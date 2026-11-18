// The share-link viewer at /r/<id>#<key>. Downloads the encrypted report,
// decrypts it here in the browser, and offers it as a PDF. The key in the
// fragment is never sent to the server.
import { decodeKey, decryptReport, ReportKeyError } from "./share-crypto.js";

const $ = (id) => document.getElementById(id);

function show(state) {
  for (const el of document.querySelectorAll("[data-state]")) {
    el.hidden = el.dataset.state !== state;
  }
}

function fail(title, body) {
  $("error-title").textContent = title;
  $("error-body").textContent = body;
  show("error");
}

/** Loads the self-hosted libsodium.js and resolves once it's ready. */
function loadSodium() {
  return new Promise((resolve, reject) => {
    window.sodium = { onload: (s) => resolve(s) };
    const script = document.createElement("script");
    script.src = "/sodium.js";
    script.async = true;
    script.onerror = () => reject(new Error("sodium.js didn't load"));
    document.head.append(script);
  });
}

function formatDate(iso) {
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return null;
  return d.toLocaleString(undefined, { dateStyle: "long", timeStyle: "short" });
}

async function main() {
  const match = location.pathname.match(/^\/r\/([A-Za-z0-9_-]{22})\/?$/);
  let key;
  try {
    if (!match) throw new ReportKeyError("No id");
    key = decodeKey(location.hash);
  } catch {
    fail(
      "This link is incomplete",
      "Ask the person who sent it for the full link, including the part after the # sign.",
    );
    return;
  }

  let res, sodium;
  try {
    const sodiumReady = loadSodium();
    res = await fetch(`/api/share/${match[1]}`, { cache: "no-store", referrerPolicy: "no-referrer" });
    sodium = await sodiumReady;
  } catch {
    fail("Couldn't load the report", "Check your connection, then reload the page.");
    return;
  }
  if (res.status === 404) {
    fail(
      "This link has expired or was turned off",
      "Shared reports stop working after the time the sender chose, or sooner if they turn the link off. Ask them for a new link.",
    );
    return;
  }
  if (!res.ok) {
    fail("Couldn't load the report", `The server returned an error (${res.status}). Try again in a few minutes.`);
    return;
  }

  let pdf;
  try {
    pdf = decryptReport(sodium, new Uint8Array(await res.arrayBuffer()), key);
  } catch {
    fail(
      "This link doesn't unlock the report",
      "Part of the link may be missing. Ask the sender to copy the whole link again.",
    );
    return;
  }

  const url = URL.createObjectURL(new Blob([pdf], { type: "application/pdf" }));
  const download = $("download");
  download.href = url;
  download.download = "bloom-cycle-report.pdf";
  $("open").addEventListener("click", () => window.open(url, "_blank", "noopener"));
  $("preview").src = url;
  const expires = formatDate(res.headers.get("X-Bloom-Expires-At"));
  $("expires").textContent = expires ? `This link stops working on ${expires}.` : "";
  $("size").textContent = `PDF · ${Math.max(1, Math.round(pdf.length / 1024))} KB`;
  show("ready");
}

main();
