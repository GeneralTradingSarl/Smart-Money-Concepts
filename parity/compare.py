"""Compare, object by object, what LuxAlgo's Pine drew on TradingView (tv_<cfg>.json)
with what the MQL5 port drew in MT5 on the same bars (MQL5\\Files\\smc_parity\\mt5_<cfg>.csv).
usage: python compare.py A [B C ...]"""
import csv
import json
import os
import sys
import datetime as dt
from collections import Counter
from configs import CONFIGS

HERE = os.path.dirname(os.path.abspath(__file__))
# dumps written by MT5 during a run (MQL5\Files\smc_parity), archived in results/ once the run is over;
# set SMC_MT5_FILES to read a fresh run straight from the terminal
MT5_FILES = os.environ.get("SMC_MT5_FILES") or os.path.join(HERE, "results")
TV_LABEL_STYLE = {"ldn": 0, "lup": 1, "llf": 2}
TV_SIZE = {"tiny": 0, "small": 1, "normal": 2}
TV_LINE_STYLE = {"sol": 0, "dsh": 1, "dot": 2}


def abgr_to_rgb(v):
    """TradingView stores colors as 0xAABBGGRR."""
    if v is None:
        return None
    return "%02X%02X%02X" % (v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF)


def abgr_to_argb(v):
    if v is None:
        return "00000000"
    return "%02X%02X%02X%02X" % ((v >> 24) & 0xFF, v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF)


def price(v):
    return None if v is None or v == "na" else round(float(v), 6)


def base(cfg):
    return cfg[:-2] if cfg.endswith("rt") else cfg


def load_tv(cfg):
    d = json.load(open(os.path.join(HERE, f"tv_{base(cfg)}.json")))
    times = {b[0]: b[1] for b in d["chartBars"]}
    last_index = max(times)
    idx = d["indexes"]

    def tv_time(x):
        if x is None or not (0 <= x < len(idx)) or idx[x] == -2000000:
            return None
        i = idx[x]
        return "future" if i > last_index else times[i]

    labels = Counter()
    for l in d["labels"]:
        y = price(l.get("y"))
        t = tv_time(l.get("x")) if y is not None else None
        labels[(l.get("t", ""), t, y, abgr_to_rgb(l.get("tci")) if y is not None else None,
                TV_LABEL_STYLE.get(l.get("st")) if y is not None else None, TV_SIZE.get(l.get("sz")) if y is not None else None)] += 1
    lines = Counter()
    for l in d["lines"]:
        y1, y2 = price(l.get("y1")), price(l.get("y2"))
        if y1 is None:
            lines[("na",)] += 1
            continue
        lines[(tv_time(l["x1"]), y1, tv_time(l["x2"]), y2, abgr_to_rgb(l.get("ci")), TV_LINE_STYLE.get(l.get("st")))] += 1
    boxes = Counter()
    for b in d["boxes"]:
        top, bottom = price(b.get("y1")), price(b.get("y2"))
        if top is None:
            boxes[("na",)] += 1
            continue
        ext = b.get("ex") == "r"
        boxes[(tv_time(b["x1"]), top, None if ext else tv_time(b["x2"]), bottom, abgr_to_argb(b.get("bc")), abgr_to_argb(b.get("c")), ext)] += 1
    candles = {r[1]: abgr_to_rgb(r[6]) for r in d["studyBars"]}
    return labels, lines, boxes, candles, last_index, times


def load_mt5(cfg, last_time, bar_times):
    labels, lines, boxes, candles = Counter(), Counter(), Counter(), {}

    import bisect

    def t(v):
        # same rule as the renderer and TradingView: a time between two bars goes on the next bar
        if v == "na":
            return None
        v = int(v)
        if v > last_time:
            return "future"
        return bar_times[bisect.bisect_left(bar_times, v)]

    with open(os.path.join(MT5_FILES, f"mt5_{cfg}.csv"), newline="") as f:
        for row in csv.reader(f):
            kind = row[0]
            if kind == "bar":
                candles[int(row[1])] = int(row[2])
            elif kind == "label":
                _, _id, keep, x, y, text, rgb, style, size = row
                y = price(y)
                if y is None:
                    labels[(text, None, None, None, None, None)] += 1
                else:
                    labels[(text, t(x), y, rgb, int(style), int(size))] += 1
            elif kind == "line":
                _, _id, keep, x1, y1, x2, y2, rgb, style = row
                if price(y1) is None:
                    lines[("na",)] += 1
                else:
                    lines[(t(x1), price(y1), t(x2), price(y2), rgb, int(style))] += 1
            elif kind == "box":
                _, _id, keep, left, top, right, bottom, bg, border, ext = row
                if price(top) is None:
                    boxes[("na",)] += 1
                else:
                    ext = ext == "1"
                    boxes[(t(left), price(top), None if ext else t(right), price(bottom), bg, border, ext)] += 1
    return labels, lines, boxes, candles


def period_extremes(times_by_index, bars, kind):
    """high / low of the previous week or month, from the chart bars (what MT5 W1 / MN1 contain)"""
    last = dt.datetime.fromtimestamp(max(bars), dt.UTC)
    if kind == "W":
        start = (last - dt.timedelta(days=last.weekday())).replace(hour=0, minute=0, second=0, microsecond=0)
        a, b = start - dt.timedelta(days=7), start
    else:
        b = last.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
        a = (b - dt.timedelta(days=1)).replace(day=1)
    sel = [v for t, v in bars.items() if a.timestamp() <= t < b.timestamp()]
    return round(max(v[0] for v in sel), 6), round(min(v[1] for v in sel), 6)


BARS_HL = {}


def explain_levels(cfg, tv_labels, m_labels, tv_lines, m_lines, times):
    d = json.load(open(os.path.join(HERE, f"tv_{base(cfg)}.json")))
    bars = {r[1]: (r[3], r[4]) for r in d["studyBars"]}
    for kind in "WM":
        hi, lo = period_extremes(times, bars, kind)
        for tag, true in ((f"P{kind}H", hi), (f"P{kind}L", lo)):
            tv = [k for k in tv_labels if k[0] == tag]
            mt = [k for k in m_labels if k[0] == tag]
            if not tv or not mt or tv[0] == mt[0]:
                continue
            if mt[0][2] == true and tv[0][1:2] == mt[0][1:2] and tv[0][3:] == mt[0][3:]:
                print(f"  note     {tag}: TradingView {tv[0][2]} (its own {kind} bar), MT5 {mt[0][2]} = true extreme of the bars, same anchor")
                tv_labels[tv[0]] -= 1
                tv_labels[mt[0]] += 1
                # the matching line: same anchor time, same price change
                for k in list(tv_lines):
                    if len(k) > 1 and k[1] == tv[0][2] and k[3] == tv[0][2]:
                        fixed = (k[0], true, k[2], true) + k[4:]
                        if m_lines[fixed]:
                            tv_lines[k] -= 1
                            tv_lines[fixed] += 1
                        break
    for c in (tv_labels, tv_lines):
        for k in [k for k, v in c.items() if v <= 0]:
            del c[k]


def diff(name, tv, mt5, show=8):
    only_tv, only_mt5 = tv - mt5, mt5 - tv
    ok = not only_tv and not only_mt5
    print(f"  {name:8s} TradingView {sum(tv.values()):5d}   MT5 {sum(mt5.values()):5d}   identical {sum((tv & mt5).values()):5d}   {'OK' if ok else 'DIFF'}")
    for k, v in list(only_tv.items())[:show]:
        print("     only TV  ", v, k)
    for k, v in list(only_mt5.items())[:show]:
        print("     only MT5 ", v, k)
    return ok


def main():
    all_ok = True
    for cfg in sys.argv[1:]:
        tv_labels, tv_lines, tv_boxes, tv_candles, last_index, times = load_tv(cfg)
        last_time = times[last_index]
        m_labels, m_lines, m_boxes, m_candles = load_mt5(cfg, last_time, sorted(times.values()))
        mono = CONFIGS[base(cfg)].get("styleInput") == "MONOCHROME"
        palette = ["B2B5BE", "5D606B"] if mono else ["089981", "F23645"]
        m_candles = {t: palette[c] for t, c in m_candles.items()}
        # weekly / monthly levels: TradingView reads its own W and M bars, MT5 aggregates the chart bars.
        # A level differing only by its price is accepted when MT5's price is the true extreme of the bars.
        print(f"config {cfg}: {len(tv_candles)} bars")
        explain_levels(cfg, tv_labels, m_labels, tv_lines, m_lines, times)
        ok = diff("labels", tv_labels, m_labels)
        ok = diff("lines", tv_lines, m_lines) and ok
        ok = diff("boxes", tv_boxes, m_boxes) and ok
        same = sum(1 for t, c in tv_candles.items() if m_candles.get(t) == c)
        print(f"  candles  trend color identical on {same}/{len(tv_candles)} bars   {'OK' if same == len(tv_candles) else 'DIFF'}")
        bad = [t for t, c in tv_candles.items() if m_candles.get(t) != c][:5]
        if bad:
            print("     first differing bars", bad)
        ok = ok and same == len(tv_candles)
        all_ok = all_ok and ok
    print("ALL IDENTICAL" if all_ok else "DIFFERENCES FOUND")


if __name__ == "__main__":
    main()
