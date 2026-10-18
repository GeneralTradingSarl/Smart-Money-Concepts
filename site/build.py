"""Build the Smart Money Concepts MT5 website into site/public.

usage: python site/build.py            (from the repository root or anywhere)
       python site/tools/export_viewer.py first if the parity exports changed
       python site/tools/shoot.py after a build to refresh the OG images and the hero poster
"""
import datetime as dt
import hashlib
import html
import io
import json
import os
import re
import shutil
import sys
import zipfile

import segno
from jinja2 import Environment, FileSystemLoader, select_autoescape
from PIL import Image

SITE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(SITE)
SRC = os.path.join(SITE, "src")
OUT = os.path.join(SITE, "public")
sys.path.insert(0, os.path.join(SITE, "tools"))
sys.path.insert(0, os.path.join(ROOT, "parity"))
from figs import all_figs  # noqa: E402

BASE = os.environ.get("SITE_URL", "https://smart-money-concepts-mt5.vercel.app").rstrip("/")
VERSION = "1.0.0"
RELEASE_DATE = "2026-10-18"
REPO = "https://github.com/GeneralTradingSarl/Smart-Money-Concepts"
SITE_INFO = {
    "url": BASE,
    "version": VERSION,
    "repo": REPO,
    "email": "general.trading.bot.2025@gmail.com",
    "linkedin": "https://www.linkedin.com/in/ismaelladjohounlou",
    "mql5": "https://www.mql5.com/en/users/ismael_financial_bot",
    "portfolio": "https://ismael-portfolio-liard.vercel.app/en",
    "telegram": "https://t.me/botaccount77",
    "telegram_handle": "@botaccount77",
    "github_user": "https://github.com/GeneralTradingSarl",
    "structura": "https://www.mql5.com/en/market/product/201556",
    "structura_video": "https://youtu.be/x35L5b2P_xY",
    "luxalgo_script": "https://www.tradingview.com/script/CnB3fSph-Smart-Money-Concepts-SMC-LuxAlgo/",
    "license": "https://creativecommons.org/licenses/by-nc-sa/4.0/",
    "google_verification": os.environ.get("GOOGLE_SITE_VERIFICATION", ""),
    "bing_verification": os.environ.get("BING_SITE_VERIFICATION", ""),
}
INDEXNOW_KEY = "5f3c9a1e7b2d4f6a8c0e1b3d5f7a9c2e"

# code, path, hreflang, name, og locale, short label
ALL_LANGS = [
    ("en", "/", "en", "English", "en_US", "EN"),
    ("fr", "/fr/", "fr", "Français", "fr_FR", "FR"),
    ("es", "/es/", "es", "Español", "es_ES", "ES"),
    ("pt", "/pt/", "pt", "Português", "pt_BR", "PT"),
    ("ru", "/ru/", "ru", "Русский", "ru_RU", "RU"),
    ("zh", "/zh/", "zh-Hans", "简体中文", "zh_CN", "中文"),
]
# a language goes live as soon as its translation file exists
LANGS = [l for l in ALL_LANGS if os.path.exists(os.path.join(SRC, "i18n", f"{l[0]}.json"))]
SKIP = {"en": "Skip to content", "fr": "Aller au contenu", "es": "Ir al contenido", "pt": "Ir para o conteúdo",
        "ru": "К содержанию", "zh": "跳到正文"}
WALLETS = [
    {"id": "tron", "address": "TULMdmDTh5tuWhMNfUNAWCN9vASh5JqAzf", "color": "#ff3b48"},
    {"id": "bnb", "address": "0xC2D08CD5277587325bABC2111F54b5E0A7ec8F12", "color": "#f0b90b"},
]
FILES = {"ex5": "SmartMoneyConcepts.ex5", "mq5": "SmartMoneyConcepts.mq5"}
ZIP_NAME = f"SmartMoneyConcepts-MT5-v{VERSION}.zip"


def sha256(b):
    return hashlib.sha256(b).hexdigest()


def human(n):
    return f"{n / 1024:.0f} KB"


def release_url(name):
    return f"{REPO}/releases/download/v{VERSION}/{name}"


def build_downloads():
    os.makedirs(os.path.join(OUT, "download"), exist_ok=True)
    dl = {}
    blobs = {}
    for k, name in FILES.items():
        b = open(os.path.join(ROOT, name), "rb").read()
        blobs[name] = b
        shutil.copyfile(os.path.join(ROOT, name), os.path.join(OUT, "download", name))
        dl[k] = {"name": name, "size": human(len(b)), "bytes": len(b), "sha": sha256(b), "url": release_url(name)}
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w", zipfile.ZIP_DEFLATED) as z:
        stamp = (2026, 10, 18, 0, 0, 0)
        for name in [*FILES.values(), "LICENSE", "README.md"]:
            data = blobs.get(name) or open(os.path.join(ROOT, name), "rb").read()
            info = zipfile.ZipInfo(f"SmartMoneyConcepts-MT5/{name}", stamp)
            info.compress_type = zipfile.ZIP_DEFLATED
            z.writestr(info, data)
    zb = buf.getvalue()
    open(os.path.join(OUT, "download", ZIP_NAME), "wb").write(zb)
    dl["zip"] = {"name": ZIP_NAME, "size": human(len(zb)), "bytes": len(zb), "sha": sha256(zb), "url": release_url(ZIP_NAME)}
    return dl


def qr_svg(text):
    q = segno.make(text, error="m", micro=False)
    out = io.BytesIO()
    q.save(out, kind="svg", scale=1, border=0, dark="#0b0f15", light=None, xmldecl=False, svgns=True, nl=False, omitsize=True)
    s = out.getvalue().decode()
    return s.replace("<svg ", '<svg preserveAspectRatio="xMidYMid meet" shape-rendering="crispEdges" ', 1)


def verify_qr(text):
    """decode the QR we are about to publish and make sure it gives back the exact address"""
    try:
        import cv2
        import numpy as np
    except ImportError:
        print("  (cv2 missing, QR decode not verified)")
        return
    out = io.BytesIO()
    segno.make(text, error="m").save(out, kind="png", scale=10, border=4)
    img = cv2.imdecode(np.frombuffer(out.getvalue(), np.uint8), cv2.IMREAD_COLOR)
    got, _, _ = cv2.QRCodeDetector().detectAndDecode(img)
    if got != text:
        raise SystemExit(f"QR decode mismatch for {text!r}: {got!r}")
    print(f"  QR ok  {text}")


def parity_totals():
    """object counts per config, the way parity/compare.py counts them"""
    from compare import load_tv
    res = {}
    for c in "ABCD":
        labels, lines, boxes, candles, _, _ = load_tv(c)
        res[c] = {"labels": sum(labels.values()), "lines": sum(lines.values()), "boxes": sum(boxes.values()),
                  "candles": len(candles), "candles_fmt": f"{len(candles):,}"}
    return res


def parse_inputs():
    """the settings reference of the guide, read from the source itself"""
    src = open(os.path.join(ROOT, FILES["mq5"]), encoding="utf-8-sig").read()
    enums = {}
    for name, body in re.findall(r"enum\s+(\w+)\s*\{(.*?)\}", src, re.S):
        enums[name] = {m.group(1): m.group(2).strip() for m in re.finditer(r"(\w+)\s*,?\s*//\s*(.+)", body)}
    defines = dict(re.findall(r"#define\s+(\w+)\s+(C'[\d,]+')", src))
    groups, cur = [], None
    for line in src.splitlines():
        g = re.match(r'input group "(.+)"', line)
        if g:
            cur = {"name": g.group(1), "items": []}
            groups.append(cur)
            continue
        m = re.match(r"input\s+(\w+)\s+(\w+)\s*=\s*(.+?);\s*//\s*(.+)$", line)
        if m and cur is not None:
            typ, var, default, label = m.groups()
            default = default.strip().strip('"')
            if typ in enums and default in enums[typ]:
                default = enums[typ][default]
            elif default in defines:
                default = defines[default]
            if default.startswith("C'"):
                r, g_, b = [int(x) for x in default[2:-1].split(",")]
                default = f"#{r:02X}{g_:02X}{b:02X}"
            if default == "PERIOD_CURRENT":
                default = "Chart timeframe"
            cur["items"].append({"label": label.strip(), "var": var, "type": typ, "default": default})
    return groups


def images():
    img_out = os.path.join(OUT, "assets", "img")
    os.makedirs(img_out, exist_ok=True)
    cmp = Image.open(os.path.join(ROOT, "docs", "images", "comparaison_tradingview_mt5.png")).convert("RGB")
    # the composite holds TradingView on top and MT5 below, each under a French caption bar
    cmp.crop((0, 45, 1600, 830)).save(os.path.join(img_out, "proof-tradingview.webp"), quality=86, method=6)
    cmp.crop((10, 876, 1600, 1678)).save(os.path.join(img_out, "proof-metatrader5.webp"), quality=86, method=6)
    structura = os.path.join(os.path.dirname(ROOT), "structura", "market", "final", "01_hero.png")
    if os.path.exists(structura):
        im = Image.open(structura).convert("RGB")
        im.thumbnail((1280, 1280))
        im.save(os.path.join(img_out, "structura.webp"), quality=84, method=6)
    for f in os.listdir(os.path.join(SRC, "assets", "img")) if os.path.isdir(os.path.join(SRC, "assets", "img")) else []:
        shutil.copyfile(os.path.join(SRC, "assets", "img", f), os.path.join(img_out, f))


def icons():
    from figs import UP, DN
    logo = open(os.path.join(SRC, "templates", "_icons.html"), encoding="utf-8").read()
    m = re.search(r"name == 'logo' -%\}(<svg.*?</svg>)", logo, re.S)
    svg = m.group(1).replace('aria-hidden="true"', 'xmlns="http://www.w3.org/2000/svg"')
    open(os.path.join(OUT, "favicon.svg"), "w", encoding="utf-8").write(svg)
    for size, name in ((32, "favicon-32.png"), (180, "apple-touch-icon.png"), (192, "icon-192.png"), (512, "icon-512.png")):
        s = size / 32
        im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        from PIL import ImageDraw
        d = ImageDraw.Draw(im)
        d.rounded_rectangle((0, 0, size - 1, size - 1), radius=int(8 * s), fill=(13, 20, 28, 255))
        for x, top, bot, w0, h0, col in ((8, 9, 23, 6, 12, UP), (16, 6, 20, 14, 8, UP), (24, 11, 26, 22, 14, DN)):
            d.line((x * s, top * s, x * s, bot * s), fill=col, width=max(1, round(1.6 * s)))
        d.rounded_rectangle((6 * s, 12 * s, 10 * s, 19 * s), radius=max(1, int(s)), fill=UP)
        d.rounded_rectangle((14 * s, 8 * s, 18 * s, 16 * s), radius=max(1, int(s)), fill=UP)
        d.rounded_rectangle((22 * s, 14 * s, 26 * s, 22 * s), radius=max(1, int(s)), fill=DN)
        im.save(os.path.join(OUT, name))


def jdump(o):
    return json.dumps(o, ensure_ascii=False, separators=(",", ":")).replace("</", "<\\/")


def person():
    return {"@type": "Person", "@id": BASE + "/#author", "name": "Ismaël Ladjohounlou",
            "alternateName": ["Ismael Ladjohounlou", "LADJOHOUNLOU Ismael"],
            "url": SITE_INFO["portfolio"], "email": "mailto:" + SITE_INFO["email"],
            "jobTitle": "AI and automation engineer, trading systems developer (MQL5, Pine Script, Python)",
            "sameAs": [SITE_INFO["github_user"], SITE_INFO["linkedin"], SITE_INFO["mql5"], SITE_INFO["telegram"]],
            "knowsAbout": ["MQL5", "MQL4", "Pine Script", "MetaTrader 5", "TradingView", "Smart Money Concepts",
                           "Expert Advisors", "Algorithmic trading", "Python", "n8n", "Business automation", "AI agents"]}


def luxalgo_work():
    return {"@type": "SoftwareSourceCode", "name": "Smart Money Concepts (SMC) [LuxAlgo]", "url": SITE_INFO["luxalgo_script"],
            "programmingLanguage": "Pine Script", "license": SITE_INFO["license"],
            "author": {"@type": "Organization", "name": "LuxAlgo", "url": "https://www.luxalgo.com"}}


def breadcrumbs(items):
    return {"@context": "https://schema.org", "@type": "BreadcrumbList",
            "itemListElement": [{"@type": "ListItem", "position": i + 1, "name": n, "item": BASE + u} for i, (n, u) in enumerate(items)]}


def home_jsonld(t, lang, dl, path):
    url = BASE + path
    app = {
        "@context": "https://schema.org", "@type": "SoftwareApplication", "@id": BASE + "/#software",
        "name": "Smart Money Concepts for MetaTrader 5",
        "alternateName": ["Smart Money Concepts MT5", "LuxAlgo Smart Money Concepts MT5", "SMC indicator MT5", "SmartMoneyConcepts.mq5"],
        "description": t["meta"]["description"], "url": url, "inLanguage": LANGS_BY[lang][2],
        "applicationCategory": "FinanceApplication", "applicationSubCategory": "Trading indicator",
        "operatingSystem": "Windows, macOS, Linux (MetaTrader 5)", "softwareRequirements": "MetaTrader 5",
        "softwareVersion": VERSION, "datePublished": RELEASE_DATE, "fileSize": dl["ex5"]["size"],
        "downloadUrl": [dl["ex5"]["url"], dl["mq5"]["url"], dl["zip"]["url"]], "installUrl": BASE + "/install/",
        "screenshot": [BASE + "/assets/img/proof-metatrader5.webp", BASE + "/assets/img/proof-tradingview.webp"],
        "image": BASE + "/og/og-en.png", "license": SITE_INFO["license"], "isAccessibleForFree": True,
        "offers": {"@type": "Offer", "price": "0", "priceCurrency": "USD", "availability": "https://schema.org/InStock"},
        "author": {"@id": BASE + "/#author"}, "isBasedOn": luxalgo_work(),
        "keywords": t["meta"]["keywords"],
        "featureList": [f["t"] for f in t["features"]["items"]],
    }
    code = {
        "@context": "https://schema.org", "@type": "SoftwareSourceCode", "name": "SmartMoneyConcepts.mq5",
        "description": "MQL5 source code of the MetaTrader 5 port of LuxAlgo's Smart Money Concepts indicator.",
        "codeRepository": REPO, "programmingLanguage": "MQL5", "runtimePlatform": "MetaTrader 5",
        "license": SITE_INFO["license"], "author": {"@id": BASE + "/#author"}, "isBasedOn": luxalgo_work(),
        "targetProduct": {"@id": BASE + "/#software"},
    }
    site = {"@context": "https://schema.org", "@type": "WebSite", "@id": BASE + "/#website", "url": BASE + "/",
            "name": "Smart Money Concepts MT5", "inLanguage": [l[2] for l in LANGS], "publisher": {"@id": BASE + "/#author"}}
    faq = {"@context": "https://schema.org", "@type": "FAQPage", "inLanguage": LANGS_BY[lang][2],
           "mainEntity": [{"@type": "Question", "name": f["q"], "acceptedAnswer": {"@type": "Answer", "text": f["a"]}}
                          for f in t["faq"]["items"]]}
    p = dict(person(), **{"@context": "https://schema.org"})
    return [jdump(x) for x in (site, app, code, faq, p)]


LANGS_BY = {l[0]: l for l in LANGS}


def env():
    e = Environment(loader=FileSystemLoader(os.path.join(SRC, "templates")),
                    autoescape=select_autoescape(["html"]), trim_blocks=True, lstrip_blocks=True)
    return e


def write(path, text):
    full = os.path.join(OUT, path.lstrip("/"))
    if full.endswith("/") or full.endswith(os.sep) or not os.path.splitext(full)[1]:
        full = os.path.join(full, "index.html")
    os.makedirs(os.path.dirname(full), exist_ok=True)
    open(full, "w", encoding="utf-8", newline="\n").write(text)


def main():
    if os.path.isdir(OUT):
        for f in os.listdir(OUT):
            p = os.path.join(OUT, f)
            shutil.rmtree(p) if os.path.isdir(p) else os.remove(p)
    os.makedirs(OUT, exist_ok=True)
    shutil.copytree(os.path.join(SRC, "assets"), os.path.join(OUT, "assets"), dirs_exist_ok=True,
                    ignore=shutil.ignore_patterns("img"))
    if os.path.isdir(os.path.join(SRC, "static")):
        shutil.copytree(os.path.join(SRC, "static"), OUT, dirs_exist_ok=True)
    images()
    icons()
    dl = build_downloads()
    for w in WALLETS:
        verify_qr(w["address"])
        w["qr"] = qr_svg(w["address"])
    figs = all_figs()
    parity = parity_totals()
    inputs = parse_inputs()
    i18n = {l[0]: json.load(open(os.path.join(SRC, "i18n", f"{l[0]}.json"), encoding="utf-8")) for l in LANGS}
    css = open(os.path.join(SRC, "assets", "css", "style.css"), "rb").read()
    js = open(os.path.join(SRC, "assets", "js", "chart.js"), "rb").read() + open(os.path.join(SRC, "assets", "js", "main.js"), "rb").read()
    v = sha256(css + js)[:10]
    poster = "/assets/img/hero-poster.webp" if os.path.exists(os.path.join(SRC, "assets", "img", "hero-poster.webp")) else None
    E = env()
    today = dt.date.today().isoformat()
    home_alts = [{"hreflang": l[2], "href": BASE + l[1]} for l in LANGS] + [{"hreflang": "x-default", "href": BASE + "/"}]
    sitemap = []

    def common(lang, page, path, title, desc, alternates, og_title=None, og_desc=None, og_type="website",
               jsonld=(), robots="index, follow, max-image-preview:large, max-snippet:-1, max-video-preview:-1"):
        t = i18n[lang]
        code = LANGS_BY[lang]
        og_img = BASE + (f"/og/og-{lang}.png" if os.path.exists(os.path.join(SRC, "static", "og", f"og-{lang}.png")) else "/og/og-en.png")
        return dict(
            t=t, lang=lang, html_lang=code[2], lang_short=code[5], page=page, title=title, description=desc,
            keywords=t["meta"].get("keywords") if page == "home" else None, robots=robots,
            canonical=BASE + path, alternates=alternates, og_type=og_type, og_title=og_title or title, og_desc=og_desc or desc,
            og_image=og_img, og_locale=code[4], og_locale_alts=[l[4] for l in LANGS if l[0] != lang] if page == "home" else [],
            jsonld=list(jsonld), site=SITE_INFO, v=v, home_url=code[1], skip=SKIP[lang],
            langs=[{"href": l[1], "hreflang": l[2], "name": l[3], "current": l[0] == lang} for l in LANGS],
            dl=dl, wallets=WALLETS, figs=figs, parity=parity, inputs=inputs, preload_data=False, poster=poster,
        )

    # localized home pages
    for code, path, hreflang, *_ in LANGS:
        t = i18n[code]
        ctx = common(code, "home", path, t["meta"]["title"], t["meta"]["description"], home_alts,
                     t["meta"]["og_title"], t["meta"]["og_desc"], jsonld=home_jsonld(t, code, dl, path))
        ctx["preload_data"] = True
        write(path, E.get_template("home.html").render(**ctx))
        sitemap.append({"loc": BASE + path, "alts": home_alts, "priority": "1.0" if code == "en" else "0.9"})

    # English guides
    en = i18n["en"]
    pages = [
        ("proof", "/proof/", "Smart Money Concepts MT5 vs TradingView: the parity proof, object by object",
         "Interactive proof that the MT5 port of LuxAlgo Smart Money Concepts draws exactly what TradingView draws: 2,535 drawings and 20,176 candle colours compared on the same AAPL bars.",
         "Proof"),
        ("install", "/install/", "How to install the Smart Money Concepts indicator in MetaTrader 5 (.ex5 and .mq5)",
         "Step-by-step installation of the free Smart Money Concepts indicator in MT5: where to put the .ex5, how to compile the .mq5, alerts, templates and troubleshooting.",
         "Install"),
        ("guide", "/guide/", "Smart Money Concepts indicator for MT5: BOS, CHoCH, order blocks, FVG and every setting",
         "How the LuxAlgo Smart Money Concepts indicator works on MetaTrader 5: internal and swing structure, BOS and CHoCH, order blocks, equal highs and lows, fair value gaps, premium and discount zones, and the full settings reference.",
         "Guide"),
        ("service", "/pine-script-to-mql5/", "Convert TradingView Pine Script to MQL5 (MT5), with proof of identical results",
         "Have any TradingView Pine Script indicator or strategy converted to MetaTrader 5 or 4, with an object-by-object parity report on the same bars. Free quote.",
         "Pine Script to MQL5"),
    ]
    for page, path, title, desc, crumb in pages:
        alts = [{"hreflang": "en", "href": BASE + path}, {"hreflang": "x-default", "href": BASE + path}]
        ctx = common("en", page, path, title, desc, alts, og_type="article")
        ctx["jsonld"] = page_jsonld(page, title, desc, path, crumb, en, dl, today)
        if page == "proof":
            ctx["preload_data"] = True
        ctx["service_faq"] = SERVICE_FAQ
        write(path, E.get_template(f"{page}.html").render(**ctx))
        sitemap.append({"loc": BASE + path, "alts": None, "priority": "0.8"})

    # 404
    ctx = common("en", "404", "/404.html", "Page not found · Smart Money Concepts MT5", "This page does not exist.", [],
                 robots="noindex")
    open(os.path.join(OUT, "404.html"), "w", encoding="utf-8").write(E.get_template("404.html").render(**ctx))

    if "--og" in sys.argv:
        # throwaway pages for tools/shoot.py (social cards and the hero poster), never deployed
        for code, path, *_ in LANGS:
            ctx = common(code, "og", "/_og/", "og", "", [], robots="noindex")
            ctx.update(kind="og", w=1200, h=630, bars=96)
            write(f"/_og/{code}.html", E.get_template("og.html").render(**ctx))
        ctx = common("en", "og", "/_og/", "og", "", [], robots="noindex")
        ctx.update(kind="poster", w=1180, h=520, bars=150)
        write("/_og/poster.html", E.get_template("og.html").render(**ctx))

    write_static(sitemap, today, en, dl)
    print("built", len(sitemap), "pages ->", OUT, "| assets v", v)


def page_jsonld(page, title, desc, path, crumb, t, dl, today):
    url = BASE + path
    crumbs = breadcrumbs([("Smart Money Concepts MT5", "/"), (crumb, path)])
    art = {"@context": "https://schema.org", "@type": "TechArticle", "headline": title, "description": desc, "url": url,
           "inLanguage": "en", "datePublished": RELEASE_DATE, "dateModified": today, "author": {"@id": BASE + "/#author"},
           "publisher": {"@id": BASE + "/#author"}, "image": BASE + "/og/og-en.png",
           "about": {"@id": BASE + "/#software"}, "mainEntityOfPage": url}
    out = [crumbs, art]
    if page == "proof":
        raw = REPO.replace("github.com", "raw.githubusercontent.com") + "/main/parity/"
        out.append({
            "@context": "https://schema.org", "@type": "Dataset",
            "name": "Smart Money Concepts parity dataset: TradingView (LuxAlgo Pine) vs MetaTrader 5 (MQL5 port)",
            "description": "Every label, line and box drawn by LuxAlgo's Smart Money Concepts on TradingView and by its MQL5 port on MetaTrader 5, on the same 5,044 AAPL 15-minute bars, in four configurations, with the comparison script.",
            "url": url, "license": SITE_INFO["license"], "creator": {"@id": BASE + "/#author"},
            "isAccessibleForFree": True, "keywords": ["Smart Money Concepts", "LuxAlgo", "MQL5", "Pine Script", "parity test", "TradingView", "MetaTrader 5"],
            "temporalCoverage": "2026-01-02/2026-10-09", "variableMeasured": ["label text, time, price, colour, style, size", "line coordinates, colour, style", "box coordinates, colours, extension", "candle trend colour"],
            "distribution": [{"@type": "DataDownload", "encodingFormat": "application/json", "contentUrl": raw + f"tv_{c}.json"} for c in "ABCD"]
            + [{"@type": "DataDownload", "encodingFormat": "text/csv", "contentUrl": raw + f"results/mt5_{c}.csv"} for c in "ABCD"],
        })
    if page == "install":
        steps = [
            ("Download the indicator", "Download SmartMoneyConcepts.ex5 (or the .mq5 source) from the release page."),
            ("Open the data folder", "In MetaTrader 5, choose File, Open Data Folder, then open MQL5 and Indicators."),
            ("Copy the file", "Copy SmartMoneyConcepts.ex5 into MQL5/Indicators."),
            ("Refresh the Navigator", "In the Navigator window, right-click Indicators and choose Refresh."),
            ("Attach it to a chart", "Drag SmartMoneyConcepts onto a chart, adjust the Inputs tab and press OK."),
        ]
        out.append({"@context": "https://schema.org", "@type": "HowTo", "name": title, "description": desc, "inLanguage": "en",
                    "totalTime": "PT2M", "tool": [{"@type": "HowToTool", "name": "MetaTrader 5"}],
                    "supply": [{"@type": "HowToSupply", "name": "SmartMoneyConcepts.ex5"}],
                    "step": [{"@type": "HowToStep", "position": i + 1, "name": n, "text": s, "url": url + f"#step-{i + 1}"}
                             for i, (n, s) in enumerate(steps)]})
    if page == "service":
        out.append({"@context": "https://schema.org", "@type": "Service", "name": "Pine Script to MQL5 conversion",
                    "serviceType": "TradingView Pine Script to MetaTrader 5 / 4 conversion", "url": url, "description": desc,
                    "provider": {"@id": BASE + "/#author"}, "areaServed": "Worldwide", "availableLanguage": ["English", "French"],
                    "termsOfService": url})
        out.append({"@context": "https://schema.org", "@type": "FAQPage",
                    "mainEntity": [{"@type": "Question", "name": q, "acceptedAnswer": {"@type": "Answer", "text": a}} for q, a in SERVICE_FAQ]})
    out.append(dict(person(), **{"@context": "https://schema.org"}))
    return [jdump(x) for x in out]


SERVICE_FAQ = [
    ("Can any Pine Script be converted to MQL5?",
     "Almost always. Indicators, strategies, request.security, arrays, matrices, user-defined types, labels, lines, boxes, tables and alerts all have an MQL5 equivalent. Where MetaTrader works differently (transparency, real-time recalculation, object limits), the port reproduces Pine's behaviour so the result stays the same."),
    ("How do I know the conversion is exact?",
     "You get a parity report: the Pine script and the MQL5 port run on the same bars, every drawing and plotted value is exported from both platforms and compared. The Smart Money Concepts port on this site is the public example."),
    ("Can a Pine strategy become an Expert Advisor?",
     "Yes. Entries, exits, stops, position sizing and pyramiding are rebuilt as an MQL5 Expert Advisor, and the trades can be compared with the TradingView strategy tester."),
    ("Do I get the source code?",
     "Yes, the full .mq5 or .mq4 source is delivered with the compiled file, unless the original licence of your script forbids it."),
    ("What about licensing?",
     "Only scripts you own, or whose licence allows a port, can be converted. Open-source TradingView scripts keep their original licence and attribution."),
]


def write_static(sitemap, today, en, dl):
    lines = ['<?xml version="1.0" encoding="UTF-8"?>',
             '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">']
    for s in sitemap:
        lines.append("  <url>")
        lines.append(f"    <loc>{s['loc']}</loc>")
        for a in s["alts"] or []:
            lines.append(f'    <xhtml:link rel="alternate" hreflang="{a["hreflang"]}" href="{a["href"]}"/>')
        lines.append(f"    <lastmod>{today}</lastmod>")
        lines.append(f"    <priority>{s['priority']}</priority>")
        lines.append("  </url>")
    lines.append("</urlset>")
    open(os.path.join(OUT, "sitemap.xml"), "w", encoding="utf-8", newline="\n").write("\n".join(lines) + "\n")
    open(os.path.join(OUT, "robots.txt"), "w", newline="\n").write(
        f"User-agent: *\nAllow: /\n\nSitemap: {BASE}/sitemap.xml\n")
    open(os.path.join(OUT, f"{INDEXNOW_KEY}.txt"), "w", newline="\n").write(INDEXNOW_KEY)
    manifest = {"name": "Smart Money Concepts MT5", "short_name": "SMC MT5", "start_url": "/", "display": "standalone",
                "background_color": "#07090d", "theme_color": "#07090d",
                "icons": [{"src": "/icon-192.png", "sizes": "192x192", "type": "image/png"},
                          {"src": "/icon-512.png", "sizes": "512x512", "type": "image/png"}]}
    json.dump(manifest, open(os.path.join(OUT, "site.webmanifest"), "w"), indent=1)
    llms = f"""# Smart Money Concepts for MetaTrader 5

> Free MetaTrader 5 (MQL5) port of LuxAlgo's open-source "Smart Money Concepts (SMC) [LuxAlgo]" TradingView indicator, by Ismaël Ladjohounlou. The compiled .ex5 and the full .mq5 source are free (CC BY-NC-SA 4.0, non-commercial). Compared object by object with TradingView on 5,044 AAPL 15-minute bars in four configurations and two tick-by-tick replays: 100% of labels, lines, boxes and candle colours identical. Unofficial, not affiliated with LuxAlgo or TradingView.

Features: internal and swing market structure (BOS, CHoCH), internal and swing order blocks, equal highs and lows (EQH, EQL), fair value gaps (chart or higher timeframe), premium / equilibrium / discount zones, strong and weak highs and lows, previous day / week / month highs and lows, trend coloured candles, 16 alerts (popup, push, email), Historical or Present mode, Colored or Monochrome style.

## Pages
- [Home and download]({BASE}/): what the indicator draws, downloads, donations, custom work
- [Parity proof]({BASE}/proof/): interactive viewer and method of the TradingView vs MT5 comparison
- [Concepts and settings]({BASE}/guide/): how each concept is computed and every input with its default
- [Installation]({BASE}/install/): .ex5 and .mq5 installation in MetaTrader 5, alerts, troubleshooting
- [Pine Script to MQL5 service]({BASE}/pine-script-to-mql5/): custom conversion of TradingView scripts with a parity report

## Files
- [SmartMoneyConcepts.ex5]({dl['ex5']['url']}) ({dl['ex5']['size']}, SHA-256 {dl['ex5']['sha']})
- [SmartMoneyConcepts.mq5]({dl['mq5']['url']}) ({dl['mq5']['size']}, SHA-256 {dl['mq5']['sha']})
- [Source repository and test bench]({REPO})

## Author
Ismaël Ladjohounlou, AI and automation engineer and trading systems developer (MQL5, Pine Script, Python). Contact: {SITE_INFO['email']}, Telegram {SITE_INFO['telegram_handle']}. Custom MT4/MT5 indicators, Expert Advisors, Pine Script to MQL5 conversions, n8n and Python automation, Telegram bots.
"""
    open(os.path.join(OUT, "llms.txt"), "w", encoding="utf-8", newline="\n").write(llms)
    vercel = {
        "trailingSlash": True,
        "headers": [
            {"source": "/(.*)", "headers": [
                {"key": "X-Content-Type-Options", "value": "nosniff"},
                {"key": "Referrer-Policy", "value": "strict-origin-when-cross-origin"},
                {"key": "Permissions-Policy", "value": "camera=(), microphone=(), geolocation=()"}]},
            {"source": "/assets/(css|js)/(.*)", "headers": [{"key": "Cache-Control", "value": "public, max-age=31536000, immutable"}]},
            {"source": "/assets/(img|data)/(.*)", "headers": [{"key": "Cache-Control", "value": "public, max-age=86400"}]},
            {"source": "/download/(.*)", "headers": [{"key": "X-Robots-Tag", "value": "noindex"},
                                                    {"key": "Content-Disposition", "value": "attachment"}]},
        ],
    }
    json.dump(vercel, open(os.path.join(OUT, "vercel.json"), "w"), indent=2)


if __name__ == "__main__":
    main()
