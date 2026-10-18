"""Test configurations shared by the Pine variants (TradingView) and the MQL5 debug builds.
Each config overrides input defaults; names are the Pine/MQL5 input variable names."""

CONFIGS = {
    # A: original defaults (+ colored candles so that the study exports its open and the trend color of every bar)
    "A": {"showTrendInput": True},
    # B: every feature on
    "B": {"showTrendInput": True, "showSwingsInput": True, "showSwingOrderBlocksInput": True,
          "showFairValueGapsInput": True, "showDailyLevelsInput": True, "showWeeklyLevelsInput": True,
          "showMonthlyLevelsInput": True, "showPremiumDiscountZonesInput": True},
    # C: the other branches: present mode, monochrome, confluence, cumulative range, close mitigation,
    #    shorter swings, wider EQH/EQL threshold, FVG on a higher timeframe without auto threshold
    "C": {"showTrendInput": True, "modeInput": "PRESENT", "styleInput": "MONOCHROME",
          "internalFilterConfluenceInput": True, "orderBlockFilterInput": "RANGE",
          "orderBlockMitigationInput": "CLOSE", "swingsLengthInput": 20, "showSwingsInput": True,
          "showSwingOrderBlocksInput": True, "equalHighsLowsThresholdInput": 0.3,
          "showFairValueGapsInput": True, "fairValueGapsThresholdInput": False,
          "fairValueGapsTimeframeInput": "30", "fairValueGapsExtendInput": 3,
          "showPremiumDiscountZonesInput": True, "internalOrderBlocksSizeInput": 10},
    # D: C in historical mode, to see every structure behind the trend colors
    "D": {"showTrendInput": True, "modeInput": "HISTORICAL", "styleInput": "MONOCHROME",
          "internalFilterConfluenceInput": True, "orderBlockFilterInput": "RANGE",
          "orderBlockMitigationInput": "CLOSE", "swingsLengthInput": 20, "showSwingsInput": True,
          "showSwingOrderBlocksInput": True, "equalHighsLowsThresholdInput": 0.3,
          "showFairValueGapsInput": True, "fairValueGapsThresholdInput": False,
          "fairValueGapsTimeframeInput": "30", "fairValueGapsExtendInput": 3,
          "showPremiumDiscountZonesInput": True, "internalOrderBlocksSizeInput": 10},
}
