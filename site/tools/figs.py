"""Small SVG diagrams of each concept, in the indicator's own colours (LuxAlgo defaults)."""
UP, DN, BLUE, GRAY = "#089981", "#F23645", "#2157f3", "#878b94"
W, H = 300, 92
FONT = 'font-family="Trebuchet MS, Segoe UI, sans-serif"'


def y(v):
    return round(84 - v * 0.76, 1)


def candles(rows, x0=18, step=22, body=10, color=None):
    out = []
    for i, (o, h, l, c) in enumerate(rows):
        x = x0 + i * step
        col = color[i] if color else (UP if c >= o else DN)
        top, bot = y(max(o, c)), y(min(o, c))
        out.append(f'<line x1="{x}" y1="{y(h)}" x2="{x}" y2="{y(l)}" stroke="{col}" stroke-width="1.2"/>')
        out.append(f'<rect x="{x - body / 2}" y="{top}" width="{body}" height="{max(1.2, round(bot - top, 1))}" rx="1" fill="{col}"/>')
    return "".join(out)


def cx(i, x0=18, step=22):
    return x0 + i * step


def hline(i1, i2, v, col, dash="4 3", width=1.2):
    d = f' stroke-dasharray="{dash}"' if dash else ""
    return f'<line x1="{cx(i1)}" y1="{y(v)}" x2="{cx(i2)}" y2="{y(v)}" stroke="{col}" stroke-width="{width}"{d}/>'


def text(x, v, s, col, size=9, anchor="middle", dy=-3):
    return f'<text x="{x}" y="{y(v) + dy}" fill="{col}" font-size="{size}" text-anchor="{anchor}" {FONT}>{s}</text>'


def box(i1, v_top, v_bot, fill, alpha, right=None, border=None):
    x1 = cx(i1)
    x2 = right if right is not None else W
    b = f' stroke="{border}" stroke-width="1"' if border else ""
    return (f'<rect x="{x1}" y="{y(v_top)}" width="{x2 - x1}" height="{round(y(v_bot) - y(v_top), 1)}" '
            f'fill="{fill}" fill-opacity="{alpha}"{b}/>')


def svg(inner, label):
    return (f'<svg viewBox="0 0 {W} {H}" role="img" aria-label="{label}" xmlns="http://www.w3.org/2000/svg" '
            f'preserveAspectRatio="xMidYMid meet">{inner}</svg>')


def structure():
    rows = [(30, 38, 26, 36), (36, 50, 34, 48), (48, 60, 45, 56), (56, 57, 40, 42), (42, 46, 32, 35), (35, 48, 34, 47),
            (47, 58, 45, 56), (56, 72, 55, 69), (69, 75, 62, 64), (64, 66, 50, 52), (52, 54, 38, 40), (40, 43, 28, 31)]
    s = hline(2, 7, 60, UP) + text((cx(2) + cx(7)) / 2, 60, "BOS", UP)
    s += hline(6, 10, 45, DN) + text((cx(6) + cx(10)) / 2, 45, "CHoCH", DN, dy=10)
    return svg(candles(rows) + s, "Break of structure and change of character")


def order_blocks():
    rows = [(70, 72, 58, 60), (60, 62, 48, 50), (50, 52, 40, 42), (42, 50, 36, 38), (38, 62, 37, 60), (60, 74, 58, 72),
            (72, 76, 64, 66), (66, 68, 54, 56), (56, 58, 47, 52), (52, 66, 50, 64), (64, 78, 62, 76), (76, 82, 72, 80)]
    s = box(3, 50, 36, BLUE, 0.22)
    s += f'<line x1="{cx(3)}" y1="{y(50)}" x2="{W}" y2="{y(50)}" stroke="{BLUE}" stroke-opacity=".55"/>'
    s += text(W - 8, 41, "Bullish OB", "#7aa2ff", anchor="end", dy=4)
    return svg(s + candles(rows), "Bullish order block")


def equal_levels():
    rows = [(40, 52, 38, 50), (50, 70, 48, 64), (64, 66, 52, 54), (54, 58, 46, 56), (56, 70.4, 54, 60), (60, 62, 44, 46),
            (46, 48, 30, 32), (32, 40, 22, 38), (38, 44, 34, 36), (36, 38, 26, 30), (30, 34, 22.2, 33), (33, 46, 31, 44)]
    s = hline(1, 4, 70, DN, dash="1 2") + text((cx(1) + cx(4)) / 2, 70, "EQH", DN)
    s += hline(7, 10, 22, UP, dash="1 2") + text((cx(7) + cx(10)) / 2, 22, "EQL", UP, dy=10)
    return svg(candles(rows) + s, "Equal highs and equal lows")


def fvg():
    rows = [(20, 26, 16, 24), (24, 30, 22, 28), (28, 40, 26, 36), (36, 74, 35, 72), (72, 80, 52, 76), (76, 79, 62, 66),
            (66, 70, 56, 60), (60, 64, 50, 62), (62, 72, 60, 70), (70, 76, 66, 74), (74, 82, 72, 80), (80, 84, 74, 78)]
    s = box(2, 52, 40, "#00ff68", 0.22)
    s += text(W - 8, 46, "Bullish FVG", "#5df59b", anchor="end", dy=4)
    return svg(s + candles(rows), "Bullish fair value gap")


def zones():
    rows = [(40, 52, 30, 50), (50, 66, 46, 62), (62, 80, 58, 76), (76, 78, 60, 62), (62, 64, 44, 46), (46, 50, 30, 34),
            (34, 36, 15, 20), (20, 34, 18, 32), (32, 48, 30, 46), (46, 50, 38, 42), (42, 56, 40, 54), (54, 60, 46, 50)]
    s = box(0, 80, 71, DN, 0.18) + box(0, 49.5, 45.5, GRAY, 0.18) + box(0, 24, 15, UP, 0.18)
    s += text(W - 6, 75.5, "Premium", DN, anchor="end", dy=3) + text(W - 6, 47.5, "Equilibrium", GRAY, anchor="end", dy=3)
    s += text(W - 6, 19.5, "Discount", UP, anchor="end", dy=3)
    return svg(s + candles(rows, x0=14, step=19, body=9), "Premium, equilibrium and discount zones")


def swings():
    rows = [(30, 36, 20, 34), (34, 56, 32, 54), (54, 58, 40, 42), (42, 46, 30, 44), (44, 70, 42, 68), (68, 72, 56, 58),
            (58, 62, 48, 50), (50, 80, 48, 78), (78, 82, 70, 72), (72, 74, 62, 64), (64, 70, 60, 68), (68, 72, 64, 70)]
    s = text(cx(1), 56, "HH", DN) + text(cx(3), 30, "HL", UP, dy=10) + text(cx(4), 70, "HH", DN) + text(cx(6), 48, "HL", UP, dy=10)
    s += hline(7, 11, 82, DN, dash=None, width=1) + text(W - 8, 82, "Weak High", DN, anchor="end")
    s += hline(6, 11, 48, UP, dash=None, width=1) + text(W - 8, 48, "Strong Low", UP, anchor="end", dy=10)
    return svg(candles(rows) + s, "Swing points, strong low and weak high")


def levels():
    rows = [(40, 46, 34, 44), (44, 52, 42, 50), (50, 54, 40, 42), (42, 46, 30, 32), (32, 40, 28, 38), (38, 48, 36, 46),
            (46, 50, 38, 40), (40, 42, 32, 36), (36, 46, 34, 44), (44, 56, 42, 54)]
    s = ""
    for v, name in ((84, "PMH"), (70, "PWH"), (56, "PDH"), (20, "PDL")):
        s += f'<line x1="0" y1="{y(v)}" x2="{W - 34}" y2="{y(v)}" stroke="{BLUE}" stroke-width="1"/>'
        s += text(W - 30, v, name, "#7aa2ff", anchor="start", dy=3)
    return svg(s + candles(rows), "Previous day, week and month levels")


def alerts():
    rows = [(30, 36, 26, 34), (34, 42, 32, 40), (40, 50, 38, 48), (48, 52, 42, 46), (46, 58, 44, 56), (56, 64, 52, 60),
            (60, 62, 46, 48), (48, 50, 38, 40), (40, 44, 30, 32), (32, 36, 24, 26), (26, 30, 18, 20)]
    cols = [UP] * 6 + [DN] * 5
    s = hline(4, 8, 44, DN) + text((cx(4) + cx(8)) / 2, 44, "CHoCH", DN, dy=10)
    bell = ('<g transform="translate(262 10)" fill="none" stroke="#ffb020" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round">'
            '<path d="M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9"/><path d="M10.3 21a1.94 1.94 0 0 0 3.4 0"/></g>')
    return svg(candles(rows, color=cols) + s + bell, "Trend coloured candles and alerts")


def modes():
    left = "".join(text(18 + i * 26, 30 + (i % 3) * 14, t, c, size=8)
                   for i, (t, c) in enumerate([("BOS", UP), ("CHoCH", DN), ("BOS", DN), ("BOS", UP), ("CHoCH", UP)]))
    right = text(232, 52, "BOS", UP, size=9) + hline(9.4, 11.6, 52, UP)
    s = (f'<rect x="6" y="6" width="138" height="80" rx="8" fill="#ffffff" fill-opacity=".03" stroke="#ffffff" stroke-opacity=".08"/>'
         f'<rect x="156" y="6" width="138" height="80" rx="8" fill="#ffffff" fill-opacity=".03" stroke="#ffffff" stroke-opacity=".08"/>')
    s += f'<text x="75" y="80" fill="#9aa7b8" font-size="9" text-anchor="middle" {FONT}>Historical</text>'
    s += f'<text x="225" y="80" fill="#9aa7b8" font-size="9" text-anchor="middle" {FONT}>Present</text>'
    return svg(s + left + right, "Historical and present display modes")


FIGS = {"structure": structure, "ob": order_blocks, "eq": equal_levels, "fvg": fvg, "pd": zones, "sw": swings,
        "mtf": levels, "alerts": alerts, "modes": modes}


def all_figs():
    return {k: f() for k, f in FIGS.items()}
