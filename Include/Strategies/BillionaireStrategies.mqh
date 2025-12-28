//+------------------------------------------------------------------+
//| BillionaireStrategies.mqh                                        |
//| Strategies from Billionaire Trading Bot                          |
//| Copyright 2025, EFFATA Reinforcement Trading Systems             |
//+------------------------------------------------------------------+
#property copyright "2025, EFFATA Reinforcement Trading Systems"
#property version   "1.00"
#property strict

#include "../Indicators/MultiPivots.mqh"
#include "../Indicators/CurrencyStrength.mqh"
#include "../Core/CompatMQL4.mqh"

// Base Strategy Interface
class IStrategy {
public:
   virtual string GetName() { return "Unknown"; }
   virtual void Calculate() {}
   virtual int GetSignal() { return 0; } // 1 Buy, -1 Sell, 0 None
};

//+------------------------------------------------------------------+
//| StrategyPivotsDay                                                |
//+------------------------------------------------------------------+
class StrategyPivotsDay : public IStrategy {
public:
   TypePivotsData pivotsdata;
   datetime lastdaysignal;

   StrategyPivotsDay() {
      pivotsdata.Settings.draw=true;
      pivotsdata.Settings.PivotTypeHour=PIVOT_FIBONACCI;
      pivotsdata.Settings.PivotTypeFourHour=PIVOT_FIBONACCI;
      pivotsdata.Settings.PivotTypeDay=PIVOT_FIBONACCI;
      pivotsdata.Settings.PivotTypeWeek=PIVOT_FIBONACCI;
      lastdaysignal=0;
   }

   string GetName() override { return "PivotsDay"; }

   void Calculate() override {
      // Calculation logic called every tick/bar
      MqlRates rates[];
      int copied = CopyRates(NULL, PERIOD_M1, 0, 1, rates);
      if(copied > 0) pivotsdata.Calculate(rates[0].time);
   }

   int GetSignal() override {
      // Logic from user snippet
      double upperlevel=pivotsdata.PivotsDay.R1;
      // ... check conditions
      double close = iClose(NULL, PERIOD_CURRENT, 0);
      if(close >= upperlevel) return -1; // Sell at R1
      return 0;
   }
};

//+------------------------------------------------------------------+
//| StrategyPivotsH4FibonacciR1S1Reversal                            |
//+------------------------------------------------------------------+
class StrategyPivotsH4FibonacciR1S1Reversal : public IStrategy {
public:
   TypePivotsData pivotsdata;

   StrategyPivotsH4FibonacciR1S1Reversal() {
      pivotsdata.Settings.PivotTypeFourHour=PIVOT_FIBONACCI;
   }

   string GetName() override { return "PivotsH4FiboRev"; }

   void Calculate() override {
       MqlRates rates[];
       int copied = CopyRates(NULL, PERIOD_M1, 0, 1, rates);
       if(copied > 0) pivotsdata.Calculate(rates[0].time);
   }

   int GetSignal() override {
       // Logic for H4 Reversal
       double upper = pivotsdata.PivotsFourHour.R1;
       double close = iClose(NULL, PERIOD_CURRENT, 0);

       if(close >= upper) return -1; // Reversal Sell
       return 0;
   }
};
