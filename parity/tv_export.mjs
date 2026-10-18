// Export what the "Smart Money Concepts" study computed on TradingView:
//  - studyBars: the bars the script ran on (time, open, high, low, close, candle color) from its plotcandle()
//  - labels / lines / boxes: every drawing, x being a position in `indexes`
//  - indexes: drawing position -> chart bar index ; chartBars: chart bar index -> time
// usage: node tv_export.mjs <out.json>
import { evaluate } from 'file:///C:/Users/HP/tradingview-mcp/src/connection.js';
import { writeFileSync } from 'fs';
const js = `(function(){
  var chart = window.TradingViewApi._activeChartWidgetWV.value()._chartWidget;
  var model = chart.model().model();
  var out = {symbol: model.mainSeries().symbol(), labels: [], lines: [], boxes: [], studyBars: [], chartBars: []};
  model.dataSources().forEach(function(s){
    if (!s.metaInfo) return;
    var name = s.metaInfo().description || '';
    if (name.indexOf('Smart Money') < 0) return;
    out.study = name;
    try { out.status = s._status && s._status.value ? s._status.value() : null; } catch(e) {}
    var g = s._graphics, pc = g._primitivesCollection;
    out.indexes = g._indexes.slice();
    [['dwglabels','labels'],['dwglines','lines'],['dwgboxes','boxes']].forEach(function(p){
      var o = pc[p[0]]; if (!o) return; var inner = o.get(p[1]); if (!inner) return;
      var coll = inner.get(false); if (!coll) return;
      coll._primitivesDataById.forEach(function(v){ out[p[1]].push(v); });
    });
    var d = s.data(), seen = {};
    [[d.firstIndex(), d.firstIndex() + 400000], [-400000, d.lastIndex()]].forEach(function(r){
      for (var i = r[0]; i <= r[1]; i++) { var v = d.valueAt(i); if (v && !seen[i]) { seen[i] = 1; out.studyBars.push([i].concat(v.slice(0, 6))); } }
    });
  });
  var b = model.mainSeries().bars();
  for (var i = b.firstIndex(); i <= b.lastIndex(); i++) { var v = b.valueAt(i); if (v) out.chartBars.push([i, v[0], v[1], v[2], v[3], v[4]]); }
  return JSON.stringify(out);
})()`;
const r = await evaluate(js);
writeFileSync(process.argv[2], r);
const d = JSON.parse(r);
console.log(d.study, '|', d.symbol, 'studyBars', d.studyBars.length, 'chartBars', d.chartBars.length, 'labels', d.labels.length, 'lines', d.lines.length, 'boxes', d.boxes.length, 'indexes', d.indexes && d.indexes.length, 'status', JSON.stringify(d.status));
process.exit(0);
