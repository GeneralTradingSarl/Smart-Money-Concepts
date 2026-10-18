"""Build the MQL5 test variants: SmartMoneyConcepts.mq5 with the input DEFAULTS of a test config,
plus a dump of everything the indicator drew (written once, after the first full calculation).
The indicator logic itself is not touched."""
import re
import sys
from pathlib import Path
from configs import CONFIGS

HERE = Path(__file__).resolve().parent
SOURCE = HERE.parent / "SmartMoneyConcepts.mq5"
TIMEFRAMES = {"": "PERIOD_CURRENT", "15": "PERIOD_M15", "30": "PERIOD_M30", "60": "PERIOD_H1", "240": "PERIOD_H4", "D": "PERIOD_D1"}

DUMP = r'''
//+------------------------------------------------------------------+
//| TEST ONLY: dump of the drawing collection for the parity check   |
//+------------------------------------------------------------------+
bool gDumped = false;
string Num(const double v) { return v == NA ? "na" : DoubleToString(v, 6); }
string Tim(const long t)   { return t == NA_TIME ? "na" : IntegerToString(t); }
string Hex(const uint v)   { return StringFormat("%08X", v); }
string Rgb(const color c)  { return StringFormat("%02X%02X%02X", (int)(c & 0xFF), (int)((c >> 8) & 0xFF), (int)((c >> 16) & 0xFF)); }
void DumpOnce(void)
  {
   if(gDumped || gTotal < TEST_BARS)
      return;
   gDumped = true;
   int h = FileOpen("smc_parity\\mt5_" + TEST_NAME + ".csv", FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
   if(h == INVALID_HANDLE)
      return;
   FileWrite(h, "meta", gStart, gTotal, (long)gT[gStart], (long)gT[gTotal - 1]);
   for(int i = gStart; i < gTotal; i++)
      FileWrite(h, "bar", (long)gT[i], (int)bufferColor[i]);
   for(int k = 0; k < ArraySize(working.labels); k++)
     {
      PineLabel l = working.labels[k];
      long t = l.x == NA_TIME ? NA_TIME : (l.xIsTime ? l.x : (long)IndexTime(l.x));
      FileWrite(h, "label", l.id, (int)l.keep, Tim(t), Num(l.y), TextOf(l.text), Rgb(l.textColor), l.style, l.size);
     }
   for(int k = 0; k < ArraySize(working.lines); k++)
     {
      PineLine l = working.lines[k];
      FileWrite(h, "line", l.id, (int)l.keep, Tim(l.x1), Num(l.y1), Tim(l.x2), Num(l.y2), Rgb(l.lineColor), l.style);
     }
   for(int k = 0; k < ArraySize(working.boxes); k++)
     {
      PineBox b = working.boxes[k];
      FileWrite(h, "box", b.id, (int)b.keep, Tim(b.left), Num(b.top), Tim(b.right), Num(b.bottom), Hex(b.bgColor), Hex(b.borderColor), (int)b.extendRight);
     }
   FileClose(h);
  }
'''


def mql_value(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, str):
        return TIMEFRAMES.get(v, v)
    return str(v)


def make(name, bars, realtime=False):
    src = SOURCE.read_text(encoding="utf-8-sig")
    for key, value in CONFIGS[name].items():
        pat = re.compile(r"^(input\s+\S+\s+" + re.escape(key) + r"\s*=\s*)([^;]+?)(\s*;)", re.M)
        src, n = pat.subn(lambda m: m.group(1) + mql_value(value) + m.group(3), src, count=1)
        assert n == 1, key
    src = src.replace("#property indicator_chart_window",
                      '#property indicator_chart_window\n#define TEST_NAME "' + name + '"\n#define TEST_BARS ' + str(bars), 1)
    # dump right after the first full render
    marker = "   Render();\n   return rates_total;\n  }"
    assert src.count(marker) == 1
    src = src.replace(marker, "   Render();\n   DumpOnce();\n   return rates_total;\n  }")
    src += DUMP
    if realtime:
        once = "   if(gDumped || gTotal < TEST_BARS)\n      return;\n   gDumped = true;"
        assert src.count(once) == 1
        src = src.replace(once, "   if(gTotal < TEST_BARS)\n      return;")
        src = src.replace('#define TEST_NAME "' + name + '"', '#define TEST_NAME "' + name + 'rt"')
        name = name + "rt"
    out = HERE / ("SMC_Test_" + name + ".mq5")
    out.write_bytes(b"\xef\xbb\xbf" + src.encode("utf-8"))
    return out


if __name__ == "__main__":
    bars = int(sys.argv[1])
    for n in sys.argv[2:]:
        rt = n.endswith("rt")
        print(make(n[:-2] if rt else n, bars, rt))
