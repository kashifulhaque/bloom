// Checks that the share-link viewer (web/r/share-crypto.js) opens a box that
// the Dart app made, and refuses a wrong key, a changed box, and non-PDFs.
// Run with: npm run test:viewer
import { test, before } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { runInThisContext } from "node:vm";
import { fileURLToPath } from "node:url";

import {
  decodeKey,
  decryptReport,
  isPdf,
  ReportDecryptError,
  ReportKeyError,
} from "../../web/r/share-crypto.js";

const here = (p) => fileURLToPath(new URL(p, import.meta.url));
const vector = JSON.parse(readFileSync(here("../fixtures/report_share_vector.json"), "utf8"));
const box = new Uint8Array(Buffer.from(vector.box, "base64"));
const plaintext = new Uint8Array(Buffer.from(vector.plaintext, "base64"));

let sodium;
before(async () => {
  // Run the browser build of libsodium.js as a plain script, as the viewer
  // does: it reads `sodium.onload` and `self.crypto` from the global object.
  // Hide `process` while it starts, or it takes a Node.js path that this
  // build doesn't include.
  globalThis.self ??= globalThis;
  const src = readFileSync(here("../../web/sodium.js"), "utf8");
  const proc = Object.getOwnPropertyDescriptor(globalThis, "process");
  sodium = await new Promise((resolve, reject) => {
    globalThis.sodium = { onload: resolve };
    setTimeout(() => reject(new Error("sodium.js didn't load")), 10000).unref();
    Object.defineProperty(globalThis, "process", { value: undefined, configurable: true, writable: true });
    try {
      runInThisContext(src, { filename: "sodium.js" });
    } finally {
      Object.defineProperty(globalThis, "process", proc);
    }
  });
});

test("decrypts a box made by the Dart app", () => {
  const out = decryptReport(sodium, box, decodeKey(`#${vector.key}`));
  assert.deepEqual(out, plaintext);
  assert.ok(isPdf(out));
});

test("refuses a wrong key", () => {
  const key = decodeKey(vector.key);
  key[0] ^= 1;
  assert.throws(() => decryptReport(sodium, box, key), ReportDecryptError);
});

test("refuses a changed box", () => {
  const changed = box.slice();
  changed[changed.length - 1] ^= 1;
  assert.throws(() => decryptReport(sodium, changed, decodeKey(vector.key)), ReportDecryptError);
});

test("refuses a box that isn't a PDF", () => {
  const key = decodeKey(vector.key);
  const nonce = sodium.randombytes_buf(24);
  const sealed = sodium.crypto_aead_xchacha20poly1305_ietf_encrypt(
    new TextEncoder().encode("<html>not a report</html>"),
    new TextEncoder().encode("bloom/v1/report-share"),
    null,
    nonce,
    key,
  );
  const html = new Uint8Array([1, ...nonce, ...sealed]);
  assert.throws(() => decryptReport(sodium, html, key), /isn't a PDF/);
});

test("refuses a missing or malformed key", () => {
  assert.throws(() => decodeKey(""), ReportKeyError);
  assert.throws(() => decodeKey("#short"), ReportKeyError);
  assert.throws(() => decodeKey(`#${vector.key}!`), ReportKeyError);
});
