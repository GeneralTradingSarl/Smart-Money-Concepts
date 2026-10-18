"""Render the social cards (1200 x 630, one per language) and the hero poster with headless Chrome.

usage: python site/tools/shoot.py
Writes site/src/static/og/og-<lang>.png and site/src/assets/img/hero-poster.webp, then rebuilds the site.
"""
import http.server
import os
import shutil
import subprocess
import sys
import tempfile
import threading
import functools

from PIL import Image

SITE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PUBLIC = os.path.join(SITE, "public")
CHROME = os.environ.get("CHROME", r"C:\Program Files\Google\Chrome\Application\chrome.exe")
PORT = 8797


def shot(url, w, h, out, scale=1):
    profile = tempfile.mkdtemp(prefix="smc-shot-")
    try:
        subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--no-first-run",
                        f"--user-data-dir={profile}", f"--force-device-scale-factor={scale}",
                        f"--window-size={w},{h}", "--virtual-time-budget=15000", f"--screenshot={out}", url],
                       check=True, capture_output=True, timeout=120)
    finally:
        shutil.rmtree(profile, ignore_errors=True)


def main():
    subprocess.run([sys.executable, os.path.join(SITE, "build.py"), "--og"], check=True)
    handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=PUBLIC)
    handler.log_message = lambda *a: None
    srv = http.server.ThreadingHTTPServer(("127.0.0.1", PORT), handler)
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    og_dir = os.path.join(SITE, "src", "static", "og")
    img_dir = os.path.join(SITE, "src", "assets", "img")
    os.makedirs(og_dir, exist_ok=True)
    os.makedirs(img_dir, exist_ok=True)
    tmp = tempfile.mkdtemp(prefix="smc-png-")
    try:
        for f in sorted(os.listdir(os.path.join(PUBLIC, "_og"))):
            name = f[:-5]
            if name == "poster":
                png = os.path.join(tmp, "poster.png")
                shot(f"http://127.0.0.1:{PORT}/_og/poster.html", 1180, 520, png, scale=1.5)
                Image.open(png).convert("RGB").save(os.path.join(img_dir, "hero-poster.webp"), quality=82, method=6)
            else:
                png = os.path.join(tmp, f"og-{name}.png")
                shot(f"http://127.0.0.1:{PORT}/_og/{f}", 1200, 630, png)
                im = Image.open(png).convert("RGB")
                assert im.size == (1200, 630), im.size
                im.save(os.path.join(og_dir, f"og-{name}.png"), optimize=True)
            print("shot", name)
    finally:
        srv.shutdown()
        shutil.rmtree(tmp, ignore_errors=True)
    subprocess.run([sys.executable, os.path.join(SITE, "build.py")], check=True)


if __name__ == "__main__":
    main()
