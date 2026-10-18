"""Write a Pine copy of the LuxAlgo original whose input DEFAULTS follow a test config (logic untouched).
A probe table is appended: it shows the first bar time and the last bar_index the server computed on
(tables do not count in the 500 labels / lines / boxes)."""
import re
import sys
from configs import CONFIGS

PINE_ENUM = {"PRESENT": "PRESENT", "HISTORICAL": "HISTORICAL", "COLORED": "COLORED", "ATR": "ATR", "HIGHLOW": "HIGHLOW", "MONOCHROME": "MONOCHROME", "RANGE": "RANGE", "CLOSE": "CLOSE"}

PROBE = """
var int probeFirstTime = time
var table probeTable = table.new(position.bottom_right, 1, 1)
if barstate.islast
    table.cell(probeTable, 0, 0, str.tostring(probeFirstTime) + '|' + str.tostring(bar_index))
"""


def pine_value(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, str):
        return PINE_ENUM.get(v, "'" + v + "'")
    return str(v)


def make(name):
    src = open("luxalgo_smc_original.pine", encoding="utf-8").read()
    for key, value in CONFIGS[name].items():
        # first argument of the input.*() call that defines `key`
        pat = re.compile(r"^(" + re.escape(key) + r"\s*=\s*input(?:\.\w+)?\(\s*)([^,]+?)(\s*,)", re.M)
        src, n = pat.subn(lambda m: m.group(1) + pine_value(value) + m.group(3), src, count=1)
        assert n == 1, key
    src = src.replace("indicator('Smart Money Concepts [LuxAlgo]'", "indicator('Smart Money Concepts [LuxAlgo] test " + name + "'", 1)
    src += PROBE
    out = "pine_" + name + ".pine"
    with open(out, "w", encoding="utf-8", newline="\n") as f:
        f.write(src)
    return out


if __name__ == "__main__":
    for n in sys.argv[1:]:
        print(make(n))
