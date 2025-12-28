//+------------------------------------------------------------------+
//| CRTTheory.mqh                                                    |
//| Candle Range Theory Implementation                               |
//| Copyright 2025, EFFATA Reinforcement Trading Systems             |
//+------------------------------------------------------------------+
#property copyright "2025, EFFATA Reinforcement Trading Systems"
#property version   "1.00"
#property strict

#include "../Core/CompatMQL4.mqh"

class CCRTTheory {
private:
   string m_symbol;
   int m_atr_period;
   double m_large_mult;
   double m_small_mult;

public:
   bool isLarge;
   bool isSmall;
   bool isInside;
   bool isOutside;

   double crtHigh;
   double crtLow;

   CCRTTheory(string symbol) {
      m_symbol = symbol;
      m_atr_period = 14;
      m_large_mult = 1.5;
      m_small_mult = 0.5;
   }

   void Configure(int atrPeriod, double largeMult, double smallMult) {
      m_atr_period = atrPeriod;
      m_large_mult = largeMult;
      m_small_mult = smallMult;
   }

   bool Calculate(int index, ENUM_TIMEFRAMES timeframe=PERIOD_CURRENT) {
      double atr = iATR(m_symbol, timeframe, m_atr_period, index+1);
      double high = iHigh(m_symbol, timeframe, index);
      double low = iLow(m_symbol, timeframe, index);
      double range = high - low;

      double prevHigh = iHigh(m_symbol, timeframe, index+1);
      double prevLow = iLow(m_symbol, timeframe, index+1);

      crtHigh = high;
      crtLow = low;

      isLarge = (range > atr * m_large_mult);
      isSmall = (range < atr * m_small_mult);
      isInside = (high < prevHigh && low > prevLow);
      isOutside = (high > prevHigh && low < prevLow);

      return true;
   }

   int GetSignal() {
      // 1 for Bullish implication (e.g. purge low then close up), -1 for Bearish
      // This is a simplified logic derived from the provided snippets
      return 0;
   }
};
