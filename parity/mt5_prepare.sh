#!/usr/bin/env bash
# usage: bash mt5_prepare.sh "A,B,C"   (bars come from tv_<first cfg>.json)
# Writes MQL5\Files\smc_parity\bars.csv, builds and compiles the test indicators and the runner script.
set -u
cd "$(dirname "$0")"
ME5="/c/Program Files/MetaTrader 5 EXNESS/metaeditor64.exe"
T5="/c/Users/HP/AppData/Roaming/MetaQuotes/Terminal/53785E099C927DB68A545C249CDBCE06/MQL5"
cfgs="$1"
first="${cfgs%%,*}"
mkdir -p "$T5/Files/smc_parity" "$T5/Indicators/smc_test"
n=$(python - "$first" "$T5/Files/smc_parity/bars.csv" <<'PY'
import json, sys
d = json.load(open(f"tv_{sys.argv[1]}.json"))
rows = sorted(d["studyBars"], key=lambda r: r[1])
with open(sys.argv[2], "w", newline="\n") as f:
    for r in rows:
        f.write(f"{r[1]},{r[2]!r},{r[3]!r},{r[4]!r},{r[5]!r}\n")
print(len(rows))
PY
)
echo "bars: $n"
compile() {
  "$ME5" /compile:"$(cygpath -w "$1")" /log:"$(cygpath -w "$PWD/compile_$2.log")"
  python -c "
import sys
b = open(sys.argv[1], 'rb').read()
try: s = b.decode('utf-16')
except Exception: s = b.decode('latin-1')
print(sys.argv[2], '->', s.strip().splitlines()[-1])" "compile_$2.log" "$2"
}
for c in ${cfgs//,/ }; do
  python make_mq5.py "$n" "$c" >/dev/null
  cp "SMC_Test_$c.mq5" "$T5/Indicators/smc_test/"
  compile "$T5/Indicators/smc_test/SMC_Test_$c.mq5" "SMC_Test_$c"
done
sed "s/^input string Configs = \"[^\"]*\"/input string Configs = \"$cfgs\"/" SMC_ParityRun.mq5 > "$T5/Scripts/SMC_ParityRun.mq5"
compile "$T5/Scripts/SMC_ParityRun.mq5" SMC_ParityRun
