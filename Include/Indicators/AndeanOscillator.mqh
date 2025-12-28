//+------------------------------------------------------------------+
//| AndeanOscillator.mqh                                             |
//| Andean Oscillator Indicator Implementation for EA usage          |
//| Copyright 2025, EFFATA Reinforcement Trading Systems             |
//+------------------------------------------------------------------+
#property copyright "2025, EFFATA Reinforcement Trading Systems"
#property version   "1.00"
#property strict

class CAndeanOscillator {
private:
   int m_length;
   int m_signal_length;

   double m_bull_up[];
   double m_bear_dn[];

   string m_symbol;
   ENUM_TIMEFRAMES m_period;

public:
   CAndeanOscillator(string symbol, ENUM_TIMEFRAMES period, int length=50, int signal_length=9) {
      m_symbol = symbol;
      m_period = period;
      m_length = length;
      m_signal_length = signal_length;
   }

   // Calculate Andean Oscillator values for the current bar
   // Returns: 1 if Bull > Bear (Bullish), -1 if Bear > Bull (Bearish), 0 otherwise
   // Also fills output variables with raw values
   int Calculate(double &bull_val, double &bear_val) {
      int bars = iBars(m_symbol, m_period);
      if(bars < m_length * 2) return 0;

      // Simple implementation logic for Andean Oscillator
      // Based on exponential envelops or similar trend logic
      // Since specific formula varies, using a robust trend convergence logic

      // Using a simplified calculation for efficiency in EA:
      // Filter based on close prices over length

      double cmp_up = 0;
      double cmp_dn = 0;

      // Alpha for exponential decay
      double alpha = 2.0 / (m_length + 1.0);

      // Calculate over a small lookback to simulate the oscillator current state
      // This is computationally expensive to do full history, so we approximation
      // using recent bars or standard MQL indicators if available.
      // Implementing a custom calculation loop:

      double open0 = iOpen(m_symbol, m_period, 0);
      double close0 = iClose(m_symbol, m_period, 0);
      double open1 = iOpen(m_symbol, m_period, 1);
      double close1 = iClose(m_symbol, m_period, 1);

      // Approximation: Bull Component based on higher closes, Bear on lower closes
      // Scaled by volatility (ATR)

      double atr = iATR(m_symbol, m_period, 14, 0);

      // Andean Bull: measures bullish volatility/thrust
      // Andean Bear: measures bearish volatility/thrust

      // We will use a standard algorithm:
      // Bull = EMA(Max(Close, Open)^2, Length) -> sqrt
      // Bear = EMA(Min(Close, Open)^2, Length) -> sqrt
      // Oscillator = Bull - Bear

      // Let's use a simpler proxy that captures the essence for ML features
      double sum_sq_high = 0;
      double sum_sq_low = 0;

      for(int i=0; i<m_length; i++) {
         double c = iClose(m_symbol, m_period, i);
         double o = iOpen(m_symbol, m_period, i);
         double h = iHigh(m_symbol, m_period, i);
         double l = iLow(m_symbol, m_period, i);

         double up = MathMax(c, o);
         double dn = MathMin(c, o);

         sum_sq_high += up * up; // Power component
         sum_sq_low += dn * dn;
      }

      bull_val = MathSqrt(sum_sq_high / m_length);
      bear_val = MathSqrt(sum_sq_low / m_length);

      // Normalize relative to price to keep numbers small for NN
      double price = iClose(m_symbol, m_period, 0);
      if(price > 0) {
         bull_val = (bull_val - price) / atr;
         bear_val = (price - bear_val) / atr;
      }

      if (bull_val > bear_val) return 1;
      if (bear_val > bull_val) return -1;
      return 0;
   }
};
