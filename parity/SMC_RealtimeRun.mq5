//+------------------------------------------------------------------+
//|                                             SMC_RealtimeRun.mq5  |
//| TEST ONLY. Real-time path: the custom symbol gets every bar but  |
//| the last `Tail` ones, the test indicator is attached, then those |
//| bars are replayed as ticks (open, extremes, close). The final    |
//| dump must equal what TradingView computed on history.           |
//+------------------------------------------------------------------+
input string Configs    = "Art,Brt";  // realtime test configs
input int    Tail       = 44;         // bars replayed tick by tick
input string TestSymbol = "SMCTEST";  // custom symbol

bool LoadBars(MqlRates &rates[])
  {
   int h = FileOpen("smc_parity\\bars.csv", FILE_READ | FILE_CSV | FILE_ANSI, ',');
   if(h == INVALID_HANDLE)
      return false;
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

void Tick(MqlTick &t, const datetime bar, const int offset, const double price)
  {
   t.time     = bar + offset;
   t.time_msc = (long)(bar + offset) * 1000;
   t.bid      = price;
   t.ask      = price;
   t.last     = 0;
   t.volume   = 0;
   t.volume_real = 0;
   t.flags    = TICK_FLAG_BID | TICK_FLAG_ASK;
  }

void OnStart()
  {
   MqlRates rates[];
   if(!LoadBars(rates))
      return;
   int n = ArraySize(rates);
   bool exists = false;
   SymbolExist(TestSymbol, exists);
   if(!exists)
      CustomSymbolCreate(TestSymbol, "SMC parity");
   SymbolSelect(TestSymbol, true);
   string list[];
   int count = StringSplit(Configs, ',', list);
   for(int k = 0; k < count; k++)
     {
      string cfg = list[k];
      CustomTicksDelete(TestSymbol, 0, LONG_MAX);
      CustomRatesDelete(TestSymbol, 0, LONG_MAX);
      MqlRates head[];
      ArrayCopy(head, rates, 0, 0, n - Tail);
      int written = CustomRatesReplace(TestSymbol, head[0].time, head[n - Tail - 1].time + 60, head);
      Sleep(3000);
      string out = "smc_parity\\mt5_" + cfg + ".csv";
      FileDelete(out);
      long chart = ChartOpen(TestSymbol, PERIOD_M15);
      int handle = iCustom(TestSymbol, PERIOD_M15, "smc_test\\SMC_Test_" + cfg);
      if(handle == INVALID_HANDLE || !ChartIndicatorAdd(chart, 0, handle))
         Print("indicator ", cfg, " not attached ", GetLastError());
      Sleep(3000);
      int ticks = 0;
      for(int b = n - Tail; b < n; b++)
        {
         MqlTick t[4];
         bool up = rates[b].close >= rates[b].open;
         Tick(t[0], rates[b].time, 0, rates[b].open);
         Tick(t[1], rates[b].time, 60, up ? rates[b].low : rates[b].high);
         Tick(t[2], rates[b].time, 120, up ? rates[b].high : rates[b].low);
         Tick(t[3], rates[b].time, 840, rates[b].close);
         for(int j = 0; j < 4; j++)
           {
            MqlTick one[1];
            one[0] = t[j];
            ticks += CustomTicksAdd(TestSymbol, one);
            Sleep(60);
           }
        }
      Sleep(4000);
      PrintFormat("realtime %s: %d history bars written, %d ticks added, dump %s", cfg, written, ticks, FileIsExist(out) ? "present" : "MISSING");
      ChartClose(chart);
      IndicatorRelease(handle);
     }
  }
//+------------------------------------------------------------------+
