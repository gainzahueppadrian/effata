//+------------------------------------------------------------------+
//| CompatMQL4.mqh                                                   |
//| Compatibility library to run MQL4 logic in MQL5                  |
//+------------------------------------------------------------------+
#property copyright "Effata Reinforcement Trading"
#property strict

#ifdef __MQL5__

// Define MQL4 constants
#define MODE_EMA 1
#define MODE_MAIN 0
#define OP_BUY 0
#define OP_SELL 1

// Timeseries access
double iClose(string symbol, int timeframe, int shift) {
   double buffer[];
   ArraySetAsSeries(buffer, true);
   if(CopyClose(symbol, (ENUM_TIMEFRAMES)timeframe, shift, 1, buffer) > 0)
      return buffer[0];
   return 0.0;
}

double iOpen(string symbol, int timeframe, int shift) {
   double buffer[];
   ArraySetAsSeries(buffer, true);
   if(CopyOpen(symbol, (ENUM_TIMEFRAMES)timeframe, shift, 1, buffer) > 0)
      return buffer[0];
   return 0.0;
}

double iHigh(string symbol, int timeframe, int shift) {
   double buffer[];
   ArraySetAsSeries(buffer, true);
   if(CopyHigh(symbol, (ENUM_TIMEFRAMES)timeframe, shift, 1, buffer) > 0)
      return buffer[0];
   return 0.0;
}

double iLow(string symbol, int timeframe, int shift) {
   double buffer[];
   ArraySetAsSeries(buffer, true);
   if(CopyLow(symbol, (ENUM_TIMEFRAMES)timeframe, shift, 1, buffer) > 0)
      return buffer[0];
   return 0.0;
}

long iVolume(string symbol, int timeframe, int shift) {
   long buffer[];
   ArraySetAsSeries(buffer, true);
   if(CopyTickVolume(symbol, (ENUM_TIMEFRAMES)timeframe, shift, 1, buffer) > 0)
      return buffer[0];
   return 0;
}

datetime iTime(string symbol, int timeframe, int shift) {
   datetime buffer[];
   ArraySetAsSeries(buffer, true);
   if(CopyTime(symbol, (ENUM_TIMEFRAMES)timeframe, shift, 1, buffer) > 0)
      return buffer[0];
   return 0;
}

// Indicator functions
double iRSI(string symbol, int timeframe, int period, int applied_price, int shift) {
   int handle = iRSI(symbol, (ENUM_TIMEFRAMES)timeframe, period, (ENUM_APPLIED_PRICE)applied_price);
   if(handle == INVALID_HANDLE) return 0.0;

   double buffer[];
   ArraySetAsSeries(buffer, true);
   if(CopyBuffer(handle, 0, shift, 1, buffer) > 0) {
      IndicatorRelease(handle);
      return buffer[0];
   }
   IndicatorRelease(handle);
   return 0.0;
}

double iATR(string symbol, int timeframe, int period, int shift) {
   int handle = iATR(symbol, (ENUM_TIMEFRAMES)timeframe, period);
   if(handle == INVALID_HANDLE) return 0.0;

   double buffer[];
   ArraySetAsSeries(buffer, true);
   if(CopyBuffer(handle, 0, shift, 1, buffer) > 0) {
      IndicatorRelease(handle);
      return buffer[0];
   }
   IndicatorRelease(handle);
   return 0.0;
}

double iMA(string symbol, int timeframe, int period, int ma_shift, int ma_method, int applied_price, int shift) {
   int handle = iMA(symbol, (ENUM_TIMEFRAMES)timeframe, period, ma_shift, (ENUM_MA_METHOD)ma_method, (ENUM_APPLIED_PRICE)applied_price);
   if(handle == INVALID_HANDLE) return 0.0;

   double buffer[];
   ArraySetAsSeries(buffer, true);
   if(CopyBuffer(handle, 0, shift, 1, buffer) > 0) {
      IndicatorRelease(handle);
      return buffer[0];
   }
   IndicatorRelease(handle);
   return 0.0;
}

double iADX(string symbol, int timeframe, int period, int applied_price, int mode, int shift) {
   int handle = iADX(symbol, (ENUM_TIMEFRAMES)timeframe, period);
   if(handle == INVALID_HANDLE) return 0.0;

   double buffer[];
   ArraySetAsSeries(buffer, true);
   // Mode 0 = Main, 1 = +DI, 2 = -DI
   int buffer_idx = 0;
   if(mode == 1) buffer_idx = 1; // +DI
   if(mode == 2) buffer_idx = 2; // -DI
   // Note: MQL5 ADX buffers: 0=Main, 1=+DI, 2=-DI

   if(CopyBuffer(handle, buffer_idx, shift, 1, buffer) > 0) {
      IndicatorRelease(handle);
      return buffer[0];
   }
   IndicatorRelease(handle);
   return 0.0;
}

// Time functions
int TimeDay(datetime date) {
   MqlDateTime dt;
   TimeToStruct(date, dt);
   return dt.day;
}

int TimeDayOfWeek(datetime date) {
   MqlDateTime dt;
   TimeToStruct(date, dt);
   return dt.day_of_week;
}

int TimeHour(datetime date) {
   MqlDateTime dt;
   TimeToStruct(date, dt);
   return dt.hour;
}

#endif
