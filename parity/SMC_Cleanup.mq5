// TEST ONLY: removes the SMCTEST custom symbol used by the parity test
void OnStart()
  {
   for(long c = ChartFirst(); c >= 0; c = ChartNext(c))
      if(ChartSymbol(c) == "SMCTEST")
         ChartClose(c);
   Sleep(1000);
   SymbolSelect("SMCTEST", false);
   bool ok = CustomSymbolDelete("SMCTEST");
   PrintFormat("SMCTEST deleted: %s (%d)", ok ? "yes" : "no", GetLastError());
  }
