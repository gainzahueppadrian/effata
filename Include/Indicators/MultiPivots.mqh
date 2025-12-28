//+------------------------------------------------------------------+
//| MultiPivots.mqh                                                  |
//| Pivot Points Calculator (Day, Week, Month)                       |
//| Copyright 2025, EFFATA Reinforcement Trading Systems             |
//+------------------------------------------------------------------+
#property copyright "2025, EFFATA Reinforcement Trading Systems"
#property version   "1.00"
#property strict

enum ENUM_PIVOT_TYPE {
   PIVOT_CLASSIC,
   PIVOT_FIBONACCI,
   PIVOT_CAMARILLA,
   PIVOT_WOODIE,
   NONE
};

struct PivotLevels {
   double P;
   double R1, R2, R3;
   double S1, S2, S3;
   double TC, BC; // Central Pivot Range
};

struct PivotSettings {
   bool draw;
   ENUM_PIVOT_TYPE PivotTypeHour;
   ENUM_PIVOT_TYPE PivotTypeFourHour;
   ENUM_PIVOT_TYPE PivotTypeDay;
   ENUM_PIVOT_TYPE PivotTypeWeek;
   ENUM_PIVOT_TYPE PivotTypeMonth;
   ENUM_PIVOT_TYPE PivotTypeYear;
};

class TypePivotsData {
public:
   PivotSettings Settings;
   PivotLevels PivotsDay;
   PivotLevels PivotsFourHour;
   PivotLevels PivotsWeek;

   // Lists for history/comparison (simplified)
   PivotLevels PivotsFourHourList[10];

   bool Calculate(datetime time) {
      // Calculate Daily Pivots (based on previous D1 candle)
      CalculatePivots(PERIOD_D1, PivotsDay, Settings.PivotTypeDay);

      // Calculate H4 Pivots
      CalculatePivots(PERIOD_H4, PivotsFourHour, Settings.PivotTypeFourHour);

      // Update List (Shift)
      for(int i=9; i>0; i--) PivotsFourHourList[i] = PivotsFourHourList[i-1];
      PivotsFourHourList[0] = PivotsFourHour;

      return true;
   }

private:
   void CalculatePivots(ENUM_TIMEFRAMES period, PivotLevels &levels, ENUM_PIVOT_TYPE type) {
      if(type == NONE) return;

      int shift = 1; // Previous candle
      double high = iHigh(NULL, period, shift);
      double low = iLow(NULL, period, shift);
      double close = iClose(NULL, period, shift);

      if(type == PIVOT_FIBONACCI) {
         levels.P = (high + low + close) / 3.0;
         double range = high - low;
         levels.R1 = levels.P + (range * 0.382);
         levels.R2 = levels.P + (range * 0.618);
         levels.R3 = levels.P + (range * 1.000);
         levels.S1 = levels.P - (range * 0.382);
         levels.S2 = levels.P - (range * 0.618);
         levels.S3 = levels.P - (range * 1.000);
      } else {
         // Classic
         levels.P = (high + low + close) / 3.0;
         levels.R1 = (2 * levels.P) - low;
         levels.S1 = (2 * levels.P) - high;
         // ... others
      }

      // CPR
      levels.BC = (high + low) / 2.0;
      levels.TC = (levels.P - levels.BC) + levels.P;
   }
};
