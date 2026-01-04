//+------------------------------------------------------------------+
//| GoldFuturesArbitrage.mqh - Gold Futures Arbitrage Strategy      |
//| Buy Spot, Sell Future (or vice versa) - Lock price gap           |
//| Compatible with MQL5/MQL4                                       |
//+------------------------------------------------------------------+

#ifndef GOLDFUTURESARBITRAGE_MQH
#define GOLDFUTURESARBITRAGE_MQH

#ifdef __MQL5__
#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>
#include <Trade/OrderInfo.mqh>
#endif

#ifdef __MQL4__
#include "../Core/CompatMQL4.mqh"
// Basic wrappers for PositionInfo if not in CompatMQL4
class CPositionInfo {
public:
   ulong Ticket() { return OrderTicket(); }
   bool SelectByIndex(int i) { return OrderSelect(i, SELECT_BY_POS, MODE_TRADES); }
   string Symbol() { return OrderSymbol(); }
   double PriceOpen() { return OrderOpenPrice(); }
   double StopLoss() { return OrderStopLoss(); }
   double TakeProfit() { return OrderTakeProfit(); }
   double Volume() { return OrderLots(); }
   int PositionType() { return OrderType(); }
   bool PositionClose(ulong ticket) { return OrderClose((int)ticket, OrderLots(), OrderClosePrice(), 3, clrNONE); } // MQL4 close
   // Note: CompatMQL4 CTrade has PositionClose(symbol)
};
#endif

#include <Arrays/ArrayObj.mqh>
#include <Arrays/ArrayDouble.mqh>

// Arbitrage Status
enum ENUM_ARBITRAGE_STATUS {
    ARBITRAGE_IDLE,
    ARBITRAGE_OPPORTUNITY_DETECTED,
    ARBITRAGE_ENTRING,
    ARBITRAGE_HEDGED,
    ARBITRAGE_CLOSING,
    ARBITRAGE_COMPLETED
};

// Arbitrage Direction
enum ENUM_ARBITRAGE_DIRECTION {
    ARBITRAGE_LONG_SPOT_SHORT_FUTURE,
    ARBITRAGE_SHORT_SPOT_LONG_FUTURE,
    ARBITRAGE_NEUTRAL
};

//+------------------------------------------------------------------+
//| SArbitrageParams - Arbitrage Parameters                          |
//+------------------------------------------------------------------+
struct SArbitrageParams {
    double                   min_spread_pct;
    double                   max_spread_pct;
    double                   target_spread_pct;
    double                   max_position_size;
    double                   min_position_size;
    double                   max_slippage_pct;
    double                   max_hold_hours;
    double                   max_spread_reversal_pct;
    int                      max_retry_count;
    int                      retry_delay_ms;
    double                   partial_close_pct;
    double                   commission_per_oz;
    double                   financing_rate_annual;
    double                   storage_rate_annual;
    double                   delivery_cost_per_oz;
    bool                     use_calendar_spread;
    string                   near_month;
    string                   far_month;
    int                      max_calendar_spread_pct;
};

//+------------------------------------------------------------------+
//| SArbitrageOpportunity - Detected Opportunity                     |
//+------------------------------------------------------------------+
struct SArbitrageOpportunity {
    ENUM_ARBITRAGE_DIRECTION direction;
    datetime                 detection_time;
    double                   spot_bid;
    double                   spot_ask;
    double                   future_bid;
    double                   future_ask;
    double                   theoretical_spread;
    double                   actual_spread;
    double                   spread_pct;
    double                   expected_profit_pct;
    double                   confidence;
    int                      minutes_to_expiry;
    double                   financing_cost;
    double                   storage_cost;
    double                   net_expected_profit;
};

//+------------------------------------------------------------------+
//| SPositionInfo - Position Details                                 |
//+------------------------------------------------------------------+
struct SPositionInfo {
    string                   spot_ticket;
    string                   future_ticket;
    double                   spot_size;
    double                   future_size;
    double                   spot_entry_price;
    double                   future_entry_price;
    datetime                 entry_time;
    double                   spot_current_pnl;
    double                   future_current_pnl;
    double                   total_pnl;
    ENUM_ARBITRAGE_STATUS    status;
};

//+------------------------------------------------------------------+
//| CGoldFuturesArbitrage - Main Arbitrage Class                     |
//+------------------------------------------------------------------+
class CGoldFuturesArbitrage {
private:
    CTrade                   m_spot_trade;
    CTrade                   m_future_trade;
    CPositionInfo            m_position_info; // Renamed to avoid conflict with struct
    SPositionInfo            m_position;      // Struct instance
    SArbitrageParams         m_params;
    ENUM_ARBITRAGE_STATUS    m_status;
    ENUM_ARBITRAGE_DIRECTION m_direction;
    SArbitrageOpportunity    m_current_opportunity;
    string                   m_spot_symbol;
    string                   m_future_symbol;
    string                   m_near_month;
    string                   m_far_month;
    bool                     m_use_calendar_spread;
    datetime                 m_last_check;
    datetime                 m_entry_time;
    int                      m_check_interval_ms;
    double                   m_total_profit;
    double                   m_total_loss;
    int                      m_opportunities_detected;
    int                      m_opportunities_completed;
    double                   m_total_commission;
    double                   m_total_financing;
    double                   m_total_storage;
    double                   m_avg_profit_pct;
    double                   m_avg_hold_time_minutes;
    double                   m_success_rate;
    int                      m_consecutive_wins;
    int                      m_consecutive_losses;
    bool                     m_initialized;
    CArrayObj                m_arbitrage_history;
    CArrayObj                m_spread_history;
    double                   m_last_spread;
    bool                     m_hedging_enabled;
    double                   m_hedge_ratio_tolerance;
    datetime                 m_last_optimization;

public:
    CGoldFuturesArbitrage();
    ~CGoldFuturesArbitrage();

    bool                    Initialize(string spot_symbol, string future_symbol);
    bool                    Configure(string config_file);
    void                    SetParameters(SArbitrageParams &params); // Changed to reference
    bool                    ScanForOpportunities();
    bool                    EvaluateOpportunity(SArbitrageOpportunity &opportunity);
    bool                    EnterArbitrage(SArbitrageOpportunity &opportunity); // Changed to reference
    bool                    ManageArbitrage();
    bool                    CloseArbitrage();
    bool                    CloseLeg(string symbol, string ticket, double size);
    bool                    EvaluateCalendarSpread();
    bool                    EnterCalendarSpread();
    bool                    CloseCalendarSpread();
    double                  CalculateFairSpread();
    double                  CalculateFinancingCost(double spot_price, double size, int days);
    double                  CalculateStorageCost(double size, int days);
    double                  CalculateNetBasis(double spot_price, double future_price);
    double                  CalculateExpectedProfit(SArbitrageOpportunity &opportunity); // Changed to reference
    void                    UpdatePositionStatus();
    void                    CheckTimeouts();
    void                    CheckSpreadReversal();
    void                    LogOpportunity(SArbitrageOpportunity &opportunity); // Changed to reference
    void                    OnTick();
    void                    OnTimer();
    void                    OnTrade();
    void                    OnPositionClose(string ticket);
    ENUM_ARBITRAGE_STATUS   GetStatus() { return m_status; }
    SArbitrageOpportunity   GetCurrentOpportunity() { return m_current_opportunity; }
    double                  GetTotalPnL() { return m_total_profit - m_total_loss; }
    double                  GetWinRate() { return m_success_rate; }
    void                    GetPerformanceMetrics(double &profit, double &wins, double &losses);
    void                    AddCommission(double commission) { m_total_commission += commission; }
    void                    AddFinancing(double financing) { m_total_financing += financing; }
    void                    AddStorage(double storage) { m_total_storage += storage; }
    bool                    OptimizeParameters();
    void                    RecordSpreadData(double spread);
    double                  GetAverageSpread();
    double                  GetSpreadVolatility();
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CGoldFuturesArbitrage::CGoldFuturesArbitrage() {
    m_spot_symbol = "XAUUSD";
    m_future_symbol = "GC";
    m_near_month = "";
    m_far_month = "";
    m_use_calendar_spread = false;
    m_status = ARBITRAGE_IDLE;
    m_direction = ARBITRAGE_NEUTRAL;
    m_last_check = 0;
    m_entry_time = 0;
    m_check_interval_ms = 100;
    m_total_profit = 0;
    m_total_loss = 0;
    m_opportunities_detected = 0;
    m_opportunities_completed = 0;
    m_total_commission = 0;
    m_total_financing = 0;
    m_total_storage = 0;
    m_avg_profit_pct = 0;
    m_avg_hold_time_minutes = 0;
    m_success_rate = 0;
    m_consecutive_wins = 0;
    m_consecutive_losses = 0;
    m_initialized = false;
    m_hedging_enabled = true;
    m_hedge_ratio_tolerance = 0.02;
    m_last_optimization = 0;
    m_last_spread = 0;

    m_params.min_spread_pct = 0.5;
    m_params.max_spread_pct = 5.0;
    m_params.target_spread_pct = 1.5;
    m_params.max_position_size = 100.0;
    m_params.min_position_size = 1.0;
    m_params.max_slippage_pct = 0.1;
    m_params.max_hold_hours = 24;
    m_params.max_spread_reversal_pct = 0.5;
    m_params.max_retry_count = 3;
    m_params.retry_delay_ms = 50;
    m_params.partial_close_pct = 0.5;
    m_params.commission_per_oz = 0.5;
    m_params.financing_rate_annual = 0.05;
    m_params.storage_rate_annual = 0.02;
    m_params.delivery_cost_per_oz = 0;
    m_params.use_calendar_spread = false;
    m_params.max_calendar_spread_pct = 2.0;
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CGoldFuturesArbitrage::~CGoldFuturesArbitrage() {
    if(m_status != ARBITRAGE_IDLE) {
        CloseArbitrage();
    }
    if(m_arbitrage_history.Total() > 0) {
        m_arbitrage_history.Clear();
    }
    if(m_spread_history.Total() > 0) {
        m_spread_history.Clear();
    }
}

//+------------------------------------------------------------------+
//| Initialize                                                       |
//+------------------------------------------------------------------+
bool CGoldFuturesArbitrage::Initialize(string spot_symbol, string future_symbol) {
    m_spot_symbol = spot_symbol;
    m_future_symbol = future_symbol;

    if(!SymbolInfoInteger(m_spot_symbol, SYMBOL_EXIST)) {
        Print("Spot symbol not found: ", m_spot_symbol);
        return false;
    }

    if(StringLen(m_future_symbol) > 0 && !SymbolInfoInteger(m_future_symbol, SYMBOL_EXIST)) {
        Print("Future symbol not found: ", m_future_symbol);
    }

    m_initialized = true;
    Print("Gold Futures Arbitrage initialized successfully");
    Print("Spot: ", m_spot_symbol, " | Future: ", m_future_symbol);
    Print("Min Spread: ", m_params.min_spread_pct, "% | Target: ", m_params.target_spread_pct, "%");
    Print("Max Position: ", m_params.max_position_size, " oz | Max Hold: ", m_params.max_hold_hours, " hours");

    return true;
}

//+------------------------------------------------------------------+
//| Configure from File                                              |
//+------------------------------------------------------------------+
bool CGoldFuturesArbitrage::Configure(string config_file) {
    int file_handle = FileOpen(config_file, FILE_READ | FILE_ANSI);
    if(file_handle == INVALID_HANDLE) {
        Print("Failed to open config file: ", config_file);
        return false;
    }

    string current_line;
    while(!FileIsEnding(file_handle)) {
        current_line = FileReadString(file_handle);
        current_line = StringTrim(current_line);

        if(StringLen(current_line) == 0 || StringGetCharacter(current_line, 0) == '#')
            continue;

        string key, value;
        int separator = StringFind(current_line, "=");
        if(separator > 0) {
            key = StringTrim(StringSubstr(current_line, 0, separator));
            value = StringTrim(StringSubstr(current_line, separator + 1));

            if(key == "min_spread_pct") m_params.min_spread_pct = StringToDouble(value);
            else if(key == "max_spread_pct") m_params.max_spread_pct = StringToDouble(value);
            else if(key == "target_spread_pct") m_params.target_spread_pct = StringToDouble(value);
            else if(key == "max_position_size") m_params.max_position_size = StringToDouble(value);
            else if(key == "min_position_size") m_params.min_position_size = StringToDouble(value);
            else if(key == "max_hold_hours") m_params.max_hold_hours = StringToDouble(value);
            else if(key == "commission_per_oz") m_params.commission_per_oz = StringToDouble(value);
            else if(key == "financing_rate_annual") m_params.financing_rate_annual = StringToDouble(value);
            else if(key == "storage_rate_annual") m_params.storage_rate_annual = StringToDouble(value);
            else if(key == "use_calendar_spread") m_params.use_calendar_spread = (bool)StringToInteger(value);
            else if(key == "max_calendar_spread_pct") m_params.max_calendar_spread_pct = StringToDouble(value);
            else if(key == "hedging_enabled") m_hedging_enabled = (bool)StringToInteger(value);
            else if(key == "hedge_ratio_tolerance") m_hedge_ratio_tolerance = StringToDouble(value);
        }
    }

    FileClose(file_handle);
    Print("Configuration loaded from: ", config_file);
    return true;
}

//+------------------------------------------------------------------+
//| Set Parameters                                                   |
//+------------------------------------------------------------------+
void CGoldFuturesArbitrage::SetParameters(SArbitrageParams &params) {
    m_params = params;
}

//+------------------------------------------------------------------+
//| Scan for Opportunities                                           |
//+------------------------------------------------------------------+
bool CGoldFuturesArbitrage::ScanForOpportunities() {
    if(m_status != ARBITRAGE_IDLE) {
        return false;
    }

    datetime current_time = TimeCurrent();
    if(current_time - m_last_check < m_check_interval_ms / 1000) {
        return false;
    }
    m_last_check = current_time;

    double spot_bid = SymbolInfoDouble(m_spot_symbol, SYMBOL_BID);
    double spot_ask = SymbolInfoDouble(m_spot_symbol, SYMBOL_ASK);

    if(spot_bid == 0 || spot_ask == 0) {
        return false;
    }

    double future_bid = 0, future_ask = 0;
    if(StringLen(m_future_symbol) > 0 && SymbolInfoInteger(m_future_symbol, SYMBOL_EXIST)) {
        future_bid = SymbolInfoDouble(m_future_symbol, SYMBOL_BID);
        future_ask = SymbolInfoDouble(m_future_symbol, SYMBOL_ASK);
    }

    double fair_spread = CalculateFairSpread();
    double actual_spread = 0;

    if(future_ask > 0 && future_bid > 0) {
        actual_spread = future_ask - spot_bid;
    }

    double spread_pct = (actual_spread / spot_bid) * 100;
    RecordSpreadData(spread_pct);

    SArbitrageOpportunity opportunity;
    ZeroMemory(opportunity);
    opportunity.detection_time = current_time;
    opportunity.spot_bid = spot_bid;
    opportunity.spot_ask = spot_ask;
    opportunity.future_bid = future_bid;
    opportunity.future_ask = future_ask;
    opportunity.actual_spread = actual_spread;
    opportunity.spread_pct = spread_pct;

    if(spread_pct > fair_spread + m_params.min_spread_pct) {
        opportunity.direction = ARBITRAGE_LONG_SPOT_SHORT_FUTURE;
        opportunity.expected_profit_pct = spread_pct - fair_spread;
    } else if(spread_pct < fair_spread - m_params.min_spread_pct) {
        opportunity.direction = ARBITRAGE_SHORT_SPOT_LONG_FUTURE;
        opportunity.expected_profit_pct = fair_spread - spread_pct;
    } else {
        return false;
    }

    if(opportunity.expected_profit_pct < m_params.min_spread_pct * 0.5) {
        return false;
    }

    opportunity.financing_cost = CalculateFinancingCost(spot_bid, m_params.min_position_size, 30);
    opportunity.storage_cost = CalculateStorageCost(m_params.min_position_size, 30);
    opportunity.net_expected_profit = opportunity.expected_profit_pct -
                                      (opportunity.financing_cost + opportunity.storage_cost) / spot_bid * 100;

    opportunity.confidence = MathMin(opportunity.expected_profit_pct / m_params.target_spread_pct, 1.0);

    if(opportunity.expected_profit_pct > m_params.max_spread_pct) {
        Print("Spread too large, possible anomaly: ", opportunity.expected_profit_pct, "%");
        return false;
    }

    m_current_opportunity = opportunity;
    LogOpportunity(opportunity);
    m_opportunities_detected++;

    return EnterArbitrage(opportunity);
}

//+------------------------------------------------------------------+
//| Enter Arbitrage                                                  |
//+------------------------------------------------------------------+
bool CGoldFuturesArbitrage::EnterArbitrage(SArbitrageOpportunity &opportunity) {
    if(m_status != ARBITRAGE_IDLE) {
        return false;
    }

    m_status = ARBITRAGE_ENTRING;

    double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double position_size = MathMin(m_params.max_position_size,
                                   account_balance / opportunity.spot_bid * 0.3);
    position_size = MathMax(position_size, m_params.min_position_size);
    position_size = MathRound(position_size * 100) / 100;

    double max_slippage = opportunity.spot_bid * m_params.max_slippage_pct / 100;
    double spot_sl = 0, spot_tp = 0;
    double future_sl = 0, future_tp = 0;

    bool success = false;
    bool spot_filled = false;
    bool future_filled = false;
    string spot_ticket = "";
    string future_ticket = "";
    double spot_fill_price = 0;
    double future_fill_price = 0;

    if(opportunity.direction == ARBITRAGE_LONG_SPOT_SHORT_FUTURE) {
        #ifdef __MQL5__
        m_spot_trade.SetAsyncMode(false);
        m_spot_trade.SetTypeFilling(ORDER_FILLING_FOK);
        #endif
        m_spot_trade.SetDeviationInPoints(100);

        if(m_spot_trade.Buy(position_size, m_spot_symbol, opportunity.spot_ask + max_slippage,
                           spot_sl, spot_tp, "Arb-LongSpot")) {
            spot_filled = true;
            #ifdef __MQL5__
            spot_ticket = IntegerToString(m_spot_trade.ResultOrder());
            spot_fill_price = m_spot_trade.ResultPrice();
            #else
            spot_ticket = IntegerToString((int)m_spot_trade.ResultOrder());
            spot_fill_price = m_spot_trade.ResultPrice();
            #endif
            m_position.spot_entry_price = spot_fill_price;
            m_position.spot_size = position_size;
            AddCommission(position_size * m_params.commission_per_oz);
        } else {
            Print("Spot buy failed: ", GetLastError());
        }

        if(spot_filled && StringLen(m_future_symbol) > 0 &&
           SymbolInfoInteger(m_future_symbol, SYMBOL_EXIST)) {
            Sleep(m_params.retry_delay_ms);

            #ifdef __MQL5__
            m_future_trade.SetAsyncMode(false);
            m_future_trade.SetTypeFilling(ORDER_FILLING_FOK);
            #endif
            m_future_trade.SetDeviationInPoints(100);

            if(m_future_trade.Sell(position_size, m_future_symbol, opportunity.future_bid - max_slippage,
                                  future_sl, future_tp, "Arb-ShortFuture")) {
                future_filled = true;
                #ifdef __MQL5__
                future_ticket = IntegerToString(m_future_trade.ResultOrder());
                future_fill_price = m_future_trade.ResultPrice();
                #else
                future_ticket = IntegerToString((int)m_future_trade.ResultOrder());
                future_fill_price = m_future_trade.ResultPrice();
                #endif
                m_position.future_entry_price = future_fill_price;
                m_position.future_size = position_size;
                AddCommission(position_size * m_params.commission_per_oz);
            } else {
                Print("Future sell failed: ", GetLastError());
            }
        }

        if(spot_filled && (!StringLen(m_future_symbol) > 0 || future_filled)) {
            success = true;
        } else if(spot_filled) {
            Print("Partial fill - closing spot position");
            #ifdef __MQL5__
            m_spot_trade.PositionClose(spot_ticket);
            #else
            m_spot_trade.PositionClose(m_spot_symbol); // MQL4 mock logic simplified
            #endif
        }
    } else {
        #ifdef __MQL5__
        m_spot_trade.SetAsyncMode(false);
        m_spot_trade.SetTypeFilling(ORDER_FILLING_FOK);
        #endif
        m_spot_trade.SetDeviationInPoints(100);

        if(m_spot_trade.Sell(position_size, m_spot_symbol, opportunity.spot_bid - max_slippage,
                            spot_sl, spot_tp, "Arb-ShortSpot")) {
            spot_filled = true;
            #ifdef __MQL5__
            spot_ticket = IntegerToString(m_spot_trade.ResultOrder());
            spot_fill_price = m_spot_trade.ResultPrice();
            #else
            spot_ticket = IntegerToString((int)m_spot_trade.ResultOrder());
            spot_fill_price = m_spot_trade.ResultPrice();
            #endif
            m_position.spot_entry_price = spot_fill_price;
            m_position.spot_size = position_size;
            AddCommission(position_size * m_params.commission_per_oz);
        } else {
            Print("Spot sell failed: ", GetLastError());
        }

        if(spot_filled && StringLen(m_future_symbol) > 0 &&
           SymbolInfoInteger(m_future_symbol, SYMBOL_EXIST)) {
            Sleep(m_params.retry_delay_ms);

            #ifdef __MQL5__
            m_future_trade.SetAsyncMode(false);
            m_future_trade.SetTypeFilling(ORDER_FILLING_FOK);
            #endif
            m_future_trade.SetDeviationInPoints(100);

            if(m_future_trade.Buy(position_size, m_future_symbol, opportunity.future_ask + max_slippage,
                                 future_sl, future_tp, "Arb-LongFuture")) {
                future_filled = true;
                #ifdef __MQL5__
                future_ticket = IntegerToString(m_future_trade.ResultOrder());
                future_fill_price = m_future_trade.ResultPrice();
                #else
                future_ticket = IntegerToString((int)m_future_trade.ResultOrder());
                future_fill_price = m_future_trade.ResultPrice();
                #endif
                m_position.future_entry_price = future_fill_price;
                m_position.future_size = position_size;
                AddCommission(position_size * m_params.commission_per_oz);
            } else {
                Print("Future buy failed: ", GetLastError());
            }
        }

        if(spot_filled && (!StringLen(m_future_symbol) > 0 || future_filled)) {
            success = true;
        } else if(spot_filled) {
            Print("Partial fill - closing spot position");
            #ifdef __MQL5__
            m_spot_trade.PositionClose(spot_ticket);
            #else
            m_spot_trade.PositionClose(m_spot_symbol);
            #endif
        }
    }

    if(success) {
        m_position.spot_ticket = spot_ticket;
        m_position.future_ticket = future_ticket;
        m_position.entry_time = TimeCurrent();
        m_position.status = ARBITRAGE_HEDGED;
        m_status = ARBITRAGE_HEDGED;
        m_entry_time = TimeCurrent();
        m_direction = opportunity.direction;

        Print("=== ARBITRAGE ENTERED SUCCESSFULLY ===");
        Print("Direction: ", opportunity.direction == ARBITRAGE_LONG_SPOT_SHORT_FUTURE ?
                                 "LONG SPOT / SHORT FUTURE" : "SHORT SPOT / LONG FUTURE");
        Print("Spot Entry: ", m_position.spot_entry_price, " | Size: ", position_size, " oz");
        if(StringLen(future_ticket) > 0) {
            Print("Future Entry: ", m_position.future_entry_price, " | Size: ", position_size);
        }
        Print("Expected Profit: ", opportunity.expected_profit_pct, "%");
        Print("Confidence: ", (opportunity.confidence * 100), "%");
        Print("=======================================");

        return true;
    } else {
        m_status = ARBITRAGE_IDLE;
        m_direction = ARBITRAGE_NEUTRAL;
        Print("Failed to enter arbitrage position");
        return false;
    }
}

//+------------------------------------------------------------------+
//| Manage Arbitrage                                                 |
//+------------------------------------------------------------------+
bool CGoldFuturesArbitrage::ManageArbitrage() {
    if(m_status != ARBITRAGE_HEDGED) {
        return false;
    }

    UpdatePositionStatus();
    CheckTimeouts();
    CheckSpreadReversal();

    if(m_status == ARBITRAGE_CLOSING) {
        return CloseArbitrage();
    }

    double spot_pnl_pct = 0, future_pnl_pct = 0;
    double current_spot = SymbolInfoDouble(m_spot_symbol, SYMBOL_BID);
    double current_future = 0;

    if(StringLen(m_future_symbol) > 0 && SymbolInfoInteger(m_future_symbol, SYMBOL_EXIST)) {
        current_future = SymbolInfoDouble(m_future_symbol, SYMBOL_ASK);
    }

    if(m_direction == ARBITRAGE_LONG_SPOT_SHORT_FUTURE) {
        if(m_position.spot_size > 0 && m_position.spot_entry_price > 0) {
            spot_pnl_pct = (current_spot - m_position.spot_entry_price) / m_position.spot_entry_price * 100;
        }
        if(m_position.future_size > 0 && m_position.future_entry_price > 0 && current_future > 0) {
            future_pnl_pct = (m_position.future_entry_price - current_future) / m_position.future_entry_price * 100;
        }
    } else {
        if(m_position.spot_size > 0 && m_position.spot_entry_price > 0) {
            spot_pnl_pct = (m_position.spot_entry_price - current_spot) / m_position.spot_entry_price * 100;
        }
        if(m_position.future_size > 0 && m_position.future_entry_price > 0 && current_future > 0) {
            future_pnl_pct = (current_future - m_position.future_entry_price) / m_position.future_entry_price * 100;
        }
    }

    m_position.spot_current_pnl = spot_pnl_pct;
    m_position.future_current_pnl = future_pnl_pct;
    m_position.total_pnl = spot_pnl_pct + future_pnl_pct;

    double fair_spread = CalculateFairSpread();

    if(m_position.total_pnl >= m_params.target_spread_pct) {
        Print("Target profit reached: ", m_position.total_pnl, "%");
        m_status = ARBITRAGE_CLOSING;
        return true;
    }

    if(m_position.total_pnl <= -m_params.max_spread_reversal_pct) {
        Print("Spread reversal detected, closing: ", m_position.total_pnl, "%");
        m_status = ARBITRAGE_CLOSING;
        return true;
    }

    if(m_position.total_pnl > 0 && m_position.total_pnl >= m_params.target_spread_pct * 0.5) {
        double partial_size = m_position.spot_size * m_params.partial_close_pct;
        partial_size = MathRound(partial_size * 100) / 100;

        if(partial_size >= m_params.min_position_size) {
            Print("Partial profit taking at: ", m_position.total_pnl, "%");
        }
    }

    return true;
}

//+------------------------------------------------------------------+
//| Close Arbitrage                                                  |
//+------------------------------------------------------------------+
bool CGoldFuturesArbitrage::CloseArbitrage() {
    if(m_status != ARBITRAGE_CLOSING && m_status != ARBITRAGE_HEDGED) {
        return false;
    }

    m_status = ARBITRAGE_CLOSING;

    bool all_closed = true;
    double total_realized_pnl = 0;

    if(StringLen(m_position.spot_ticket) > 0 && m_position.spot_size > 0) {
        #ifdef __MQL5__
        if(m_spot_trade.PositionClose(m_position.spot_ticket)) {
        #else
        if(m_spot_trade.PositionClose(m_spot_symbol)) {
        #endif
            total_realized_pnl += m_position.spot_current_pnl * m_position.spot_size;
            Print("Spot position closed successfully");
        } else {
            Print("Failed to close spot position: ", GetLastError());
            all_closed = false;
        }
    }

    if(StringLen(m_position.future_ticket) > 0 && m_position.future_size > 0) {
        #ifdef __MQL5__
        if(m_future_trade.PositionClose(m_position.future_ticket)) {
        #else
        if(m_future_trade.PositionClose(m_future_symbol)) {
        #endif
            total_realized_pnl += m_position.future_current_pnl * m_position.future_size;
            Print("Future position closed successfully");
        } else {
            Print("Failed to close future position: ", GetLastError());
            all_closed = false;
        }
    }

    if(all_closed) {
        double hold_hours = (TimeCurrent() - m_entry_time) / 3600.0;

        if(total_realized_pnl > 0) {
            m_total_profit += total_realized_pnl;
            m_consecutive_wins++;
            m_consecutive_losses = 0;
        } else {
            m_total_loss += MathAbs(total_realized_pnl);
            m_consecutive_losses++;
            m_consecutive_wins = 0;
        }

        m_opportunities_completed++;
        m_success_rate = (double)m_consecutive_wins / MathMax(m_consecutive_wins + m_consecutive_losses, 1);

        Print("=== ARBITRAGE COMPLETED ===");
        Print("Total Realized PnL: ", total_realized_pnl);
        Print("Hold Time: ", hold_hours, " hours");

        m_position.status = ARBITRAGE_COMPLETED;
        m_status = ARBITRAGE_IDLE;
        m_direction = ARBITRAGE_NEUTRAL;
        m_position.spot_size = 0;
        m_position.future_size = 0;

        return true;
    }

    return false;
}

//+------------------------------------------------------------------+
//| Calculate Fair Spread                                            |
//+------------------------------------------------------------------+
double CGoldFuturesArbitrage::CalculateFairSpread() {
    double spot_price = SymbolInfoDouble(m_spot_symbol, SYMBOL_BID);
    if(spot_price == 0) return 0;

    int days_to_expiry = 30;
    #ifdef __MQL5__
    if(StringLen(m_future_symbol) > 0) {
        long expiry = SymbolInfoInteger(m_future_symbol, SYMBOL_EXPIRATION_TIME);
        if(expiry > 0) {
            days_to_expiry = (int)((expiry - TimeCurrent()) / 86400);
            days_to_expiry = MathMax(days_to_expiry, 1);
        }
    }
    #endif

    double annual_cost_rate = m_params.financing_rate_annual + m_params.storage_rate_annual;
    double daily_cost_rate = annual_cost_rate / 365.0;
    double fair_spread_pct = daily_cost_rate * days_to_expiry * 100;

    return fair_spread_pct;
}

//+------------------------------------------------------------------+
//| Calculate Financing Cost                                         |
//+------------------------------------------------------------------+
double CGoldFuturesArbitrage::CalculateFinancingCost(double spot_price, double size, int days) {
    double notional = spot_price * size;
    double daily_rate = m_params.financing_rate_annual / 365.0;
    return notional * daily_rate * days;
}

//+------------------------------------------------------------------+
//| Calculate Storage Cost                                           |
//+------------------------------------------------------------------+
double CGoldFuturesArbitrage::CalculateStorageCost(double size, int days) {
    double daily_rate = m_params.storage_rate_annual / 365.0;
    return size * daily_rate * days;
}

//+------------------------------------------------------------------+
//| Update Position Status                                           |
//+------------------------------------------------------------------+
void CGoldFuturesArbitrage::UpdatePositionStatus() {
    #ifdef __MQL5__
    if(StringLen(m_position.spot_ticket) > 0) {
        if(!m_position_info.SelectByTicket(StringToInteger(m_position.spot_ticket))) {
            m_position.spot_size = 0;
        }
    }

    if(StringLen(m_position.future_ticket) > 0) {
        if(!m_position_info.SelectByTicket(StringToInteger(m_position.future_ticket))) {
            m_position.future_size = 0;
        }
    }
    #else
    // MQL4 simple check (iterating trades)
    // Assume still open if not closed by EA logic, or check OrderSelect
    if(StringLen(m_position.spot_ticket) > 0) {
        if(!OrderSelect(StringToInteger(m_position.spot_ticket), SELECT_BY_TICKET)) m_position.spot_size = 0;
        else if(OrderCloseTime() > 0) m_position.spot_size = 0;
    }
    #endif
}

//+------------------------------------------------------------------+
//| Check Timeouts                                                   |
//+------------------------------------------------------------------+
void CGoldFuturesArbitrage::CheckTimeouts() {
    if(m_entry_time == 0) return;

    double hold_hours = (TimeCurrent() - m_entry_time) / 3600.0;

    if(hold_hours >= m_params.max_hold_hours) {
        Print("Maximum hold time reached: ", hold_hours, " hours");
        m_status = ARBITRAGE_CLOSING;
    }
}

//+------------------------------------------------------------------+
//| Check Spread Reversal                                            |
//+------------------------------------------------------------------+
void CGoldFuturesArbitrage::CheckSpreadReversal() {
    if(m_entry_time == 0) return;

    double current_spot = SymbolInfoDouble(m_spot_symbol, SYMBOL_BID);
    double current_future = 0;

    if(StringLen(m_future_symbol) > 0 && SymbolInfoInteger(m_future_symbol, SYMBOL_EXIST)) {
        current_future = SymbolInfoDouble(m_future_symbol, SYMBOL_ASK);
    }

    if(current_future == 0) return;

    double current_spread_pct = (current_future - current_spot) / current_spot * 100;
    double fair_spread = CalculateFairSpread();

    if(m_direction == ARBITRAGE_LONG_SPOT_SHORT_FUTURE) {
        if(current_spread_pct < fair_spread - m_params.max_spread_reversal_pct) {
            Print("Spread reversal detected (Long Spot/Short Future)");
            m_status = ARBITRAGE_CLOSING;
        }
    } else {
        if(current_spread_pct > fair_spread + m_params.max_spread_reversal_pct) {
            Print("Spread reversal detected (Short Spot/Long Future)");
            m_status = ARBITRAGE_CLOSING;
        }
    }
}

//+------------------------------------------------------------------+
//| Log Opportunity                                                  |
//+------------------------------------------------------------------+
void CGoldFuturesArbitrage::LogOpportunity(SArbitrageOpportunity &opportunity) {
    Print("=== ARBITRAGE OPPORTUNITY DETECTED ===");
    Print("Time: ", TimeToString(opportunity.detection_time));
    Print("Direction: ", opportunity.direction == ARBITRAGE_LONG_SPOT_SHORT_FUTURE ?
                              "LONG SPOT / SHORT FUTURE" : "SHORT SPOT / LONG FUTURE");
    Print("Spot: ", opportunity.spot_bid, " / ", opportunity.spot_ask);
    if(opportunity.future_bid > 0) {
        Print("Future: ", opportunity.future_bid, " / ", opportunity.future_ask);
    }
    Print("Spread: ", opportunity.spread_pct, "%");
    Print("Fair Spread: ", CalculateFairSpread(), "%");
    Print("Expected Profit: ", opportunity.expected_profit_pct, "%");
    Print("Confidence: ", opportunity.confidence * 100, "%");
    Print("=====================================");
}

//+------------------------------------------------------------------+
//| Record Spread Data                                               |
//+------------------------------------------------------------------+
void CGoldFuturesArbitrage::RecordSpreadData(double spread) {
    CArrayDouble *spread_data = new CArrayDouble();
    spread_data.Add(spread);
    spread_data.Add((double)TimeCurrent());
    m_spread_history.Add(spread_data);

    if(m_spread_history.Total() > 1000) {
        CArrayDouble *old_data = m_spread_history.At(0);
        if(old_data != NULL) {
            delete old_data;
        }
        m_spread_history.Delete(0);
    }

    m_last_spread = spread;
}

//+------------------------------------------------------------------+
//| Get Average Spread                                               |
//+------------------------------------------------------------------+
double CGoldFuturesArbitrage::GetAverageSpread() {
    if(m_spread_history.Total() == 0) return 0;

    double sum = 0;
    int count = 0;

    for(int i = 0; i < m_spread_history.Total(); i++) {
        CArrayDouble *data = m_spread_history.At(i);
        if(data != NULL && data.Total() > 0) {
            sum += data.At(0);
            count++;
        }
    }

    return count > 0 ? sum / count : 0;
}

//+------------------------------------------------------------------+
//| Get Spread Volatility                                            |
//+------------------------------------------------------------------+
double CGoldFuturesArbitrage::GetSpreadVolatility() {
    if(m_spread_history.Total() < 2) return 0;

    double avg = GetAverageSpread();
    double sum_sq = 0;
    int count = 0;

    for(int i = 0; i < m_spread_history.Total(); i++) {
        CArrayDouble *data = m_spread_history.At(i);
        if(data != NULL && data.Total() > 0) {
            double deviation = data.At(0) - avg;
            sum_sq += deviation * deviation;
            count++;
        }
    }

    return count > 1 ? MathSqrt(sum_sq / (count - 1)) : 0;
}

//+------------------------------------------------------------------+
//| Optimize Parameters                                              |
//+------------------------------------------------------------------+
bool CGoldFuturesArbitrage::OptimizeParameters() {
    if(m_opportunities_completed < 10) return false;

    datetime now = TimeCurrent();
    if(now - m_last_optimization < 86400) return false;
    m_last_optimization = now;

    double avg_spread = GetAverageSpread();
    double spread_vol = GetSpreadVolatility();

    if(avg_spread > 0 && spread_vol > 0) {
        double new_target = avg_spread + spread_vol * 0.5;
        if(new_target > m_params.min_spread_pct && new_target < m_params.max_spread_pct) {
            m_params.target_spread_pct = new_target;
            Print("Parameters optimized - New target spread: ", new_target, "%");
        }
    }

    return true;
}

//+------------------------------------------------------------------+
//| OnTick Event Handler                                             |
//+------------------------------------------------------------------+
void CGoldFuturesArbitrage::OnTick() {
    if(!m_initialized) return;

    if(m_status == ARBITRAGE_IDLE) {
        ScanForOpportunities();
    } else if(m_status == ARBITRAGE_HEDGED || m_status == ARBITRAGE_CLOSING) {
        ManageArbitrage();
    }
}

//+------------------------------------------------------------------+
//| OnTimer Event Handler                                            |
//+------------------------------------------------------------------+
void CGoldFuturesArbitrage::OnTimer() {
    OptimizeParameters();
}

//+------------------------------------------------------------------+
//| Get Performance Metrics                                          |
//+------------------------------------------------------------------+
void CGoldFuturesArbitrage::GetPerformanceMetrics(double &profit, double &wins, double &losses) {
    profit = m_total_profit - m_total_loss;
    wins = (double)m_consecutive_wins;
    losses = (double)m_consecutive_losses;
}

#endif // GOLDFUTURESARBITRAGE_MQH
