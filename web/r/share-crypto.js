// Opens an encrypted Bloom report in the browser. Shared by the viewer page
// (viewer.js) and its test (test/viewer/share_crypto.test.mjs).
//
// A box is [format byte 0x01][24-byte nonce][XChaCha20-Poly1305 ciphertext and
// 16-byte tag], sealed with the associated data "bloom/v1/report-share". The
// 32-byte key is the link's URL fragment in base64url without padding. This
// matches lib/features/reports/share/share_crypto.dart.

export const FORMAT = 1;
export const NONCE_BYTES = 24;
export const TAG_BYTES = 16;
export const AAD = "bloom/v1/report-share";

export class ReportKeyError extends Error {}
export class ReportDecryptError extends Error {}

/** Reads the key from a link fragment (with or without the leading "#"). */
export function decodeKey(fragment) {
  const text = (fragment || "").replace(/^#/, "");
  if (!/^[A-Za-z0-9_-]{43}$/.test(text)) throw new ReportKeyError("The link has no key.");
  const b64 = text.replaceAll("-", "+").replaceAll("_", "/") + "=";
  const bin = atob(b64);
  const key = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) key[i] = bin.charCodeAt(i);
  if (key.length !== 32) throw new ReportKeyError("The link's key is the wrong length.");
  return key;
}

/** True when bytes start with "%PDF-". */
export function isPdf(bytes) {
  const magic = [0x25, 0x50, 0x44, 0x46, 0x2d];
  return bytes.length >= magic.length && magic.every((b, i) => bytes[i] === b);
}

/**
 * Decrypts a box with libsodium.js and checks that the result is a PDF.
 * Throws ReportDecryptError when the key doesn't match, the box was changed,
 * or the contents aren't a PDF.
 */
export function decryptReport(sodium, box, key) {
  if (box.length < 1 + NONCE_BYTES + TAG_BYTES || box[0] !== FORMAT) {
    throw new ReportDecryptError("That isn't an encrypted Bloom report.");
  }
  const nonce = box.subarray(1, 1 + NONCE_BYTES);
  const sealed = box.subarray(1 + NONCE_BYTES);
  let plain;
  try {
    plain = sodium.crypto_aead_xchacha20poly1305_ietf_decrypt(
      null,
      sealed,
      new TextEncoder().encode(AAD),
      nonce,
      key,
    );
  } catch {
    throw new ReportDecryptError("The key doesn't unlock this report.");
  }
  if (!isPdf(plain)) throw new ReportDecryptError("The report isn't a PDF.");
  return plain;
}
