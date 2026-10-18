#!/usr/bin/env bash
# Run config <cfg> on TradingView: inject pine_<cfg>.pine, update the study, wait for its probe, export tv_<cfg>.json
set -u
cd "$(dirname "$0")"
cfg=$1
CLI="node C:/Users/HP/tradingview-mcp/src/cli/index.js"
$CLI pine set -f "$(cygpath -w "$PWD/pine_$cfg.pine")" >/dev/null
xy=$($CLI ui eval "(function(){var s=[...document.querySelectorAll('button')].find(function(x){return (x.getAttribute('title')||'')==='Save script'});var b=s.parentElement.querySelectorAll('button')[0];var r=b.getBoundingClientRect();return Math.round(r.x+r.width/2)+' '+Math.round(r.y+r.height/2);})()" | grep -o '"result": *"[0-9 ]*"' | grep -o '[0-9]* [0-9]*')
$CLI ui mouse $xy >/dev/null
for k in $(seq 1 40); do
  node -e "setTimeout(()=>{},3000)"
  name=$($CLI state | grep -o "Smart Money Concepts \[LuxAlgo\] test $cfg")
  probe=$($CLI data tables 2>&1 | tr -d '\n' | grep -o '"rows": *\[[^]]*\]' | grep -o '[0-9]*|[0-9]*')
  status=$($CLI ui eval "(function(){var o='';window.TradingViewApi._activeChartWidgetWV.value()._chartWidget.model().model().dataSources().forEach(function(s){if(s.metaInfo&&(s.metaInfo().description||'').indexOf('test $cfg')>=0){var v=s._status.value();o=v.type+(v.errorDescription?(' '+v.errorDescription.error):'')}});return o;})()" | grep -o '"result": *"[^"]*"')
  if [ -n "$name" ] && [ -n "$probe" ] && echo "$status" | grep -q '"2"'; then break; fi
done
echo "study=$name probe=$probe status=$status"
node tv_export.mjs "tv_$cfg.json"
