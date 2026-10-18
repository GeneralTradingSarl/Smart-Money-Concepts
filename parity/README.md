# Parity test bench: TradingView vs MetaTrader 5

Everything needed to check that `SmartMoneyConcepts.mq5` draws exactly what LuxAlgo's
*Smart Money Concepts (SMC) [LuxAlgo]* draws on TradingView, on the same bars.

```bash
python parity/compare.py A B C D Art Brt
```

prints, for each configuration, the number of labels, lines and boxes on each platform, how many
have an identical twin on the other side, and the trend colour of every candle. Expected last line:
`ALL IDENTICAL`.

## Files

| File | What |
|---|---|
| `luxalgo_smc_original.pine` | the original script, unmodified (© LuxAlgo, CC BY-NC-SA 4.0) |
| `pine_A.pine` ... `pine_D.pine` | the same script with the input defaults of each configuration (`make_pine.py`) |
| `configs.py` | the four configurations, shared by the Pine variants and the MQL5 test builds |
| `tv_A.json` ... `tv_D.json` | what TradingView drew: every label, line and box, plus the bars the script ran on (`tv_export.mjs`) |
| `results/mt5_*.csv` | what MetaTrader 5 drew on the same bars (`SMC_ParityRun.mq5`, `SMC_RealtimeRun.mq5` for the tick-by-tick replays `Art`, `Brt`) |
| `results/bars.csv` | the 5,044 AAPL 15-minute bars |
| `compare.py` | the comparison, object by object |
| `probe_eps.pine`, `probe_float.pine` | the probes that measured Pine's 1e-10 float tolerance |

## Configurations

- **A**: original defaults, with coloured candles on so the trend of every bar is exported
- **B**: every feature on (swing points, swing order blocks, FVG, daily / weekly / monthly levels, zones)
- **C**: Present mode, Monochrome, confluence filter, cumulative mean range, Close mitigation, 20-bar swings, EQH/EQL threshold 0.3, FVG on 30 minutes without auto threshold
- **D**: config C in Historical mode, which pushes Pine to its 500-label limit

## The one known difference

Weekly and monthly levels (PWH, PWL, PMH, PML): TradingView reads them from its own W and M bars,
MT5 rebuilds them from the chart's bars. `compare.py` accepts a level that differs only by its price
when the MT5 price is the true extreme of the chart's bars, and prints a `note` line for it. The anchors
are identical. On a live MT5 account, W1 and MN1 come from the same feed as the chart.

## Re-running the exports

The exports were produced on TradingView Desktop (driven over the Chrome DevTools protocol, `tv_run.sh`,
`tv_export.mjs`) and on a MetaTrader 5 terminal with a custom symbol holding the same bars
(`mt5_prepare.sh`, `make_mq5.py`, `SMC_ParityRun.mq5`). Paths in those scripts point at the author's
machine; adapt them to yours. Set `SMC_MT5_FILES` to read a fresh MT5 run straight from
`MQL5\Files\smc_parity`.
