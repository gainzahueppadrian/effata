//+------------------------------------------------------------------+
//| HTF_PO3_Integration.mqh                                          |
//| Power of 3 (PO3) Analysis on Higher Timeframes                   |
//| Copyright 2025, EFFATA Reinforcement Trading Systems             |
//+------------------------------------------------------------------+
#property copyright "2025, EFFATA Reinforcement Trading Systems"
#property version   "1.00"
#property strict

struct PO3Candle {
   datetime time;
   double open;
   double high;
   double low;
   double close;
   double range;
   bool isBullish;

   int po3Phase; // 1=Accumulation, 2=Manipulation, 3=Distribution
   string po3PhaseText;

   double po3High;
   double po3Mid;
   double po3Low;

   double premiumZone;
   double discountZone;
   double equilibrium;
};

class CHTF_PO3_Analyzer {
private:
   string m_symbol;
   ENUM_TIMEFRAMES m_htfPeriod;
   PO3Candle m_currentPO3Candle;
   PO3Candle m_previousHTF;

   bool m_priceConfluence;
   bool m_timeConfluence;
   bool m_po3Confluence;

public:
   CHTF_PO3_Analyzer(string symbol, ENUM_TIMEFRAMES htfPeriod) {
      m_symbol = symbol;
      m_htfPeriod = htfPeriod;
      ZeroMemory(m_currentPO3Candle);
      ZeroMemory(m_previousHTF);
   }

   void UpdateHTFData() {
      UpdatePO3Candle();
   }

   void UpdatePO3Candle() {
      // Current Candle Data
      m_currentPO3Candle.time = iTime(m_symbol, m_htfPeriod, 0);
      m_currentPO3Candle.open = iOpen(m_symbol, m_htfPeriod, 0);
      m_currentPO3Candle.high = iHigh(m_symbol, m_htfPeriod, 0);
      m_currentPO3Candle.low = iLow(m_symbol, m_htfPeriod, 0);
      m_currentPO3Candle.close = iClose(m_symbol, m_htfPeriod, 0);

      m_currentPO3Candle.range = m_currentPO3Candle.high - m_currentPO3Candle.low;
      m_currentPO3Candle.isBullish = (m_currentPO3Candle.close > m_currentPO3Candle.open);

      // Calculate Levels
      m_currentPO3Candle.po3High = m_currentPO3Candle.high;
      m_currentPO3Candle.po3Low = m_currentPO3Candle.low;
      m_currentPO3Candle.po3Mid = (m_currentPO3Candle.high + m_currentPO3Candle.low) / 2.0;

      // Calculate Zones
      m_currentPO3Candle.equilibrium = m_currentPO3Candle.po3Mid;
      double range = m_currentPO3Candle.range;
      m_currentPO3Candle.premiumZone = m_currentPO3Candle.low + range * 0.75;
      m_currentPO3Candle.discountZone = m_currentPO3Candle.low + range * 0.25;

      AnalyzePO3Phase();
   }

   void AnalyzePO3Phase() {
      double currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      double range = m_currentPO3Candle.range;
      double prevHigh = iHigh(m_symbol, m_htfPeriod, 1);
      double prevLow = iLow(m_symbol, m_htfPeriod, 1);

      if(range == 0) range = Point();
      double prevRange = prevHigh - prevLow;
      if(prevRange == 0) prevRange = Point();

      // Phase 1: Accumulation (Consolidation)
      if(currentPrice > m_currentPO3Candle.low + range * 0.33 &&
         currentPrice < m_currentPO3Candle.high - range * 0.33 &&
         range < prevRange * 0.7)
      {
         m_currentPO3Candle.po3Phase = 1;
         m_currentPO3Candle.po3PhaseText = "ACCUMULATION";
      }
      // Phase 2: Manipulation (Sweep)
      else if((m_currentPO3Candle.high > prevHigh && currentPrice < prevHigh) ||
              (m_currentPO3Candle.low < prevLow && currentPrice > prevLow))
      {
         m_currentPO3Candle.po3Phase = 2;
         m_currentPO3Candle.po3PhaseText = "MANIPULATION";
      }
      // Phase 3: Distribution (Expansion)
      else if((currentPrice > prevHigh + range * 0.3) ||
              (currentPrice < prevLow - range * 0.3))
      {
         m_currentPO3Candle.po3Phase = 3;
         m_currentPO3Candle.po3PhaseText = "DISTRIBUTION";
      }
      else {
         m_currentPO3Candle.po3Phase = 0;
         m_currentPO3Candle.po3PhaseText = "UNDEFINED";
      }
   }

   bool IsInPremiumZone() {
      double currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      return (currentPrice >= m_currentPO3Candle.premiumZone);
   }

   bool IsInDiscountZone() {
      double currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      return (currentPrice <= m_currentPO3Candle.discountZone);
   }

   bool CheckTimeConfluence(int h1, int h2, int h3) {
       MqlDateTime dt;
       TimeToStruct(TimeCurrent(), dt);
       return (dt.hour == h1 || dt.hour == h2 || dt.hour == h3);
   }

   bool GetCompleteConfluence(int bias, int h1, int h2, int h3) {
       if(!CheckTimeConfluence(h1, h2, h3)) return false;
       if(bias == 1 && !IsInDiscountZone()) return false;
       if(bias == -1 && !IsInPremiumZone()) return false;
       return true;
   }

   PO3Candle GetCurrentHTF() { return m_currentPO3Candle; }
   string GetPO3PhaseText() { return m_currentPO3Candle.po3PhaseText; }

   void PrintAnalysis() {
       // Debug print
   }
};
