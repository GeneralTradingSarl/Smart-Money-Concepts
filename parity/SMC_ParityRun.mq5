//+------------------------------------------------------------------+
//|                                               SMC_ParityRun.mq5  |
//| TEST ONLY. Loads the TradingView bars of MQL5\Files\smc_parity\   |
//| bars.csv into a custom symbol, then for each test config opens a |
//| M15 chart, attaches Indicators\smc_test\SMC_Test_<cfg>, waits for|
//| its dump (smc_parity\mt5_<cfg>.csv) and closes the chart.        |
//+------------------------------------------------------------------+
input string Configs = "A";          // test configs, comma separated
input string TestSymbol = "SMCTEST"; // custom symbol

bool LoadBars(MqlRates &rates[])
  {
   int h = FileOpen("smc_parity\\bars.csv", FILE_READ | FILE_CSV | FILE_ANSI, ',');
   if(h == INVALID_HANDLE)
     {
      Print("bars.csv missing");
      return false;
     }
   int n = 0;
   while(!FileIsEnding(h))
     {
      string t = FileReadString(h);
      if(t == "")
         break;
      ArrayResize(rates, n + 1, 8192);
      rates[n].time        = (datetime)StringToInteger(t);
      rates[n].open        = StringToDouble(FileReadString(h));
      rates[n].high        = StringToDouble(FileReadString(h));
      rates[n].low         = StringToDouble(FileReadString(h));
      rates[n].close       = StringToDouble(FileReadString(h));
      rates[n].tick_volume = 1;
      rates[n].spread      = 0;
      rates[n].real_volume = 0;
      n++;
     }
   FileClose(h);
   return n > 0;
  }

void OnStart()
  {
   MqlRates rates[];
   if(!LoadBars(rates))
      return;
   int n = ArraySize(rates);
   bool exists = false;
   SymbolExist(TestSymbol, exists);
   if(!exists && !CustomSymbolCreate(TestSymbol, "SMC parity"))
     {
      Print("CustomSymbolCreate failed ", GetLastError());
      return;
     }
   CustomSymbolSetInteger(TestSymbol, SYMBOL_DIGITS, 3);
   CustomSymbolSetDouble(TestSymbol, SYMBOL_POINT, 0.001);
   CustomSymbolSetDouble(TestSymbol, SYMBOL_TRADE_TICK_SIZE, 0.001);
   SymbolSelect(TestSymbol, true);
   // rewrite the history only when it changed: a chart opened while it is rebuilt may see part of it
   MqlRates have[];
   int got = CopyRates(TestSymbol, PERIOD_M1, rates[0].time, rates[n - 1].time, have);
   if(got != n || have[0].time != rates[0].time || have[got - 1].time != rates[n - 1].time || have[got - 1].close != rates[n - 1].close)
     {
      CustomRatesDelete(TestSymbol, 0, LONG_MAX);
      int written = CustomRatesReplace(TestSymbol, rates[0].time, rates[n - 1].time + 60, rates);
      PrintFormat("custom symbol %s: %d bars read, %d written", TestSymbol, n, written);
      Sleep(3000);
     }
   else
      PrintFormat("custom symbol %s: %d bars already loaded", TestSymbol, n);

   string list[];
   int count = StringSplit(Configs, ',', list);
   for(int k = 0; k < count; k++)
     {
      string cfg = list[k];
      StringTrimLeft(cfg);
      StringTrimRight(cfg);
      string out = "smc_parity\\mt5_" + cfg + ".csv";
      FileDelete(out);
      long chart = ChartOpen(TestSymbol, PERIOD_M15);
      if(chart == 0)
        {
         Print("ChartOpen failed ", GetLastError());
         continue;
        }
      int handle = iCustom(TestSymbol, PERIOD_M15, "smc_test\\SMC_Test_" + cfg);
      if(handle == INVALID_HANDLE || !ChartIndicatorAdd(chart, 0, handle))
         Print("indicator ", cfg, " not attached ", GetLastError());
      uint start = GetTickCount();
      while(!FileIsExist(out) && GetTickCount() - start < 180000 && !IsStopped())
         Sleep(250);
      PrintFormat("config %s: %s in %u ms", cfg, FileIsExist(out) ? "dumped" : "TIMEOUT", GetTickCount() - start);
      Sleep(500);
      ChartClose(chart);
      IndicatorRelease(handle);
     }
  }
//+------------------------------------------------------------------+
