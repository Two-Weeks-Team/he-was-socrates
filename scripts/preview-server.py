#!/usr/bin/env python3
# Local HTTP server for the viseme tweak UI.
# Serves assets/ statically + 3 endpoints:
#   GET  /api/config      -> current persisted config (or {})
#   POST /api/config      -> save config to assets/.preview-config.json
#   POST /api/rebuild     -> run `bash scripts/build-visemes.sh` with config env

import http.server
import json
import os
import socketserver
import subprocess
import sys
from pathlib import Path
from urllib.parse import urlparse


ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "assets"
CONFIG = ASSETS / ".preview-config.json"
PORT = int(os.environ.get("PREVIEW_PORT", "8765"))


def env_from_config() -> dict:
    env = os.environ.copy()
    if not CONFIG.exists():
        return env
    try:
        d = json.loads(CONFIG.read_text())
    except Exception:
        return env
    if "dot_size" in d:
        env["DOT_SIZE"] = str(d["dot_size"])
    if "fg_rgba" in d:
        env["FG_RGBA"] = ",".join(str(x) for x in d["fg_rgba"])
    if "gamma" in d:
        env["GAMMA"] = str(d["gamma"])
    if "mouth_xy" in d:
        xy = d["mouth_xy"]
        env["MOUTH_XY"] = f"{xy[0]},{xy[1]}"
    if "mouth_color" in d:
        env["MOUTH_COLOR"] = ",".join(str(x) for x in d["mouth_color"])
    if "scale" in d:
        env["SCALE"] = str(d["scale"])
    if "mode" in d:
        env["MODE"] = str(d["mode"])
    if "feather" in d:
        env["FEATHER"] = str(d["feather"])
    return env


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(ASSETS), **kwargs)

    def log_message(self, fmt, *args):
        sys.stderr.write(f"[preview-server] {fmt % args}\n")

    def _json(self, code: int, payload: dict) -> None:
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def end_headers(self) -> None:
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def do_GET(self):
        url = urlparse(self.path)
        if url.path == "/api/config":
            data = {}
            if CONFIG.exists():
                try:
                    data = json.loads(CONFIG.read_text())
                except Exception:
                    data = {"_error": "could not parse"}
            return self._json(200, data)
        return super().do_GET()

    def do_POST(self):
        url = urlparse(self.path)

        if url.path == "/api/config":
            length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(length)
            try:
                config = json.loads(body)
            except Exception as exc:
                return self._json(400, {"ok": False, "error": f"bad json: {exc}"})
            if not isinstance(config, dict):
                return self._json(400, {"ok": False, "error": "config must be object"})
            CONFIG.write_text(json.dumps(config, indent=2, ensure_ascii=False) + "\n")
            return self._json(
                200,
                {
                    "ok": True,
                    "config_path": str(CONFIG.relative_to(ROOT)),
                    "saved": config,
                },
            )

        if url.path == "/api/rebuild":
            try:
                proc = subprocess.run(
                    ["bash", "scripts/build-visemes.sh"],
                    cwd=ROOT,
                    env=env_from_config(),
                    capture_output=True,
                    text=True,
                    timeout=180,
                )
            except subprocess.TimeoutExpired:
                return self._json(504, {"ok": False, "error": "rebuild timed out"})
            ok = proc.returncode == 0
            return self._json(
                200 if ok else 500,
                {
                    "ok": ok,
                    "returncode": proc.returncode,
                    "stdout": proc.stdout[-4096:],
                    "stderr": proc.stderr[-4096:],
                },
            )

        return self._json(404, {"ok": False, "error": "unknown endpoint"})


def main() -> int:
    if not ASSETS.exists():
        print(f"preview-server: missing {ASSETS}", file=sys.stderr)
        return 2
    socketserver.TCPServer.allow_reuse_address = True
    print(
        f"preview-server: http://localhost:{PORT}/preview/index.html",
        file=sys.stderr,
    )
    print(
        f"preview-server: serving {ASSETS}; config={CONFIG}",
        file=sys.stderr,
    )
    with socketserver.TCPServer(("127.0.0.1", PORT), Handler) as httpd:
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\npreview-server: stopped", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
