//+------------------------------------------------------------------+
//| Fibonacci.mqh                                                    |
//| Fibonacci Retracement Levels Calculator                          |
//| Copyright 2025, EFFATA Reinforcement Trading Systems             |
//+------------------------------------------------------------------+
#property copyright "2025, EFFATA Reinforcement Trading Systems"
#property version   "1.00"
#property strict

struct FiboLevels {
   double level_0;   // Low/High
   double level_236;
   double level_382;
   double level_50;
   double level_618;
   double level_786;
   double level_100; // High/Low
   bool   is_uptrend;
};

class CFibonacci {
private:
   string m_symbol;
   ENUM_TIMEFRAMES m_period;
   int m_lookback;

public:
   CFibonacci(string symbol, ENUM_TIMEFRAMES period, int lookback=100) {
      m_symbol = symbol;
      m_period = period;
      m_lookback = lookback;
   }

   FiboLevels Calculate() {
      FiboLevels levels;

      int high_idx = iHighest(m_symbol, m_period, MODE_HIGH, m_lookback, 0);
      int low_idx = iLowest(m_symbol, m_period, MODE_LOW, m_lookback, 0);

      double high_val = iHigh(m_symbol, m_period, high_idx);
      double low_val = iLow(m_symbol, m_period, low_idx);

      // Determine direction based on recency
      // If High is more recent than Low, we are in an Uptrend (retracing down?) -
      // Actually standard usage:
      // If recent trend is UP (Low -> High), we draw Fibo from Low (100) to High (0) to find supports.
      // If recent trend is DOWN (High -> Low), we draw Fibo from High (100) to Low (0) to find resistance.

      // Let's define is_uptrend by which index is smaller (more recent)
      levels.is_uptrend = (high_idx < low_idx);

      double diff = high_val - low_val;

      if(levels.is_uptrend) {
         // Drawn from Low to High
         levels.level_0   = high_val;
         levels.level_236 = high_val - diff * 0.236;
         levels.level_382 = high_val - diff * 0.382;
         levels.level_50  = high_val - diff * 0.5;
         levels.level_618 = high_val - diff * 0.618;
         levels.level_786 = high_val - diff * 0.786;
         levels.level_100 = low_val;
      } else {
         // Drawn from High to Low
         levels.level_0   = low_val;
         levels.level_236 = low_val + diff * 0.236;
         levels.level_382 = low_val + diff * 0.382;
         levels.level_50  = low_val + diff * 0.5;
         levels.level_618 = low_val + diff * 0.618;
         levels.level_786 = low_val + diff * 0.786;
         levels.level_100 = high_val;
      }

      return levels;
   }

   // Get distance to nearest key level (0.382, 0.5, 0.618)
   double GetNearestGoldenLevelDist() {
      FiboLevels fib = Calculate();
      double price = iClose(m_symbol, m_period, 0);

      double d1 = MathAbs(price - fib.level_382);
      double d2 = MathAbs(price - fib.level_50);
      double d3 = MathAbs(price - fib.level_618);

      return MathMin(d1, MathMin(d2, d3));
   }
};
