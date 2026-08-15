// dsh-shadowgarden-ui-suite — host half
// Serves the Shadow web assets under the /shadow namespace so the client can
// load them without touching the dist. Registered like genui does: probe the
// webServer service reflectively and claim ONE prefix route (never top-level
// paths, which would collide with the host static server and crash the boot).
import { readFile } from "node:fs/promises";
import { join, dirname, basename } from "node:path";
import { fileURLToPath } from "node:url";

export const name = "dsh-shadowgarden-ui-suite";

const ASSET_ROUTE_PATH = "/shadow";

const here = dirname(fileURLToPath(import.meta.url));
const webDir = join(here, "..", "web");

const SAFE_NAME = /^[A-Za-z0-9][A-Za-z0-9._-]*$/;

const TYPES = {
  ".css": "text/css; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".html": "text/html; charset=utf-8",
  ".png": "image/png",
  ".jpg": "image/jpeg"
};

async function serveAsset(req, res) {
  if (req.method !== "GET" && req.method !== "HEAD") {
    res.writeHead(405);
    res.end();
    return;
  }
  let pathname;
  try {
    pathname = decodeURIComponent(new URL(req.url ?? "/", "http://shadow.invalid").pathname);
  } catch {
    res.writeHead(400);
    res.end();
    return;
  }
  const rel = pathname.startsWith(`${ASSET_ROUTE_PATH}/`) ? pathname.slice(ASSET_ROUTE_PATH.length + 1) : "";
  if (!SAFE_NAME.test(rel)) {
    res.writeHead(404);
    res.end("not found");
    return;
  }
  try {
    const file = join(webDir, basename(rel));
    const body = await readFile(file);
    const ext = rel.slice(rel.lastIndexOf("."));
    res.writeHead(200, { "content-type": TYPES[ext] ?? "application/octet-stream", "cache-control": "no-cache" });
    res.end(body);
  } catch {
    res.writeHead(404);
    res.end("not found");
  }
}

export function apply(ctx) {
  let registered = false;
  const tryRegister = (value) => {
    if (registered) return;
    const webServer = value ?? ctx.reflect.get("webServer", false);
    if (webServer === void 0) return;
    webServer.register({
      kind: "prefix",
      path: ASSET_ROUTE_PATH,
      handler: serveAsset
    });
    registered = true;
  };
  tryRegister(void 0);
  ctx.on("internal/service", (name, value) => {
    if (name === "webServer") tryRegister(value);
  });
}
