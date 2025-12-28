//+------------------------------------------------------------------+
//|                                          TradingChecks.mqh       |
//|                        Trading Validation Functions              |
//|                        Compatible with MQL4 and MQL5             |
//+------------------------------------------------------------------+
#property copyright "Trading Checks Library"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Compiler Compatibility Definitions                                |
//+------------------------------------------------------------------+
#ifdef __MQL5__
   #define MQL5_CODE
#else
   #define MQL4_CODE
#endif

//+------------------------------------------------------------------+
//| Enumeration for Check Results                                     |
//+------------------------------------------------------------------+
enum ENUM_CHECK_RESULT
{
   CHECK_PASSED = 0,           // All checks passed
   CHECK_FAILED_SPREAD,        // Spread too high
   CHECK_FAILED_SLIPPAGE,      // Slippage exceeded
   CHECK_FAILED_FREE_MARGIN,   // Insufficient free margin
   CHECK_FAILED_MARGIN,        // Margin requirement not met
   CHECK_FAILED_SYMBOL,        // Symbol error
   CHECK_FAILED_VOLUME,        // Invalid volume
   CHECK_FAILED_PRICE          // Invalid price
};

//+------------------------------------------------------------------+
//| Structure for Trading Parameters                                  |
//+------------------------------------------------------------------+
struct TradingParams
{
   string   symbol;            // Trading symbol
   double   lotSize;           // Lot size
   int      orderType;         // Order type (OP_BUY, OP_SELL, etc.)
   double   requestedPrice;    // Requested execution price
   int      maxSlippagePoints; // Maximum allowed slippage in points
   int      maxSpreadPoints;   // Maximum allowed spread in points
   double   minFreeMarginPct;  // Minimum free margin percentage

   // Constructor with defaults
   void Init(string sym = "", double lots = 0.01)
   {
      symbol = (sym == "") ? Symbol() : sym;
      lotSize = lots;
      orderType = -1;
      requestedPrice = 0;
      maxSlippagePoints = 30;
      maxSpreadPoints = 50;
      minFreeMarginPct = 50.0;
   }
};

//+------------------------------------------------------------------+
//| Structure for Check Results                                       |
//+------------------------------------------------------------------+
struct CheckResults
{
   bool     spreadOK;
   bool     slippageOK;
   bool     freeMarginOK;
   bool     marginOK;

   int      currentSpread;
   double   currentSlippage;
   double   freeMargin;
   double   requiredMargin;
   double   freeMarginPercent;

   string   errorMessage;
   ENUM_CHECK_RESULT overallResult;

   void Reset()
   {
      spreadOK = true;
      slippageOK = true;
      freeMarginOK = true;
      marginOK = true;
      currentSpread = 0;
      currentSlippage = 0;
      freeMargin = 0;
      requiredMargin = 0;
      freeMarginPercent = 100;
      errorMessage = "";
      overallResult = CHECK_PASSED;
   }
};

//+------------------------------------------------------------------+
//| CLASS: CTradingChecks                                             |
//| Main class for all trading validation checks                      |
//+------------------------------------------------------------------+
class CTradingChecks
{
private:
   string         m_symbol;
   CheckResults   m_lastResults;

   // Private helper methods
   double         GetPointValue(string symbol);
   double         GetTickValue(string symbol);
   int            GetDigits(string symbol);

public:
   // Constructor / Destructor
                  CTradingChecks(string symbol = "");
                 ~CTradingChecks() {}

   // Main check methods
   bool           CheckSpread(int maxSpreadPoints, string symbol = "");
   bool           CheckSlippage(double requestedPrice, double executedPrice,
                               int maxSlippagePoints, string symbol = "");
   bool           CheckFreeMargin(double lotSize, int orderType,
                                  double minFreeMarginPct = 50.0, string symbol = "");
   bool           CheckMargin(double lotSize, int orderType, string symbol = "");

   // Comprehensive check
   ENUM_CHECK_RESULT CheckAll(TradingParams &params);

   // Getter methods
   int            GetCurrentSpread(string symbol = "");
   double         GetFreeMargin();
   double         GetFreeMarginPercent();
   double         GetRequiredMargin(double lotSize, int orderType, string symbol = "");
   double         GetMaxLotByMargin(int orderType, string symbol = "");

   // Results access
   CheckResults   GetLastResults() { return m_lastResults; }
   string         GetLastError() { return m_lastResults.errorMessage; }

   // Utility methods
   bool           IsSymbolValid(string symbol);
   void           SetSymbol(string symbol) { m_symbol = symbol; }
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CTradingChecks::CTradingChecks(string symbol = "")
{
   m_symbol = (symbol == "") ? Symbol() : symbol;
   m_lastResults.Reset();
}

//+------------------------------------------------------------------+
//| Get Point Value for Symbol                                        |
//+------------------------------------------------------------------+
double CTradingChecks::GetPointValue(string symbol)
{
   if(symbol == "") symbol = m_symbol;

   #ifdef MQL5_CODE
      return SymbolInfoDouble(symbol, SYMBOL_POINT);
   #else
      if(symbol == Symbol())
         return Point;
      else
         return MarketInfo(symbol, MODE_POINT);
   #endif
}

//+------------------------------------------------------------------+
//| Get Tick Value for Symbol                                         |
//+------------------------------------------------------------------+
double CTradingChecks::GetTickValue(string symbol)
{
   if(symbol == "") symbol = m_symbol;

   #ifdef MQL5_CODE
      return SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   #else
      return MarketInfo(symbol, MODE_TICKVALUE);
   #endif
}

//+------------------------------------------------------------------+
//| Get Digits for Symbol                                             |
//+------------------------------------------------------------------+
int CTradingChecks::GetDigits(string symbol)
{
   if(symbol == "") symbol = m_symbol;

   #ifdef MQL5_CODE
      return (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   #else
      if(symbol == Symbol())
         return Digits;
      else
         return (int)MarketInfo(symbol, MODE_DIGITS);
   #endif
}

//+------------------------------------------------------------------+
//| Check if Symbol is Valid                                          |
//+------------------------------------------------------------------+
bool CTradingChecks::IsSymbolValid(string symbol)
{
   if(symbol == "") symbol = m_symbol;

   #ifdef MQL5_CODE
      return SymbolInfoInteger(symbol, SYMBOL_EXIST) &&
             SymbolInfoInteger(symbol, SYMBOL_SELECT);
   #else
      return MarketInfo(symbol, MODE_BID) > 0;
   #endif
}

//+------------------------------------------------------------------+
//| Get Current Spread in Points                                      |
//+------------------------------------------------------------------+
int CTradingChecks::GetCurrentSpread(string symbol = "")
{
   if(symbol == "") symbol = m_symbol;

   #ifdef MQL5_CODE
      return (int)SymbolInfoInteger(symbol, SYMBOL_SPREAD);
   #else
      if(symbol == Symbol())
         return (int)MarketInfo(symbol, MODE_SPREAD);
      else
      {
         double ask = MarketInfo(symbol, MODE_ASK);
         double bid = MarketInfo(symbol, MODE_BID);
         double point = MarketInfo(symbol, MODE_POINT);
         if(point > 0)
            return (int)MathRound((ask - bid) / point);
         return 0;
      }
   #endif
}

//+------------------------------------------------------------------+
//| Check Spread Against Maximum Allowed                              |
//+------------------------------------------------------------------+
bool CTradingChecks::CheckSpread(int maxSpreadPoints, string symbol = "")
{
   if(symbol == "") symbol = m_symbol;

   m_lastResults.Reset();

   // Validate symbol
   if(!IsSymbolValid(symbol))
   {
      m_lastResults.spreadOK = false;
      m_lastResults.errorMessage = "Invalid symbol: " + symbol;
      m_lastResults.overallResult = CHECK_FAILED_SYMBOL;
      return false;
   }

   // Get current spread
   int currentSpread = GetCurrentSpread(symbol);
   m_lastResults.currentSpread = currentSpread;

   // Compare with maximum
   if(currentSpread > maxSpreadPoints)
   {
      m_lastResults.spreadOK = false;
      m_lastResults.errorMessage = StringFormat(
         "Spread too high: %d points (max: %d)",
         currentSpread, maxSpreadPoints);
      m_lastResults.overallResult = CHECK_FAILED_SPREAD;
      return false;
   }

   m_lastResults.spreadOK = true;
   return true;
}

//+------------------------------------------------------------------+
//| Check Slippage Between Requested and Executed Price               |
//+------------------------------------------------------------------+
bool CTradingChecks::CheckSlippage(double requestedPrice,
                                    double executedPrice,
                                    int maxSlippagePoints,
                                    string symbol = "")
{
   if(symbol == "") symbol = m_symbol;

   m_lastResults.Reset();

   // Validate prices
   if(requestedPrice <= 0 || executedPrice <= 0)
   {
      m_lastResults.slippageOK = false;
      m_lastResults.errorMessage = "Invalid price values";
      m_lastResults.overallResult = CHECK_FAILED_PRICE;
      return false;
   }

   // Calculate slippage in points
   double point = GetPointValue(symbol);
   if(point <= 0)
   {
      m_lastResults.slippageOK = false;
      m_lastResults.errorMessage = "Cannot get point value for: " + symbol;
      m_lastResults.overallResult = CHECK_FAILED_SYMBOL;
      return false;
   }

   double slippagePoints = MathAbs(executedPrice - requestedPrice) / point;
   m_lastResults.currentSlippage = slippagePoints;

   // Compare with maximum allowed
   if(slippagePoints > maxSlippagePoints)
   {
      m_lastResults.slippageOK = false;
      m_lastResults.errorMessage = StringFormat(
         "Slippage exceeded: %.1f points (max: %d)",
         slippagePoints, maxSlippagePoints);
      m_lastResults.overallResult = CHECK_FAILED_SLIPPAGE;
      return false;
   }

   m_lastResults.slippageOK = true;
   return true;
}

//+------------------------------------------------------------------+
//| Get Free Margin                                                   |
//+------------------------------------------------------------------+
double CTradingChecks::GetFreeMargin()
{
   #ifdef MQL5_CODE
      return AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   #else
      return AccountFreeMargin();
   #endif
}

//+------------------------------------------------------------------+
//| Get Free Margin Percentage                                        |
//+------------------------------------------------------------------+
double CTradingChecks::GetFreeMarginPercent()
{
   #ifdef MQL5_CODE
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      double margin = AccountInfoDouble(ACCOUNT_MARGIN);
   #else
      double equity = AccountEquity();
      double margin = AccountMargin();
   #endif

   if(equity <= 0) return 0;
   if(margin <= 0) return 100;  // No margin used = 100% free

   return ((equity - margin) / equity) * 100.0;
}

//+------------------------------------------------------------------+
//| Get Required Margin for a Trade                                   |
//+------------------------------------------------------------------+
double CTradingChecks::GetRequiredMargin(double lotSize,
                                          int orderType,
                                          string symbol = "")
{
   if(symbol == "") symbol = m_symbol;

   #ifdef MQL5_CODE
      // MQL5: Use OrderCalcMargin
      double margin = 0;
      double price = 0;

      ENUM_ORDER_TYPE mql5OrderType;

      // Convert order type
      switch(orderType)
      {
         case 0:  // OP_BUY
            mql5OrderType = ORDER_TYPE_BUY;
            price = SymbolInfoDouble(symbol, SYMBOL_ASK);
            break;
         case 1:  // OP_SELL
            mql5OrderType = ORDER_TYPE_SELL;
            price = SymbolInfoDouble(symbol, SYMBOL_BID);
            break;
         case 2:  // OP_BUYLIMIT
            mql5OrderType = ORDER_TYPE_BUY_LIMIT;
            price = SymbolInfoDouble(symbol, SYMBOL_ASK);
            break;
         case 3:  // OP_SELLLIMIT
            mql5OrderType = ORDER_TYPE_SELL_LIMIT;
            price = SymbolInfoDouble(symbol, SYMBOL_BID);
            break;
         case 4:  // OP_BUYSTOP
            mql5OrderType = ORDER_TYPE_BUY_STOP;
            price = SymbolInfoDouble(symbol, SYMBOL_ASK);
            break;
         case 5:  // OP_SELLSTOP
            mql5OrderType = ORDER_TYPE_SELL_STOP;
            price = SymbolInfoDouble(symbol, SYMBOL_BID);
            break;
         default:
            return 0;
      }

      if(OrderCalcMargin(mql5OrderType, symbol, lotSize, price, margin))
         return margin;
      else
         return 0;

   #else
      // MQL4: Use MarketInfo
      double marginRequired = MarketInfo(symbol, MODE_MARGINREQUIRED);
      return marginRequired * lotSize;
   #endif
}

//+------------------------------------------------------------------+
//| Check if Free Margin is Sufficient                                |
//+------------------------------------------------------------------+
bool CTradingChecks::CheckFreeMargin(double lotSize,
                                      int orderType,
                                      double minFreeMarginPct = 50.0,
                                      string symbol = "")
{
   if(symbol == "") symbol = m_symbol;

   m_lastResults.Reset();

   // Validate lot size
   if(lotSize <= 0)
   {
      m_lastResults.freeMarginOK = false;
      m_lastResults.errorMessage = "Invalid lot size";
      m_lastResults.overallResult = CHECK_FAILED_VOLUME;
      return false;
   }

   // Get account values
   double freeMargin = GetFreeMargin();
   double requiredMargin = GetRequiredMargin(lotSize, orderType, symbol);

   m_lastResults.freeMargin = freeMargin;
   m_lastResults.requiredMargin = requiredMargin;

   // Check if we have enough margin
   if(requiredMargin <= 0)
   {
      m_lastResults.freeMarginOK = false;
      m_lastResults.errorMessage = "Cannot calculate required margin";
      m_lastResults.overallResult = CHECK_FAILED_MARGIN;
      return false;
   }

   if(freeMargin < requiredMargin)
   {
      m_lastResults.freeMarginOK = false;
      m_lastResults.errorMessage = StringFormat(
         "Insufficient free margin: %.2f (required: %.2f)",
         freeMargin, requiredMargin);
      m_lastResults.overallResult = CHECK_FAILED_FREE_MARGIN;
      return false;
   }

   // Check remaining margin percentage after trade
   double marginAfterTrade = freeMargin - requiredMargin;

   #ifdef MQL5_CODE
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   #else
      double equity = AccountEquity();
   #endif

   double percentRemaining = (equity > 0) ? (marginAfterTrade / equity) * 100.0 : 0;
   m_lastResults.freeMarginPercent = percentRemaining;

   if(percentRemaining < minFreeMarginPct)
   {
      m_lastResults.freeMarginOK = false;
      m_lastResults.errorMessage = StringFormat(
         "Free margin after trade too low: %.1f%% (min: %.1f%%)",
         percentRemaining, minFreeMarginPct);
      m_lastResults.overallResult = CHECK_FAILED_FREE_MARGIN;
      return false;
   }

   m_lastResults.freeMarginOK = true;
   return true;
}

//+------------------------------------------------------------------+
//| Check Margin Level                                                |
//+------------------------------------------------------------------+
bool CTradingChecks::CheckMargin(double lotSize, int orderType, string symbol = "")
{
   if(symbol == "") symbol = m_symbol;

   m_lastResults.Reset();

   double requiredMargin = GetRequiredMargin(lotSize, orderType, symbol);
   double freeMargin = GetFreeMargin();

   m_lastResults.requiredMargin = requiredMargin;
   m_lastResults.freeMargin = freeMargin;

   if(requiredMargin <= 0)
   {
      m_lastResults.marginOK = false;
      m_lastResults.errorMessage = "Cannot calculate margin";
      m_lastResults.overallResult = CHECK_FAILED_MARGIN;
      return false;
   }

   if(freeMargin < requiredMargin)
   {
      m_lastResults.marginOK = false;
      m_lastResults.errorMessage = StringFormat(
         "Margin check failed. Required: %.2f, Available: %.2f",
         requiredMargin, freeMargin);
      m_lastResults.overallResult = CHECK_FAILED_MARGIN;
      return false;
   }

   m_lastResults.marginOK = true;
   return true;
}

//+------------------------------------------------------------------+
//| Get Maximum Lot Size Based on Available Margin                    |
//+------------------------------------------------------------------+
double CTradingChecks::GetMaxLotByMargin(int orderType, string symbol = "")
{
   if(symbol == "") symbol = m_symbol;

   double freeMargin = GetFreeMargin();
   double marginFor1Lot = GetRequiredMargin(1.0, orderType, symbol);

   if(marginFor1Lot <= 0) return 0;

   // Calculate max lots with 80% of free margin (keep 20% buffer)
   double maxLots = (freeMargin * 0.8) / marginFor1Lot;

   // Get lot constraints
   #ifdef MQL5_CODE
      double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
      double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
      double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   #else
      double minLot = MarketInfo(symbol, MODE_MINLOT);
      double maxLot = MarketInfo(symbol, MODE_MAXLOT);
      double lotStep = MarketInfo(symbol, MODE_LOTSTEP);
   #endif

   // Normalize to lot step
   if(lotStep > 0)
      maxLots = MathFloor(maxLots / lotStep) * lotStep;

   // Apply constraints
   if(maxLots < minLot) return 0;
   if(maxLots > maxLot) maxLots = maxLot;

   return NormalizeDouble(maxLots, 2);
}

//+------------------------------------------------------------------+
//| Comprehensive Check - All Parameters                              |
//+------------------------------------------------------------------+
ENUM_CHECK_RESULT CTradingChecks::CheckAll(TradingParams &params)
{
   m_lastResults.Reset();

   string symbol = (params.symbol == "") ? m_symbol : params.symbol;

   // Validate symbol
   if(!IsSymbolValid(symbol))
   {
      m_lastResults.errorMessage = "Invalid symbol: " + symbol;
      m_lastResults.overallResult = CHECK_FAILED_SYMBOL;
      return CHECK_FAILED_SYMBOL;
   }

   // Check Spread
   if(!CheckSpread(params.maxSpreadPoints, symbol))
   {
      return m_lastResults.overallResult;
   }

   // Check Margin (basic)
   if(!CheckMargin(params.lotSize, params.orderType, symbol))
   {
      return m_lastResults.overallResult;
   }

   // Check Free Margin with percentage
   if(!CheckFreeMargin(params.lotSize, params.orderType,
                       params.minFreeMarginPct, symbol))
   {
      return m_lastResults.overallResult;
   }

   // Note: Slippage is checked post-execution with actual prices
   m_lastResults.overallResult = CHECK_PASSED;
   return CHECK_PASSED;
}


//+------------------------------------------------------------------+
//|                     STANDALONE FUNCTIONS                          |
//| For use without class instantiation                               |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Get Spread (Standalone Function)                                  |
//+------------------------------------------------------------------+
int GetSpread(string symbol = "")
{
   if(symbol == "") symbol = Symbol();

   #ifdef MQL5_CODE
      return (int)SymbolInfoInteger(symbol, SYMBOL_SPREAD);
   #else
      return (int)MarketInfo(symbol, MODE_SPREAD);
   #endif
}

//+------------------------------------------------------------------+
//| Check Spread (Standalone Function)                                |
//+------------------------------------------------------------------+
bool IsSpreadOK(int maxSpreadPoints, string symbol = "")
{
   return GetSpread(symbol) <= maxSpreadPoints;
}

//+------------------------------------------------------------------+
//| Calculate Slippage in Points (Standalone Function)                |
//+------------------------------------------------------------------+
double CalculateSlippage(double requestedPrice,
                         double executedPrice,
                         string symbol = "")
{
   if(symbol == "") symbol = Symbol();

   double point;
   #ifdef MQL5_CODE
      point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   #else
      point = MarketInfo(symbol, MODE_POINT);
   #endif

   if(point <= 0) return 0;

   return MathAbs(executedPrice - requestedPrice) / point;
}

//+------------------------------------------------------------------+
//| Check Slippage (Standalone Function)                              |
//+------------------------------------------------------------------+
bool IsSlippageOK(double requestedPrice,
                  double executedPrice,
                  int maxSlippagePoints,
                  string symbol = "")
{
   return CalculateSlippage(requestedPrice, executedPrice, symbol) <= maxSlippagePoints;
}

//+------------------------------------------------------------------+
//| Get Free Margin (Standalone Function)                             |
//+------------------------------------------------------------------+
double GetAccountFreeMargin()
{
   #ifdef MQL5_CODE
      return AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   #else
      return AccountFreeMargin();
   #endif
}

//+------------------------------------------------------------------+
//| Get Margin Level Percent (Standalone Function)                    |
//+------------------------------------------------------------------+
double GetMarginLevelPercent()
{
   #ifdef MQL5_CODE
      double margin = AccountInfoDouble(ACCOUNT_MARGIN);
      if(margin <= 0) return 0;
      return AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
   #else
      double margin = AccountMargin();
      if(margin <= 0) return 0;
      return (AccountEquity() / margin) * 100.0;
   #endif
}

//+------------------------------------------------------------------+
//| Calculate Required Margin (Standalone Function)                   |
//+------------------------------------------------------------------+
double CalculateRequiredMargin(double lotSize,
                                int orderType,
                                string symbol = "")
{
   if(symbol == "") symbol = Symbol();

   #ifdef MQL5_CODE
      double margin = 0;
      double price;
      ENUM_ORDER_TYPE mql5Type;

      if(orderType == 0 || orderType == 2 || orderType == 4) // Buy types
      {
         price = SymbolInfoDouble(symbol, SYMBOL_ASK);
         mql5Type = (orderType == 0) ? ORDER_TYPE_BUY :
                    (orderType == 2) ? ORDER_TYPE_BUY_LIMIT : ORDER_TYPE_BUY_STOP;
      }
      else // Sell types
      {
         price = SymbolInfoDouble(symbol, SYMBOL_BID);
         mql5Type = (orderType == 1) ? ORDER_TYPE_SELL :
                    (orderType == 3) ? ORDER_TYPE_SELL_LIMIT : ORDER_TYPE_SELL_STOP;
      }

      if(OrderCalcMargin(mql5Type, symbol, lotSize, price, margin))
         return margin;
      return 0;
   #else
      return MarketInfo(symbol, MODE_MARGINREQUIRED) * lotSize;
   #endif
}

//+------------------------------------------------------------------+
//| Check if Margin is Sufficient (Standalone Function)               |
//+------------------------------------------------------------------+
bool IsMarginSufficient(double lotSize,
                        int orderType,
                        double minFreeMarginPct = 20.0,
                        string symbol = "")
{
   double freeMargin = GetAccountFreeMargin();
   double requiredMargin = CalculateRequiredMargin(lotSize, orderType, symbol);

   if(requiredMargin <= 0) return false;
   if(freeMargin < requiredMargin) return false;

   // Check percentage remaining
   #ifdef MQL5_CODE
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   #else
      double equity = AccountEquity();
   #endif

   if(equity <= 0) return false;

   double remainingPct = ((freeMargin - requiredMargin) / equity) * 100.0;
   return remainingPct >= minFreeMarginPct;
}

//+------------------------------------------------------------------+
//| Pre-Trade Validation (Standalone Function)                        |
//+------------------------------------------------------------------+
bool ValidateTradeConditions(string symbol,
                              double lotSize,
                              int orderType,
                              int maxSpreadPoints,
                              double minFreeMarginPct,
                              string &errorMsg)
{
   if(symbol == "") symbol = Symbol();

   // Check spread
   int spread = GetSpread(symbol);
   if(spread > maxSpreadPoints)
   {
      errorMsg = StringFormat("Spread too high: %d > %d", spread, maxSpreadPoints);
      return false;
   }

   // Check margin
   if(!IsMarginSufficient(lotSize, orderType, minFreeMarginPct, symbol))
   {
      double required = CalculateRequiredMargin(lotSize, orderType, symbol);
      double available = GetAccountFreeMargin();
      errorMsg = StringFormat("Insufficient margin: %.2f required, %.2f available",
                              required, available);
      return false;
   }

   errorMsg = "";
   return true;
}

//+------------------------------------------------------------------+
//| Post-Execution Slippage Check (Standalone Function)               |
//+------------------------------------------------------------------+
bool ValidateExecutionSlippage(double requestedPrice,
                                double executedPrice,
                                int maxSlippagePoints,
                                string symbol,
                                string &warningMsg)
{
   double slippage = CalculateSlippage(requestedPrice, executedPrice, symbol);

   if(slippage > maxSlippagePoints)
   {
      warningMsg = StringFormat("High slippage detected: %.1f points (max: %d)",
                                slippage, maxSlippagePoints);
      return false;
   }

   warningMsg = "";
   return true;
}