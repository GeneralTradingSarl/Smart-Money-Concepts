"""Turn the parity exports (parity/tv_<cfg>.json and parity/results/mt5_<cfg>.csv) into the
compact JSON the website's proof viewer draws.

Every object keeps its own position, price, text, colour and style, exactly as each platform
exported it. Objects are then paired with the same keys as parity/compare.py:
  m = 1  the same object exists on the other platform
  m = 2  same object, only the price differs (weekly / monthly levels read from TradingView's own
         W and M bars, rebuilt from the chart bars in MT5; see parity/README.md)
  m = 0  no counterpart (none expected)

usage: python site/tools/export_viewer.py   ->  site/src/assets/data/*.json
"""
import bisect
import csv
import json
import os
import sys
from collections import defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PARITY = os.path.join(ROOT, "parity")
OUT = os.path.join(ROOT, "site", "src", "assets", "data")
sys.path.insert(0, PARITY)
from compare import abgr_to_rgb, abgr_to_argb, price, TV_LABEL_STYLE, TV_SIZE, TV_LINE_STYLE  # noqa: E402
from configs import CONFIGS  # noqa: E402

STEP = 900  # AAPL 15 min
FUTURE_BARS = 20
FUTURE_TEXTS = {"Strong High", "Weak High", "Strong Low", "Weak Low", "PDH", "PDL", "PWH", "PWL", "PMH", "PML"}

NAMES = {
    "A": "Default settings",
    "B": "Every feature on",
    "C": "Present mode, monochrome, confluence filter, FVG on 30 min",
    "D": "Config C in historical mode (hits Pine's 500-label limit)",
}


def load_bars():
    d = json.load(open(os.path.join(PARITY, "tv_A.json")))
    rows = sorted(d["studyBars"], key=lambda r: r[1])
    return [(r[1], r[2], r[3], r[4], r[5]) for r in rows]


def tv_side(cfg, bar_times):
    d = json.load(open(os.path.join(PARITY, f"tv_{cfg}.json")))
    chart = {b[0]: b[1] for b in d["chartBars"]}
    last_index = max(chart)
    last_pos = len(bar_times) - 1
    idx = d["indexes"]

    def pos(x):
        """(bar position for drawing, time key used by compare.py)"""
        if x is None or not (0 <= x < len(idx)) or idx[x] == -2000000:
            return None, None
        i = idx[x]
        if i > last_index:
            # TradingView's export only says "after the last bar" (index last + 1). In this script the
            # only such points are the strong/weak high/low and the D/W/M levels, which the Pine source
            # places at last_bar_time + 20 * (time - time[1]) (lines 584-589 and 605): 20 bars ahead.
            return last_pos + FUTURE_BARS, "future"
        t = chart[i]
        return bisect.bisect_left(bar_times, t), t

    labels, lines, boxes = [], [], []
    for l in d["labels"]:
        y = price(l.get("y"))
        if y is None:
            continue
        p, key_t = pos(l.get("x"))
        if p is None:
            continue
        assert key_t != "future" or l.get("t") in FUTURE_TEXTS, l.get("t")
        rgb = abgr_to_rgb(l.get("tci"))
        st, sz = TV_LABEL_STYLE.get(l.get("st")), TV_SIZE.get(l.get("sz"))
        labels.append({"d": [p, y, l.get("t", ""), rgb, st, sz], "k": (l.get("t", ""), key_t, y, rgb, st, sz)})
    for l in d["lines"]:
        y1, y2 = price(l.get("y1")), price(l.get("y2"))
        if y1 is None:
            continue
        (p1, t1), (p2, t2) = pos(l["x1"]), pos(l["x2"])
        if p1 is None or p2 is None:
            continue
        rgb, st = abgr_to_rgb(l.get("ci")), TV_LINE_STYLE.get(l.get("st"))
        lines.append({"d": [p1, y1, p2, y2, rgb, st], "k": (t1, y1, t2, y2, rgb, st)})
    for b in d["boxes"]:
        top, bottom = price(b.get("y1")), price(b.get("y2"))
        if top is None:
            continue
        ext = b.get("ex") == "r"
        (p1, t1), (p2, t2) = pos(b["x1"]), pos(b["x2"])
        if p1 is None:
            continue
        bg, border = abgr_to_argb(b.get("bc")), abgr_to_argb(b.get("c"))
        boxes.append({"d": [p1, top, -1 if ext else p2, bottom, bg, border],
                      "k": (t1, top, None if ext else t2, bottom, bg, border, ext)})
    candles = {r[1]: abgr_to_rgb(r[6]) for r in d["studyBars"]}
    return labels, lines, boxes, [candles.get(t) for t in bar_times]


def mt5_side(cfg, bar_times):
    last_time, last_pos = bar_times[-1], len(bar_times) - 1

    def pos(v):
        if v == "na":
            return None, None
        v = int(v)
        if v > last_time:
            return last_pos + (v - last_time) / STEP, "future"
        i = bisect.bisect_left(bar_times, v)  # a time between two bars is drawn on the next bar
        return i, bar_times[i]

    labels, lines, boxes, candles = [], [], [], {}
    with open(os.path.join(PARITY, "results", f"mt5_{cfg}.csv"), newline="") as f:
        for row in csv.reader(f):
            kind = row[0]
            if kind == "bar":
                candles[int(row[1])] = int(row[2])
            elif kind == "label":
                _, _id, keep, x, y, text, rgb, style, size = row
                y = price(y)
                if y is None:
                    continue
                p, t = pos(x)
                labels.append({"d": [p, y, text, rgb, int(style), int(size)], "k": (text, t, y, rgb, int(style), int(size))})
            elif kind == "line":
                _, _id, keep, x1, y1, x2, y2, rgb, style = row
                if price(y1) is None:
                    continue
                (p1, t1), (p2, t2) = pos(x1), pos(x2)
                lines.append({"d": [p1, price(y1), p2, price(y2), rgb, int(style)],
                              "k": (t1, price(y1), t2, price(y2), rgb, int(style))})
            elif kind == "box":
                _, _id, keep, left, top, right, bottom, bg, border, ext = row
                if price(top) is None:
                    continue
                ext = ext == "1"
                (p1, t1), (p2, t2) = pos(left), pos(right)
                boxes.append({"d": [p1, price(top), -1 if ext else p2, price(bottom), bg, border],
                              "k": (t1, price(top), None if ext else t2, price(bottom), bg, border, ext)})
    mono = CONFIGS[cfg].get("styleInput") == "MONOCHROME"
    palette = ["B2B5BE", "5D606B"] if mono else ["089981", "F23645"]
    return labels, lines, boxes, [palette[candles[t]] if t in candles else None for t in bar_times]


PRICE_FIELDS = {"labels": (2,), "lines": (1, 3), "boxes": (1, 3)}


def pair(kind, a, b):
    """mark m on both sides: exact key match first, then price-only match"""
    free = defaultdict(list)
    for o in b:
        o["m"] = 0
        free[o["k"]].append(o)
    for o in a:
        o["m"] = 0
        if free[o["k"]]:
            free[o["k"]].pop()["m"] = 1
            o["m"] = 1

    def no_price(k):
        return tuple(v for i, v in enumerate(k) if i not in PRICE_FIELDS[kind])

    loose = defaultdict(list)
    for o in b:
        if o["m"] == 0:
            loose[no_price(o["k"])].append(o)
    for o in a:
        if o["m"] == 0 and loose[no_price(o["k"])]:
            other = loose[no_price(o["k"])].pop()
            other["m"] = 2
            o["m"] = 2


def main():
    os.makedirs(OUT, exist_ok=True)
    bars = load_bars()
    bar_times = [b[0] for b in bars]
    gaps = [bar_times[0]] + [(bar_times[i] - bar_times[i - 1]) // STEP for i in range(1, len(bar_times))]
    json.dump({"symbol": "AAPL", "tf": "M15", "step": STEP, "t": gaps,
               "o": [b[1] for b in bars], "h": [b[2] for b in bars], "l": [b[3] for b in bars], "c": [b[4] for b in bars]},
              open(os.path.join(OUT, "bars.json"), "w"), separators=(",", ":"))
    summary = {}
    for cfg in "ABCD":
        tv = tv_side(cfg, bar_times)
        mt = mt5_side(cfg, bar_times)
        out = {"cfg": cfg, "name": NAMES[cfg], "settings": CONFIGS[cfg]}
        stats = {}
        for i, kind in enumerate(("labels", "lines", "boxes")):
            pair(kind, tv[i], mt[i])
            stats[kind] = {
                "tv": len(tv[i]), "mt5": len(mt[i]),
                "same": sum(1 for o in tv[i] if o["m"] == 1),
                "priceOnly": sum(1 for o in tv[i] if o["m"] == 2),
                "unmatched": sum(1 for o in tv[i] if o["m"] == 0) + sum(1 for o in mt[i] if o["m"] == 0),
            }
        palette = sorted({c for c in tv[3] + mt[3] if c})
        enc = {c: str(palette.index(c)) for c in palette}
        stats["candles"] = {"bars": len(bar_times), "same": sum(1 for x, y in zip(tv[3], mt[3]) if x == y)}
        for side, data in (("tv", tv), ("mt5", mt)):
            out[side] = {
                "labels": [o["d"] + [o["m"]] for o in data[0]],
                "lines": [o["d"] + [o["m"]] for o in data[1]],
                "boxes": [o["d"] + [o["m"]] for o in data[2]],
                "candles": "".join(enc.get(c, "-") for c in data[3]),
            }
        out["palette"] = palette
        out["stats"] = stats
        summary[cfg] = stats
        json.dump(out, open(os.path.join(OUT, f"parity-{cfg}.json"), "w"), separators=(",", ":"))
        print(cfg, json.dumps(stats))
    json.dump(summary, open(os.path.join(OUT, "summary.json"), "w"), indent=1)


if __name__ == "__main__":
    main()
