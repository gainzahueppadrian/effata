//+------------------------------------------------------------------+
//|                                       PO3_Integration.mqh   |
//|                      Integration Library for PO3Candle PO3      |
//|                      with CRT XAUUSD EA                          |
//+------------------------------------------------------------------+
#property copyright "2025, Manus AI - PO3 Integration"
#property link      "https://www.mql5.com"
#property strict

#include "../Core/CompatMQL4.mqh"

//+------------------------------------------------------------------+
//| HTF PO3Candle Data Structure                                        |
//+------------------------------------------------------------------+
struct PO3Candle
{
   datetime time;
   double open;
   double high;
   double low;
   double close;
   double range;
   bool isBullish;

   // PO3 Specific
   double po3High;
   double po3Low;
   double po3Mid;
   int po3Phase;        // 0=Undefined, 1=Accumulation, 2=Manipulation, 3=Distribution
   string po3PhaseText;

   // Price Zones
   double premiumZone;  // 61.8% level
   double discountZone; // 38.2% level
   double equilibrium;  // 50% level
};

//+------------------------------------------------------------------+
//| HTF PO3 Analyzer Class                                           |
//+------------------------------------------------------------------+
class PO3_Analyzer
{
private:
   string m_symbol;
   ENUM_TIMEFRAMES m_htfPeriod;

   PO3Candle m_currentPO3Candle;
   PO3Candle m_previousHTF;

   datetime m_lastUpdateTime;

   // Confluence tracking
   bool m_priceConfluence;
   bool m_timeConfluence;
   bool m_po3Confluence;

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   PO3_Analyzer(string symbol, ENUM_TIMEFRAMES htfPeriod)
   {
      m_symbol = symbol;
      m_htfPeriod = htfPeriod;
      m_lastUpdateTime = 0;

      m_priceConfluence = false;
      m_timeConfluence = false;
      m_po3Confluence = false;

      UpdatePO3Candle();
   }

   //+------------------------------------------------------------------+
   //| Update HTF PO3Candle Data                                          |
   //+------------------------------------------------------------------+
   void UpdatePO3Candle()
   {
      // Store previous PO3Candle
      m_previousHTF = m_currentPO3Candle;

      // Get current HTF PO3Candle
      datetime htfTime = iTime(m_symbol, m_htfPeriod, 0);

      if(htfTime == m_lastUpdateTime)
         return; // No update needed

      m_lastUpdateTime = htfTime;

      // Update current PO3Candle data
      m_currentPO3Candle.time = htfTime;
      m_currentPO3Candle.open = iOpen(m_symbol, m_htfPeriod, 0);
      m_currentPO3Candle.high = iHigh(m_symbol, m_htfPeriod, 0);
      m_currentPO3Candle.low = iLow(m_symbol, m_htfPeriod, 0);
      m_currentPO3Candle.close = iClose(m_symbol, m_htfPeriod, 0);
      m_currentPO3Candle.range = m_currentPO3Candle.high - m_currentPO3Candle.low;
      m_currentPO3Candle.isBullish = (m_currentPO3Candle.close >= m_currentPO3Candle.open);

      // Calculate PO3 levels
      m_currentPO3Candle.po3High = m_currentPO3Candle.high;
      m_currentPO3Candle.po3Low = m_currentPO3Candle.low;
      m_currentPO3Candle.po3Mid = (m_currentPO3Candle.high + m_currentPO3Candle.low) / 2.0;

      // Calculate Fibonacci levels
      m_currentPO3Candle.equilibrium = m_currentPO3Candle.po3Mid;
      m_currentPO3Candle.premiumZone = m_currentPO3Candle.low + m_currentPO3Candle.range * 0.618;
      m_currentPO3Candle.discountZone = m_currentPO3Candle.low + m_currentPO3Candle.range * 0.382;

      // Analyze PO3 phase
      AnalyzePO3Phase();
   }

   //+------------------------------------------------------------------+
   //| Analyze PO3 Phase                                                |
   //+------------------------------------------------------------------+
   void AnalyzePO3Phase()
   {
      double currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      double range = m_currentPO3Candle.range;

      // Get previous HTF data for comparison
      double prevHigh = iHigh(m_symbol, m_htfPeriod, 1);
      double prevLow = iLow(m_symbol, m_htfPeriod, 1);

      // Safety check for zero range
      if(range == 0) range = _Point;
      double prevRange = prevHigh - prevLow;
      if(prevRange == 0) prevRange = _Point;

      // Phase 1: Accumulation
      // Price consolidating in middle third of range
      if(currentPrice > m_currentPO3Candle.low + range * 0.33 &&
         currentPrice < m_currentPO3Candle.high - range * 0.33 &&
         range < prevRange * 0.7) // Range contraction
      {
         m_currentPO3Candle.po3Phase = 1;
         m_currentPO3Candle.po3PhaseText = "ACCUMULATION";
      }
      // Phase 2: Manipulation (Judas Swing)
      // Price purges liquidity (sweeps high/low) then reverses
      else if((m_currentPO3Candle.high > prevHigh && currentPrice < prevHigh) || // Bearish manipulation
              (m_currentPO3Candle.low < prevLow && currentPrice > prevLow))       // Bullish manipulation
      {
         m_currentPO3Candle.po3Phase = 2;
         m_currentPO3Candle.po3PhaseText = "MANIPULATION";
      }
      // Phase 3: Distribution
      // Strong directional move, price beyond previous range
      else if((currentPrice > prevHigh + range * 0.3) ||  // Bullish distribution
              (currentPrice < prevLow - range * 0.3))      // Bearish distribution
      {
         m_currentPO3Candle.po3Phase = 3;
         m_currentPO3Candle.po3PhaseText = "DISTRIBUTION";
      }
      else
      {
         m_currentPO3Candle.po3Phase = 0;
         m_currentPO3Candle.po3PhaseText = "UNDEFINED";
      }
   }

   //+------------------------------------------------------------------+
   //| Check Price Confluence                                           |
   //+------------------------------------------------------------------+
   bool CheckPriceConfluence(int direction)
   {
      double currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);

      // For Buy: Price should be in discount zone
      if(direction == 1)
      {
         m_priceConfluence = (currentPrice <= m_currentPO3Candle.discountZone);
      }
      // For Sell: Price should be in premium zone
      else if(direction == -1)
      {
         m_priceConfluence = (currentPrice >= m_currentPO3Candle.premiumZone);
      }

      return m_priceConfluence;
   }

   //+------------------------------------------------------------------+
   //| Check Time Confluence (within HTF PO3Candle timing)                |
   //+------------------------------------------------------------------+
   bool CheckTimeConfluence(int targetHour1, int targetHour2, int targetHour3)
   {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      int currentHour = dt.hour;

      // Check if current time is within key hours
      m_timeConfluence = (currentHour == targetHour1 ||
                          currentHour == targetHour2 ||
                          currentHour == targetHour3);

      return m_timeConfluence;
   }

   //+------------------------------------------------------------------+
   //| Check PO3 Confluence                                             |
   //+------------------------------------------------------------------+
   bool CheckPO3Confluence(int direction)
   {
      // For Buy: Should be in Manipulation or Distribution phase (bullish)
      if(direction == 1)
      {
         m_po3Confluence = (m_currentPO3Candle.po3Phase == 2 || m_currentPO3Candle.po3Phase == 3) &&
                           m_currentPO3Candle.isBullish;
      }
      // For Sell: Should be in Manipulation or Distribution phase (bearish)
      else if(direction == -1)
      {
         m_po3Confluence = (m_currentPO3Candle.po3Phase == 2 || m_currentPO3Candle.po3Phase == 3) &&
                           !m_currentPO3Candle.isBullish;
      }

      return m_po3Confluence;
   }

   //+------------------------------------------------------------------+
   //| Get Complete Confluence Analysis                                |
   //+------------------------------------------------------------------+
   bool GetCompleteConfluence(int direction, int hour1, int hour2, int hour3)
   {
      UpdatePO3Candle();

      bool priceOK = CheckPriceConfluence(direction);
      bool timeOK = CheckTimeConfluence(hour1, hour2, hour3);
      bool po3OK = CheckPO3Confluence(direction);

      PrintFormat("HTF Confluence Check - Price: %s | Time: %s | PO3: %s",
                  priceOK ? "✓" : "✗",
                  timeOK ? "✓" : "✗",
                  po3OK ? "✓" : "✗");

      return (priceOK && timeOK && po3OK);
   }

   //+------------------------------------------------------------------+
   //| Get Current HTF PO3Candle                                           |
   //+------------------------------------------------------------------+
   PO3Candle GetCurrentHTF() { return m_currentPO3Candle; }

   //+------------------------------------------------------------------+
   //| Get Previous HTF PO3Candle                                          |
   //+------------------------------------------------------------------+
   PO3Candle GetPreviousHTF() { return m_previousHTF; }

   //+------------------------------------------------------------------+
   //| Get PO3 Phase                                                    |
   //+------------------------------------------------------------------+
   int GetPO3Phase() { return m_currentPO3Candle.po3Phase; }

   //+------------------------------------------------------------------+
   //| Get PO3 Phase Text                                               |
   //+------------------------------------------------------------------+
   string GetPO3PhaseText() { return m_currentPO3Candle.po3PhaseText; }

   //+------------------------------------------------------------------+
   //| Check if Price is in Premium Zone                               |
   //+------------------------------------------------------------------+
   bool IsInPremiumZone()
   {
      double currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      return (currentPrice >= m_currentPO3Candle.premiumZone);
   }

   //+------------------------------------------------------------------+
   //| Check if Price is in Discount Zone                              |
   //+------------------------------------------------------------------+
   bool IsInDiscountZone()
   {
      double currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      return (currentPrice <= m_currentPO3Candle.discountZone);
   }

   //+------------------------------------------------------------------+
   //| Check if Price is at Equilibrium                                |
   //+------------------------------------------------------------------+
   bool IsAtEquilibrium()
   {
      double currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      double tolerance = m_currentPO3Candle.range * 0.05; // 5% tolerance

      return (MathAbs(currentPrice - m_currentPO3Candle.equilibrium) <= tolerance);
   }

   //+------------------------------------------------------------------+
   //| Get Entry Signal Based on HTF PO3                               |
   //+------------------------------------------------------------------+
   int GetEntrySignal()
   {
      UpdatePO3Candle();

      // Bullish Signal: Manipulation/Distribution phase + Discount zone
      if((m_currentPO3Candle.po3Phase == 2 || m_currentPO3Candle.po3Phase == 3) &&
         IsInDiscountZone() &&
         m_currentPO3Candle.isBullish)
      {
         return 1; // Buy signal
      }

      // Bearish Signal: Manipulation/Distribution phase + Premium zone
      if((m_currentPO3Candle.po3Phase == 2 || m_currentPO3Candle.po3Phase == 3) &&
         IsInPremiumZone() &&
         !m_currentPO3Candle.isBullish)
      {
         return -1; // Sell signal
      }

      return 0; // No signal
   }

   //+------------------------------------------------------------------+
   //| Print HTF Analysis                                               |
   //+------------------------------------------------------------------+
   void PrintAnalysis()
   {
      PrintFormat("========== HTF PO3 ANALYSIS ==========");
      PrintFormat("Timeframe: %s", EnumToString(m_htfPeriod));
      PrintFormat("Time: %s", TimeToString(m_currentPO3Candle.time));
      PrintFormat("OHLC: O=%.2f H=%.2f L=%.2f C=%.2f",
                  m_currentPO3Candle.open, m_currentPO3Candle.high,
                  m_currentPO3Candle.low, m_currentPO3Candle.close);
      PrintFormat("Range: %.2f | Bullish: %s",
                  m_currentPO3Candle.range, m_currentPO3Candle.isBullish ? "Yes" : "No");
      PrintFormat("PO3 Phase: %s (%d)",
                  m_currentPO3Candle.po3PhaseText, m_currentPO3Candle.po3Phase);
      PrintFormat("PO3 Levels - High: %.2f | Mid: %.2f | Low: %.2f",
                  m_currentPO3Candle.po3High, m_currentPO3Candle.po3Mid, m_currentPO3Candle.po3Low);
      PrintFormat("Fib Levels - Premium: %.2f | Eq: %.2f | Discount: %.2f",
                  m_currentPO3Candle.premiumZone, m_currentPO3Candle.equilibrium,
                  m_currentPO3Candle.discountZone);

      double currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      string zone = "EQUILIBRIUM";
      if(IsInPremiumZone()) zone = "PREMIUM";
      else if(IsInDiscountZone()) zone = "DISCOUNT";

      PrintFormat("Current Price: %.2f | Zone: %s", currentPrice, zone);
      PrintFormat("======================================");
   }
};
