package org.matrix.TEESimulator.interception.keystore.shim

import android.hardware.security.keymint.Algorithm
import android.hardware.security.keymint.BlockMode
import android.hardware.security.keymint.Digest
import android.hardware.security.keymint.KeyParameter
import android.hardware.security.keymint.KeyPurpose
import android.hardware.security.keymint.PaddingMode
import android.hardware.security.keymint.Tag
import org.matrix.TEESimulator.attestation.KeyMintAttestation

object AuthorizeCreate {

    fun check(
        keyParams: KeyMintAttestation?,
        opParams: KeyMintAttestation,
        rawOpParams: Array<KeyParameter>? = null,
    ): Int? {
        if (keyParams == null) return null
        val purpose = opParams.purpose.firstOrNull() ?: return null
        // Algorithm-level rejection runs before purpose-list check (AOSP HAL behavior)
        return checkAlgorithmPurpose(keyParams, purpose)
            ?: checkPurpose(keyParams, purpose)
            ?: checkOperationAuthorizations(keyParams, opParams)
            ?: checkTemporalValidity(keyParams, purpose)
            ?: checkCallerNonce(keyParams, purpose, rawOpParams)
    }

    private fun checkAlgorithmPurpose(keyParams: KeyMintAttestation, purpose: Int): Int? {
        val algo = keyParams.algorithm
        if (
            (algo == Algorithm.EC || algo == Algorithm.RSA) &&
                (purpose == KeyPurpose.VERIFY || purpose == KeyPurpose.ENCRYPT)
        ) {
            return KeystoreErrorCodes.unsupportedPurpose
        }
        if (algo == Algorithm.RSA && purpose == KeyPurpose.AGREE_KEY)
            return KeystoreErrorCodes.unsupportedPurpose
        return null
    }

    private fun checkPurpose(keyParams: KeyMintAttestation, purpose: Int): Int? {
        if (purpose == KeyPurpose.WRAP_KEY) return KeystoreErrorCodes.incompatiblePurpose
        if (purpose !in keyParams.purpose) return KeystoreErrorCodes.incompatiblePurpose
        return null
    }

    private fun checkOperationAuthorizations(
        keyParams: KeyMintAttestation,
        opParams: KeyMintAttestation,
    ): Int? {
        if (opParams.blockMode.any { it !in keyParams.blockMode }) {
            return KeystoreErrorCodes.incompatibleBlockMode
        }
        if (opParams.padding.any { it !in keyParams.padding }) {
            return KeystoreErrorCodes.incompatiblePaddingMode
        }
        if (opParams.digest.any { it !in keyParams.digest }) {
            return KeystoreErrorCodes.incompatibleDigest
        }
        checkRsaOaepMgfDigest(keyParams, opParams)?.let {
            return it
        }

        if (keyParams.algorithm == Algorithm.AES && opParams.blockMode.contains(BlockMode.GCM)) {
            val requestedMacLength = opParams.minMacLength
            val keyMinMacLength = keyParams.minMacLength
            if (
                requestedMacLength != null &&
                    keyMinMacLength != null &&
                    requestedMacLength < keyMinMacLength
            ) {
                return KeystoreErrorCodes.invalidMacLength
            }
        }

        if (
            keyParams.algorithm == Algorithm.RSA &&
                opParams.padding.contains(PaddingMode.RSA_OAEP) &&
                opParams.digest.isEmpty()
        ) {
            return KeystoreErrorCodes.incompatibleDigest
        }

        return null
    }

    /**
     * AOSP Tag::RSA_OAEP_MGF_DIGEST semantics: an explicit begin() MGF1 digest must be present in
     * the key's authorized set (else INCOMPATIBLE_MGF_DIGEST), and Digest.NONE is never usable
     * (UNSUPPORTED_MGF_DIGEST). An omitted begin() MGF1 digest defaults to SHA-1, which must then be
     * part of the key's explicitly authorized set (else INCOMPATIBLE_MGF_DIGEST).
     */
    fun checkRsaOaepMgfDigest(
        keyParams: KeyMintAttestation,
        opParams: KeyMintAttestation,
    ): Int? {
        if (keyParams.algorithm != Algorithm.RSA) return null
        if (!opParams.padding.contains(PaddingMode.RSA_OAEP)) return null
        val keyMgf = keyParams.rsaOaepMgfDigest
        val opMgf = opParams.rsaOaepMgfDigest
        if (opMgf.contains(Digest.NONE)) return KeystoreErrorCodes.unsupportedMgfDigest
        if (opMgf.isEmpty()) {
            if (keyMgf.isNotEmpty() && !keyMgf.contains(Digest.SHA1)) {
                return KeystoreErrorCodes.incompatibleMgfDigest
            }
            return null
        }
        if (opMgf.any { it !in keyMgf }) return KeystoreErrorCodes.incompatibleMgfDigest
        return null
    }

    private fun checkTemporalValidity(keyParams: KeyMintAttestation, purpose: Int): Int? {
        val now = System.currentTimeMillis()

        keyParams.activeDateTime?.let { activeDate ->
            if (now < activeDate.time) return KeystoreErrorCodes.keyNotYetValid
        }

        keyParams.originationExpireDateTime?.let { expireDate ->
            if (purpose == KeyPurpose.SIGN || purpose == KeyPurpose.ENCRYPT) {
                if (now > expireDate.time) return KeystoreErrorCodes.keyExpired
            }
        }

        keyParams.usageExpireDateTime?.let { expireDate ->
            if (purpose == KeyPurpose.VERIFY || purpose == KeyPurpose.DECRYPT) {
                if (now > expireDate.time) return KeystoreErrorCodes.keyExpired
            }
        }

        return null
    }

    private fun checkCallerNonce(
        keyParams: KeyMintAttestation,
        purpose: Int,
        rawOpParams: Array<KeyParameter>?,
    ): Int? {
        if (purpose != KeyPurpose.SIGN && purpose != KeyPurpose.ENCRYPT) return null
        if (keyParams.callerNonce == true) return null
        if (rawOpParams?.any { it.tag == Tag.NONCE } == true)
            return KeystoreErrorCodes.callerNonceProhibited
        return null
    }
}
