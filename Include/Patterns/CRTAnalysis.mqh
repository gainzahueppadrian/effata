//+------------------------------------------------------------------+
//|                                          CRTAnalysis.mqh   |
//|                      Enhanced CRT Library with PO3 Integration   |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "2025, Manus AI - CRT Enhanced"
#property link      "https://www.mql5.com"
#property strict

#include "../Core/CompatMQL4.mqh"
#include "../Patterns/PO3_Integration.mqh"

//+------------------------------------------------------------------+
//| Structure for CRT Candle Analysis                                |
//+------------------------------------------------------------------+
struct CRTCandle
{
   datetime time;
   double high;
   double low;
   double open;
   double close;
   double atr;
   double trueRange;
   bool isLarge;
   bool isSmall;
   bool isInside;
   bool isOutside;
   int insideBarsCount;
   bool purgedHigh;
   bool purgedLow;
   double crtHigh;      // CRT High level
   double crtLow;       // CRT Low level
};

//+------------------------------------------------------------------+
//| Structure for Order Block                                        |
//+------------------------------------------------------------------+
struct SOrderBlock
{
   datetime time;
   double high;
   double low;
   double close;
   bool isBullish;
   bool isValid;
   bool isMitigated;
};

//+------------------------------------------------------------------+
//| Structure for Fair Value Gap                                     |
//+------------------------------------------------------------------+
struct SFairValueGap
{
   datetime time;
   double upper;
   double lower;
   bool isBullish;
   bool isFilled;
};

//+------------------------------------------------------------------+
//| Structure for PO3 Analysis (Power of 3)                          |
//+------------------------------------------------------------------+
struct SPO3Analysis
{
   bool inAccumulation;
   bool inManipulation;
   bool inDistribution;
   double accumulationLow;
   double accumulationHigh;
   double manipulationTarget;
   double distributionTarget;
   datetime accumulationTime;
   datetime manipulationTime;
   int phase; // 0=None, 1=Accumulation, 2=Manipulation, 3=Distribution
};

//+------------------------------------------------------------------+
//| CRT Pattern Class                                                |
//+------------------------------------------------------------------+
class CandleRangePattern
{
public:
   int    atrPeriod;
   double largeMult;
   double smallMult;

   bool   isLarge;
   bool   isSmall;
   bool   isInside;
   bool   isOutside;

   double crtHigh;
   double crtLow;

   CandleRangePattern() : atrPeriod(14), largeMult(1.5), smallMult(0.5),
                     isLarge(false), isSmall(false), isInside(false), isOutside(false),
                     crtHigh(0), crtLow(0) {}

   //+------------------------------------------------------------------+
   //| Calculate CRT Pattern for a specific bar                         |
   //+------------------------------------------------------------------+
   bool Calculate(int shift, const double &H[], const double &L[],
                  const double &O[], const double &C[], int total)
   {
      if(shift >= total - atrPeriod - 1) return false;

      // Calculate ATR
      double atr = CalculateATR(shift, H, L, C, total);
      if(atr <= 0) return false;

      // Current candle range
      double range = H[shift] - L[shift];

      // Previous candle
      double prevHigh = (shift + 1 < total) ? H[shift + 1] : 0;
      double prevLow  = (shift + 1 < total) ? L[shift + 1] : 0;

      // Determine candle type
      isLarge   = (range > atr * largeMult);
      isSmall   = (range < atr * smallMult);
      isInside  = (H[shift] <= prevHigh && L[shift] >= prevLow);
      isOutside = (H[shift] > prevHigh && L[shift] < prevLow);

      // Set CRT High/Low
      if(isLarge || isOutside)
      {
         crtHigh = H[shift];
         crtLow  = L[shift];
      }

      return true;
   }

   //+------------------------------------------------------------------+
   //| Calculate ATR (Average True Range)                               |
   //+------------------------------------------------------------------+
   double CalculateATR(int shift, const double &H[], const double &L[],
                       const double &C[], int total)
   {
      if(shift + atrPeriod >= total) return 0;

      double sum = 0;
      for(int i = shift; i < shift + atrPeriod; i++)
      {
         double tr = TrueRange(i, H, L, C, total);
         sum += tr;
      }

      return sum / atrPeriod;
   }

   //+------------------------------------------------------------------+
   //| Calculate True Range                                             |
   //+------------------------------------------------------------------+
   double TrueRange(int shift, const double &H[], const double &L[],
                    const double &C[], int total)
   {
      if(shift >= total - 1) return H[shift] - L[shift];

      double hl = H[shift] - L[shift];
      double hc = MathAbs(H[shift] - C[shift + 1]);
      double lc = MathAbs(L[shift] - C[shift + 1]);

      return MathMax(hl, MathMax(hc, lc));
   }
};

//+------------------------------------------------------------------+
//| CRT Analysis Class with Multi-Timeframe Support                  |
//+------------------------------------------------------------------+
class CCRTAnalysis
{
private:
   string m_symbol;
   ENUM_TIMEFRAMES m_htf1;      // Daily
   ENUM_TIMEFRAMES m_htf2;      // 4H
   ENUM_TIMEFRAMES m_entryTF;   // M15

   SOrderBlock m_orderBlocks[];
   SFairValueGap m_fvgList[];
   SPO3Analysis m_po3;

   int m_obLookback;

public:
   CCRTAnalysis(string symbol, ENUM_TIMEFRAMES htf1, ENUM_TIMEFRAMES htf2,
                ENUM_TIMEFRAMES entryTF, int obLookback = 50)
   {
      m_symbol = symbol;
      m_htf1 = htf1;
      m_htf2 = htf2;
      m_entryTF = entryTF;
      m_obLookback = obLookback;

      ArrayResize(m_orderBlocks, 0);
      ArrayResize(m_fvgList, 0);
      ResetPO3();
   }

   //+------------------------------------------------------------------+
   //| Reset PO3 Analysis                                               |
   //+------------------------------------------------------------------+
   void ResetPO3()
   {
      m_po3.inAccumulation = false;
      m_po3.inManipulation = false;
      m_po3.inDistribution = false;
      m_po3.accumulationLow = 0;
      m_po3.accumulationHigh = 0;
      m_po3.manipulationTarget = 0;
      m_po3.distributionTarget = 0;
      m_po3.phase = 0;
   }

   //+------------------------------------------------------------------+
   //| Get HTF Bias (1=Bullish, -1=Bearish, 0=Neutral)                 |
   //+------------------------------------------------------------------+
   int GetHTFBias(ENUM_TIMEFRAMES tf)
   {
      double close0 = iClose(m_symbol, tf, 0);
      double close1 = iClose(m_symbol, tf, 1);
      double close5 = iClose(m_symbol, tf, 5);

      // Simple trend detection: compare recent closes
      if(close0 > close5 && close1 > close5) return 1;  // Bullish
      if(close0 < close5 && close1 < close5) return -1; // Bearish

      return 0; // Neutral
   }

   //+------------------------------------------------------------------+
   //| Detect Order Blocks                                              |
   //+------------------------------------------------------------------+
   void DetectOrderBlocks(ENUM_TIMEFRAMES tf)
   {
      ArrayResize(m_orderBlocks, 0);

      for(int i = 1; i <= m_obLookback; i++)
      {
         double high0 = iHigh(m_symbol, tf, i);
         double low0  = iLow(m_symbol, tf, i);
         double close0 = iClose(m_symbol, tf, i);
         double open0 = iOpen(m_symbol, tf, i);

         double high_next = iHigh(m_symbol, tf, i - 1);
         double low_next  = iLow(m_symbol, tf, i - 1);

         // Bullish Order Block: Down candle followed by strong up move
         if(close0 < open0 && high_next > high0)
         {
            SOrderBlock ob;
            ob.time = iTime(m_symbol, tf, i);
            ob.high = high0;
            ob.low = low0;
            ob.close = close0;
            ob.isBullish = true;
            ob.isValid = true;
            ob.isMitigated = false;

            int size = ArraySize(m_orderBlocks);
            ArrayResize(m_orderBlocks, size + 1);
            m_orderBlocks[size] = ob;
         }

         // Bearish Order Block: Up candle followed by strong down move
         if(close0 > open0 && low_next < low0)
         {
            SOrderBlock ob;
            ob.time = iTime(m_symbol, tf, i);
            ob.high = high0;
            ob.low = low0;
            ob.close = close0;
            ob.isBullish = false;
            ob.isValid = true;
            ob.isMitigated = false;

            int size = ArraySize(m_orderBlocks);
            ArrayResize(m_orderBlocks, size + 1);
            m_orderBlocks[size] = ob;
         }
      }
   }

   //+------------------------------------------------------------------+
   //| Get Last Detected Order Block                                    |
   //+------------------------------------------------------------------+
   SOrderBlock GetOrderBlock()
   {
      SOrderBlock ob;
      if(ArraySize(m_orderBlocks) > 0)
         ob = m_orderBlocks[ArraySize(m_orderBlocks)-1];
      else {
         ob.isValid = false;
         ob.isBullish = false;
         ob.isMitigated = false;
         ob.high = 0;
         ob.low = 0;
         ob.close = 0;
         ob.time = 0;
      }
      return ob;
   }

   //+------------------------------------------------------------------+
   //| Detect Fair Value Gaps                                           |
   //+------------------------------------------------------------------+
   void DetectFVG(ENUM_TIMEFRAMES tf)
   {
      ArrayResize(m_fvgList, 0);

      for(int i = 1; i <= 50; i++)
      {
         double high0 = iHigh(m_symbol, tf, i);
         double low0  = iLow(m_symbol, tf, i);

         // FVG requires comparison with bars i+2 and i (skipping i+1 which is the middle bar of 3 bar pattern typically)
         // Assuming i is the newest bar of the 3-bar formation?
         // Actually FVG is gap between bar i and bar i+2 (where i+1 is the big move)
         // Let's assume typical 1-2-3 pattern where 3 is newest.
         // If i is the "gap" bar (the one before the move), we look forward.
         // Standard: Gap between High of Candle 1 and Low of Candle 3 (Bullish)

         double high2 = iHigh(m_symbol, tf, i + 2);
         double low2  = iLow(m_symbol, tf, i + 2);

         // Bullish FVG: Gap between candle 2 high and candle 0 low
         if(low0 > high2)
         {
            SFairValueGap fvg;
            fvg.time = iTime(m_symbol, tf, i);
            fvg.upper = low0;
            fvg.lower = high2;
            fvg.isBullish = true;
            fvg.isFilled = false;

            int size = ArraySize(m_fvgList);
            ArrayResize(m_fvgList, size + 1);
            m_fvgList[size] = fvg;
         }

         // Bearish FVG: Gap between candle 0 high and candle 2 low
         if(high0 < low2)
         {
            SFairValueGap fvg;
            fvg.time = iTime(m_symbol, tf, i);
            fvg.upper = low2;
            fvg.lower = high0;
            fvg.isBullish = false;
            fvg.isFilled = false;

            int size = ArraySize(m_fvgList);
            ArrayResize(m_fvgList, size + 1);
            m_fvgList[size] = fvg;
         }
      }
   }

   //+------------------------------------------------------------------+
   //| Analyze PO3 Pattern (Accumulation/Manipulation/Distribution)     |
   //+------------------------------------------------------------------+
   void AnalyzePO3(ENUM_TIMEFRAMES tf)
   {
      // Get recent price action
      double high0 = iHigh(m_symbol, tf, 0);
      double low0  = iLow(m_symbol, tf, 0);
      double close0 = iClose(m_symbol, tf, 0);

      double high1 = iHigh(m_symbol, tf, 1);
      double low1  = iLow(m_symbol, tf, 1);

      // Find recent swing high/low for accumulation range
      double swingHigh = high1;
      double swingLow = low1;

      for(int i = 2; i <= 10; i++)
      {
         double h = iHigh(m_symbol, tf, i);
         double l = iLow(m_symbol, tf, i);

         if(h > swingHigh) swingHigh = h;
         if(l < swingLow) swingLow = l;
      }

      // Phase 1: Accumulation (consolidation/range)
      double range = swingHigh - swingLow;
      double currentRange = high0 - low0;

      if(range > 0 && currentRange < range * 0.3) // Small candles = accumulation
      {
         m_po3.inAccumulation = true;
         m_po3.accumulationHigh = swingHigh;
         m_po3.accumulationLow = swingLow;
         m_po3.phase = 1;
      }

      // Phase 2: Manipulation (liquidity grab - purge of high/low)
      if(m_po3.inAccumulation)
      {
         // Bullish manipulation: Purge below accumulation low then reverse
         if(low0 < m_po3.accumulationLow && close0 > m_po3.accumulationLow)
         {
            m_po3.inManipulation = true;
            m_po3.manipulationTarget = m_po3.accumulationLow;
            m_po3.phase = 2;
         }

         // Bearish manipulation: Purge above accumulation high then reverse
         if(high0 > m_po3.accumulationHigh && close0 < m_po3.accumulationHigh)
         {
            m_po3.inManipulation = true;
            m_po3.manipulationTarget = m_po3.accumulationHigh;
            m_po3.phase = 2;
         }
      }

      // Phase 3: Distribution (strong move in one direction)
      if(m_po3.inManipulation)
      {
         // Bullish distribution: Strong move up after manipulation
         if(close0 > m_po3.accumulationHigh + range * 0.5)
         {
            m_po3.inDistribution = true;
            m_po3.distributionTarget = close0;
            m_po3.phase = 3;
         }

         // Bearish distribution: Strong move down after manipulation
         if(close0 < m_po3.accumulationLow - range * 0.5)
         {
            m_po3.inDistribution = true;
            m_po3.distributionTarget = close0;
            m_po3.phase = 3;
         }
      }
   }

   //+------------------------------------------------------------------+
   //| Get PO3 Analysis                                                 |
   //+------------------------------------------------------------------+
   SPO3Analysis GetPO3() { return m_po3; }

   //+------------------------------------------------------------------+
   //| Get Order Blocks                                                 |
   //+------------------------------------------------------------------+
   void GetOrderBlocks(SOrderBlock &blocks[])
   {
      ArrayResize(blocks, ArraySize(m_orderBlocks));
      for(int i = 0; i < ArraySize(m_orderBlocks); i++)
         blocks[i] = m_orderBlocks[i];
   }

   //+------------------------------------------------------------------+
   //| Get Fair Value Gaps                                              |
   //+------------------------------------------------------------------+
   void GetFVGs(SFairValueGap &fvgs[])
   {
      ArrayResize(fvgs, ArraySize(m_fvgList));
      for(int i = 0; i < ArraySize(m_fvgList); i++)
         fvgs[i] = m_fvgList[i];
   }

   //+------------------------------------------------------------------+
   //| Check if price is in Premium/Discount zone                       |
   //+------------------------------------------------------------------+
   int GetPriceZone(double price, double high, double low)
   {
      double mid = (high + low) / 2.0;
      double upper = high - (high - mid) * 0.382; // 61.8% retracement
      double lower = low + (mid - low) * 0.382;

      if(price >= upper) return 1;  // Premium (Sell zone)
      if(price <= lower) return -1; // Discount (Buy zone)

      return 0; // Equilibrium
   }
};
