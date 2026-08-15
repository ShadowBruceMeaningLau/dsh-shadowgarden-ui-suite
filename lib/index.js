// dsh-shadowgarden-ui-suite — host half
// Serves the Shadow web assets (theme css, kanban layer, images) on the DSH
// web server so the client half can load them without touching the dist.
import { readFile } from "node:fs/promises";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

export const name = "dsh-shadowgarden-ui-suite";
export const inject = ["webServer"];

const here = dirname(fileURLToPath(import.meta.url));
const webDir = join(here, "..", "web");

const ROUTES = {
  "/shadow-theme.css": "shadow-theme.css",
  "/dsh-kanban.css": "dsh-kanban.css",
  "/dsh-kanban.js": "dsh-kanban.js",
  "/kanban.html": "kanban.html",
  "/shadow-bg.png": "shadow-bg.png",
  "/shadowgarden2.jpg": "shadowgarden2.jpg"
};

const TYPES = {
  ".css": "text/css; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".html": "text/html; charset=utf-8",
  ".png": "image/png",
  ".jpg": "image/jpeg"
};

export function apply(ctx) {
  for (const [path, file] of Object.entries(ROUTES)) {
    const ext = file.slice(file.lastIndexOf("."));
    const type = TYPES[ext] ?? "application/octet-stream";
    ctx.effect(() => ctx.webServer.register({
      kind: "prefix",
      path,
      handler: async (req, res) => {
        try {
          const body = await readFile(join(webDir, file));
          res.writeHead(200, { "content-type": type, "cache-control": "no-cache" });
          res.end(body);
        } catch {
          res.writeHead(404);
          res.end("not found");
        }
      }
    }), "dsh-shadowgarden-ui-suite: asset routes");
  }
}
