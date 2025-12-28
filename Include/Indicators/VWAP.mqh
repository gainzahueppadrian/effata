//+------------------------------------------------------------------+
//| VWAP.mqh                                                         |
//| Volume Weighted Average Price Indicator                          |
//| Copyright 2025, EFFATA Reinforcement Trading Systems             |
//+------------------------------------------------------------------+
#property copyright "2025, EFFATA Reinforcement Trading Systems"
#property version   "1.00"
#property strict

class CVWAP {
private:
   string m_symbol;
   ENUM_TIMEFRAMES m_period;

public:
   CVWAP(string symbol, ENUM_TIMEFRAMES period) {
      m_symbol = symbol;
      m_period = period;
   }

   // Calculate VWAP for the current day
   double Calculate() {
      // Find start of the day
      datetime time0 = iTime(m_symbol, m_period, 0);
      MqlDateTime dt;
      TimeToStruct(time0, dt);

      // We need to go back to the start of the trading day
      int start_idx = 0;

      // Go back at most 24 hours to find session start (00:00)
      for(int i=0; i<1440; i++) {
         datetime t = iTime(m_symbol, m_period, i);
         MqlDateTime t_dt;
         TimeToStruct(t, t_dt);
         if(t_dt.day != dt.day) {
            start_idx = i - 1;
            break;
         }
         start_idx = i;
      }

      if(start_idx < 0) start_idx = 0;

      double cum_pv = 0;
      double cum_vol = 0;

      for(int i=start_idx; i>=0; i--) {
         double price = (iHigh(m_symbol, m_period, i) + iLow(m_symbol, m_period, i) + iClose(m_symbol, m_period, i)) / 3.0;
         double vol = (double)iTickVolume(m_symbol, m_period, i);

         cum_pv += price * vol;
         cum_vol += vol;
      }

      if(cum_vol == 0) return iClose(m_symbol, m_period, 0);

      return cum_pv / cum_vol;
   }

   // Returns deviation from VWAP
   double GetDeviation() {
      double vwap = Calculate();
      double price = iClose(m_symbol, m_period, 0);
      return price - vwap;
   }
};
