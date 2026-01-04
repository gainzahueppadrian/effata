//+------------------------------------------------------------------+
//| MultiAccountManagerEnv.mqh - Multi-Account Management            |
//| For institutional-grade multi-account trading                    |
//+------------------------------------------------------------------+

#ifndef MULTIACCOUNTMANAGERENV_MQH
#define MULTIACCOUNTMANAGERENV_MQH

#include <Arrays/ArrayObj.mqh>
#include <Arrays/ArrayString.mqh>
#include <Arrays/ArrayDouble.mqh>
#include <Arrays/ArrayInt.mqh>

#ifdef __MQL5__
#include <Trade/AccountInfo.mqh>
#include <Trade/Trade.mqh>
#include <Trade/OrderInfo.mqh>
#include <Trade/PositionInfo.mqh>
#else
#include "../Core/CompatMQL4.mqh"
#include "../Trade/TradeManager.mqh" // Reuse CTradeManager MQL4 mocks if needed or use CompatMQL4 wrappers
#endif

#include "RLEnvironment.mqh"
#include "../Core/Structures.mqh"

// Account Connection Status
enum ENUM_ACCOUNT_STATUS {
    ACCOUNT_STATUS_DISCONNECTED,
    ACCOUNT_STATUS_CONNECTING,
    ACCOUNT_STATUS_CONNECTED,
    ACCOUNT_STATUS_ERROR,
    ACCOUNT_STATUS_SUSPENDED
};

// Account Mode
enum ENUM_ACCOUNT_MODE {
    ACCOUNT_MODE_INDIVIDUAL,
    ACCOUNT_MODE_MASTER_SLAVE,
    ACCOUNT_MODE_POOLED,
    ACCOUNT_MODE_COPY_TRADING
};

// Trade Action Structure for internal use
struct STradeAction {
   int action_type; // 1=Buy, 2=Sell, 3=Close
   string symbol;
   double lot_size;
   double sl_price;
   double tp_price;
   string comment;
   ENUM_ORDER_TYPE order_type;
   int magic_number;
};

//+------------------------------------------------------------------+
//| SAccountConnection - Individual Account Configuration            |
//+------------------------------------------------------------------+
class SAccountConnection : public CObject {
public:
    string                   connection_id;
    string                   broker_name;
    string                   server_name;
    string                   login;
    string                   password;
    int                      account_number;
    string                   terminal_path;
    string                   profile_path;
    ENUM_ACCOUNT_STATUS      status;
    ENUM_ACCOUNT_MODE        mode;
    ENUM_ACCOUNT_TYPE        account_type;
    double                   initial_balance;
    double                   target_allocation_pct;
    double                   current_allocation;
    double                   current_balance;
    double                   current_equity;
    double                   current_margin;
    double                   free_margin;
    double                   margin_level;
    double                   max_drawdown_pct;
    double                   current_drawdown;
    double                   profit_target_pct;
    double                   current_profit_pct;
    int                      max_positions;
    int                      current_positions;
    bool                     auto_trading_enabled;
    bool                     copy_enabled;
    double                   risk_multiplier;
    datetime                 last_sync;
    datetime                 last_activity;
    CArrayString             trade_symbols;
    CArrayInt                magic_numbers;
    string                   comments;

    SAccountConnection() {}
};

//+------------------------------------------------------------------+
//| STradeAllocation - Trade Allocation Details                      |
//+------------------------------------------------------------------+
class STradeAllocation : public CObject {
public:
    string                   master_ticket;
    string                   symbol;
    double                   master_lot_size;
    double                   master_price;
    ENUM_ORDER_TYPE          order_type;
    datetime                 entry_time;
    CArrayDouble             allocated_lots;
    CArrayString             account_ids;
    CArrayString             slave_tickets;
    double                   total_allocated;
    double                   remaining_capacity;
    bool                     fully_allocated;

    STradeAllocation() {}
};

//+------------------------------------------------------------------+
//| SAccountPerformance - Account Performance Metrics                |
//+------------------------------------------------------------------+
class SAccountPerformance : public CObject {
public:
    string                   account_id;
    double                   total_profit;
    double                   total_loss;
    double                   net_profit;
    double                   roi_pct;
    int                      total_trades;
    int                      winning_trades;
    int                      losing_trades;
    double                   win_rate;
    double                   profit_factor;
    double                   average_win;
    double                   average_loss;
    double                   max_drawdown;
    double                   current_drawdown;
    double                   sharpe_ratio;
    double                   sortino_ratio;
    datetime                 period_start;
    datetime                 period_end;
    int                      consecutive_wins;
    int                      consecutive_losses;
    double                   monthly_return;
    double                   quarterly_return;

    SAccountPerformance() {}
};

//+------------------------------------------------------------------+
//| CMultiAccountManager - Main Multi-Account Management Class       |
//+------------------------------------------------------------------+
class CMultiAccountManager {
private:
    // Account Management
    CArrayObj                m_accounts;
    CArrayObj                m_allocations;
    CArrayObj                m_performance_history;

    // Master Account
    SAccountConnection       *m_master_account;
    bool                     m_is_master_slave_mode;

    // Pooled Account
    double                   m_pooled_total_balance;
    double                   m_pooled_total_equity;
    double                   m_pooled_total_margin;
    double                   m_pooled_free_margin;

    // Risk Management
    double                   m_total_risk_per_trade;
    double                   m_max_group_drawdown_pct;
    double                   m_current_group_drawdown;
    double                   m_group_profit_target;
    double                   m_current_group_profit;

    // Execution
    CTrade                   m_master_trade;
    // CArrayObj                m_slave_trades; // Not used effectively without multiple CTrade instances, simulated via single CTrade
    int                      m_sync_interval_ms;
    datetime                 m_last_sync;
    bool                     m_allocation_in_progress;

    // Statistics
    int                      m_total_allocated_trades;
    double                   m_total_slippage;
    int                      m_failed_allocations;
    int                      m_successful_allocations;

    // Master-Slave Configuration
    bool                     m_enable_master_trades;
    bool                     m_enable_slave_sync;
    double                   m_max_lot_allocation;
    double                   m_min_lot_allocation;
    double                   m_allocation_tolerance;
    int                      m_max_retry_count;

    // Notification
    bool                     m_notifications_enabled;
    CArrayString             m_notification_emails;
    string                   m_webhook_url;

    // Performance Tracking
    datetime                 m_performance_period_start;
    double                   m_period_profit_target;
    double                   m_period_min_return;
    double                   m_period_max_drawdown;

public:
    CMultiAccountManager();
    ~CMultiAccountManager();

    // Initialization
    bool                    Initialize();
    bool                    LoadConfiguration(string config_file);
    bool                    AddAccount(SAccountConnection &account);
    bool                    RemoveAccount(string account_id);
    bool                    ConnectAccount(string account_id);
    bool                    DisconnectAccount(string account_id);
    bool                    DisconnectAllAccounts();

    // Master-Slave Operations
    bool                    SetMasterAccount(SAccountConnection &master);
    bool                    AddSlaveAccount(string account_id);
    bool                    RemoveSlaveAccount(string account_id);
    bool                    ExecuteMasterTrade(STradeAction &action);
    bool                    AllocateTradeToSlaves(STradeAction &master_action);
    bool                    SyncSlavePositions();
    bool                    CloseAllPositions(string account_id);
    bool                    CloseAllPositionsAllAccounts();

    // Pooled Operations
    bool                    InitializePooledMode();
    double                  CalculatePooledPositionSize(double risk_amount);
    bool                    ExecutePooledTrade(STradeAction &action);
    bool                    DistributeProfits();
    double                  GetPooledFreeMargin();
    double                  GetPooledMarginLevel();

    // Individual Operations
    bool                    ExecuteTrade(string account_id, STradeAction &action);
    bool                    ClosePosition(string account_id, string ticket);
    bool                    ModifyStopLoss(string account_id, string ticket, double sl_price);
    bool                    ModifyTakeProfit(string account_id, string ticket, double tp_price);

    // Monitoring
    void                    UpdateAccountStatus(SAccountConnection *account);
    void                    UpdateAccountStatuses();
    void                    SyncAllAccounts();
    void                    CheckRiskLimits();
    void                    CheckDrawdownLimits();
    void                    CheckProfitTargets();
    void                    LogAccountStatus(string account_id);
    void                    LogAllAccountStatuses();

    // Performance
    void                    CalculatePerformance(string account_id);
    void                    CalculateAllPerformance();
    SAccountPerformance*    GetAccountPerformance(string account_id); // Return pointer
    double                  GetTotalGroupProfit();
    double                  GetTotalGroupEquity();
    double                  GetAverageWinRate();
    double                  GetTotalProfitFactor();

    // Allocation
    double                  CalculateAllocationPct(string account_id);
    double                  CalculateAllocatedLots(string account_id, double master_lots);
    bool                    ValidateAllocation(string account_id, double lots);
    void                    UpdateAllocations();

    // Risk Management
    double                  CalculateGroupRisk(string symbol, double lots);
    bool                    CheckGroupRiskLimits();
    void                    ReduceRiskProportionally(double reduction_pct);
    void                    PauseTradingForAccount(string account_id, string reason);
    void                    PauseTradingAllAccounts(string reason);
    void                    ResumeTrading(string account_id);
    void                    ResumeAllAccounts();

    // Getters
    int                     GetAccountCount() { return m_accounts.Total(); }
    SAccountConnection*     GetAccount(string account_id);
    double                  GetTotalEquity() { return m_pooled_total_equity; }
    double                  GetTotalBalance() { return m_pooled_total_balance; }
    bool                    IsConnected(string account_id);
    bool                    IsAnyAccountActive();

    // Event Handlers
    void                    OnTick();
    void                    OnTimer();
    void                    OnTrade();
    void                    OnAccountChange(string account_id);
    void                    OnPositionOpen(string account_id, string ticket);
    void                    OnPositionClose(string account_id, string ticket);

    // Persistence
    bool                    SaveState(string state_file);
    bool                    LoadState(string state_file);
    bool                    ExportPerformanceReport(string report_file);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CMultiAccountManager::CMultiAccountManager() {
    m_is_master_slave_mode = false;
    m_pooled_total_balance = 0;
    m_pooled_total_equity = 0;
    m_pooled_total_margin = 0;
    m_pooled_free_margin = 0;
    m_total_risk_per_trade = 1.0;
    m_max_group_drawdown_pct = 15.0;
    m_current_group_drawdown = 0;
    m_group_profit_target = 10.0;
    m_current_group_profit = 0;
    m_sync_interval_ms = 1000;
    m_last_sync = 0;
    m_allocation_in_progress = false;
    m_total_allocated_trades = 0;
    m_total_slippage = 0;
    m_failed_allocations = 0;
    m_successful_allocations = 0;
    m_enable_master_trades = true;
    m_enable_slave_sync = true;
    m_max_lot_allocation = 100.0;
    m_min_lot_allocation = 0.01;
    m_allocation_tolerance = 0.01;
    m_max_retry_count = 3;
    m_notifications_enabled = false;
    m_performance_period_start = TimeCurrent();
    m_period_profit_target = 5.0;
    m_period_min_return = -3.0;
    m_period_max_drawdown = 8.0;
    m_master_account = NULL;
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CMultiAccountManager::~CMultiAccountManager() {
    DisconnectAllAccounts();

    if(CheckPointer(m_master_account) == POINTER_DYNAMIC) delete m_master_account;

    for(int i = 0; i < m_allocations.Total(); i++) {
        STradeAllocation *alloc = m_allocations.At(i);
        if(CheckPointer(alloc) == POINTER_DYNAMIC) delete alloc;
    }
    m_allocations.Clear();

    for(int i = 0; i < m_performance_history.Total(); i++) {
        SAccountPerformance *perf = m_performance_history.At(i);
        if(CheckPointer(perf) == POINTER_DYNAMIC) delete perf;
    }
    m_performance_history.Clear();

    for(int i = 0; i < m_accounts.Total(); i++) {
        SAccountConnection *acc = m_accounts.At(i);
        if(CheckPointer(acc) == POINTER_DYNAMIC) delete acc;
    }
    m_accounts.Clear();
}

//+------------------------------------------------------------------+
//| Initialize                                                       |
//+------------------------------------------------------------------+
bool CMultiAccountManager::Initialize() {
    Print("Multi-Account Manager initializing...");
    m_performance_period_start = TimeCurrent();
    Print("Multi-Account Manager initialized successfully");
    return true;
}

//+------------------------------------------------------------------+
//| Add Account                                                      |
//+------------------------------------------------------------------+
bool CMultiAccountManager::AddAccount(SAccountConnection &account) {
    SAccountConnection *new_account = new SAccountConnection();
    // Copy members manually or rely on default if simple, but SAccountConnection has complex types (CArrayString)
    // Deep copy needed for arrays
    new_account.connection_id = account.connection_id;
    new_account.broker_name = account.broker_name;
    new_account.login = account.login;
    new_account.initial_balance = account.initial_balance;
    new_account.target_allocation_pct = account.target_allocation_pct;

    new_account.status = ACCOUNT_STATUS_DISCONNECTED;
    new_account.current_positions = 0;
    new_account.last_sync = 0;
    new_account.last_activity = TimeCurrent();

    if(new_account.target_allocation_pct <= 0) {
        new_account.target_allocation_pct = 100.0 / MathMax(m_accounts.Total() + 1, 1);
    }

    m_accounts.Add(new_account);

    Print("Account added: ", account.connection_id, " (", account.broker_name, ")");
    Print("Initial Balance: ", account.initial_balance);
    Print("Target Allocation: ", new_account.target_allocation_pct, "%");

    return true;
}

//+------------------------------------------------------------------+
//| Connect Account                                                  |
//+------------------------------------------------------------------+
bool CMultiAccountManager::ConnectAccount(string account_id) {
    SAccountConnection *account = NULL;

    for(int i = 0; i < m_accounts.Total(); i++) {
        account = m_accounts.At(i);
        if(account != NULL && account.connection_id == account_id) {
            break;
        }
        account = NULL;
    }

    if(account == NULL) {
        Print("Account not found: ", account_id);
        return false;
    }

    account.status = ACCOUNT_STATUS_CONNECTING;

    // Simulate connection (in real implementation, would connect to terminal)
    account.status = ACCOUNT_STATUS_CONNECTED;
    account.last_sync = TimeCurrent();

    account.current_balance = account.initial_balance;
    account.current_equity = account.initial_balance;
    account.free_margin = account.initial_balance;
    account.margin_level = 100.0;
    account.current_drawdown = 0;
    account.current_profit_pct = 0;

    Print("Account connected: ", account_id);
    LogAccountStatus(account_id);

    return true;
}

//+------------------------------------------------------------------+
//| Disconnect Account                                               |
//+------------------------------------------------------------------+
bool CMultiAccountManager::DisconnectAccount(string account_id) {
    for(int i = 0; i < m_accounts.Total(); i++) {
        SAccountConnection *account = m_accounts.At(i);
        if(account != NULL && account.connection_id == account_id) {
            if(account.current_positions > 0) {
                Print("Warning: Account has open positions");
            }
            account.status = ACCOUNT_STATUS_DISCONNECTED;
            Print("Account disconnected: ", account_id);
            return true;
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| Disconnect All Accounts                                          |
//+------------------------------------------------------------------+
bool CMultiAccountManager::DisconnectAllAccounts() {
    for(int i = 0; i < m_accounts.Total(); i++) {
        SAccountConnection *account = m_accounts.At(i);
        if(account != NULL) {
            account.status = ACCOUNT_STATUS_DISCONNECTED;
        }
    }
    Print("All accounts disconnected");
    return true;
}

//+------------------------------------------------------------------+
//| Execute Master Trade                                             |
//+------------------------------------------------------------------+
bool CMultiAccountManager::ExecuteMasterTrade(STradeAction &action) {
    if(!m_enable_master_trades) return false;

    bool result = false;

    if(action.action_type == 1) // Buy
        result = m_master_trade.Buy(action.lot_size, action.symbol, action.sl_price,
                                     action.tp_price, action.comment);
    else if(action.action_type == 2) // Sell
        result = m_master_trade.Sell(action.lot_size, action.symbol, action.sl_price,
                                     action.tp_price, action.comment);

    if(result) {
        Print("Master trade executed: ", action.symbol, " ", action.lot_size, " lots");

        if(m_is_master_slave_mode) {
            AllocateTradeToSlaves(action);
        }

        return true;
    }

    Print("Master trade failed: ", GetLastError());
    return false;
}

//+------------------------------------------------------------------+
//| Allocate Trade to Slaves                                         |
//+------------------------------------------------------------------+
bool CMultiAccountManager::AllocateTradeToSlaves(STradeAction &master_action) {
    if(m_allocation_in_progress) {
        Print("Allocation already in progress");
        return false;
    }

    m_allocation_in_progress = true;

    STradeAllocation *allocation = new STradeAllocation();
    allocation.master_ticket = IntegerToString(m_master_trade.ResultOrder());
    allocation.symbol = master_action.symbol;
    allocation.master_lot_size = master_action.lot_size;
    allocation.master_price = m_master_trade.ResultPrice();
    allocation.order_type = master_action.order_type;
    allocation.entry_time = TimeCurrent();
    allocation.total_allocated = 0;
    allocation.remaining_capacity = 0;
    allocation.fully_allocated = false;

    Print("Allocating trade to slaves: ", master_action.symbol, " ", master_action.lot_size, " lots");

    for(int i = 0; i < m_accounts.Total(); i++) {
        SAccountConnection *account = m_accounts.At(i);
        if(account == NULL || account.status != ACCOUNT_STATUS_CONNECTED) continue;
        if(account.copy_enabled == false) continue;
        if(account.current_positions >= account.max_positions) {
            Print("Account ", account.connection_id, " at max positions");
            continue;
        }

        double allocated_lots = CalculateAllocatedLots(account.connection_id, master_action.lot_size);

        if(allocated_lots < m_min_lot_allocation) {
            continue;
        }

        allocated_lots = MathRound(allocated_lots / account.risk_multiplier * 100) / 100;

        CTrade slave_trade;
        bool success = false;

        if(master_action.action_type == 1) {
            success = slave_trade.Buy(allocated_lots, master_action.symbol,
                                     master_action.sl_price, master_action.tp_price,
                                     account.comments + "-Copy");
        } else if(master_action.action_type == 2) {
            success = slave_trade.Sell(allocated_lots, master_action.symbol,
                                      master_action.sl_price, master_action.tp_price,
                                      account.comments + "-Copy");
        }

        if(success) {
            string slave_ticket = IntegerToString(slave_trade.ResultOrder());
            allocation.allocated_lots.Add(allocated_lots);
            allocation.account_ids.Add(account.connection_id);
            allocation.slave_tickets.Add(slave_ticket);
            allocation.total_allocated += allocated_lots;

            account.current_positions++;
            account.last_activity = TimeCurrent();
            m_successful_allocations++;

            Print("Allocated to ", account.connection_id, ": ", allocated_lots, " lots (Ticket: ", slave_ticket, ")");
        } else {
            m_failed_allocations++;
            Print("Failed to allocate to ", account.connection_id, ": ", GetLastError());
        }
    }

    allocation.remaining_capacity = master_action.lot_size - allocation.total_allocated;
    allocation.fully_allocated = (allocation.remaining_capacity < m_allocation_tolerance);

    m_allocations.Add(allocation);
    m_total_allocated_trades++;

    m_allocation_in_progress = false;

    Print("Allocation complete. Total allocated: ", allocation.total_allocated, " / ", master_action.lot_size);

    return true;
}

//+------------------------------------------------------------------+
//| Update Account Status                                            |
//+------------------------------------------------------------------+
void CMultiAccountManager::UpdateAccountStatus(SAccountConnection *account) {
    if(account == NULL) return;

    // In real environment, this would query account info
    // For simulation, we assume static
    account.margin_level = 100.0;
}

//+------------------------------------------------------------------+
//| Sync Slave Positions                                             |
//+------------------------------------------------------------------+
bool CMultiAccountManager::SyncSlavePositions() {
    datetime current_time = TimeCurrent();
    if(current_time - m_last_sync < m_sync_interval_ms / 1000) {
        return false;
    }
    m_last_sync = current_time;

    Print("Synchronizing slave positions...");

    for(int i = 0; i < m_accounts.Total(); i++) {
        SAccountConnection *account = m_accounts.At(i);
        if(account == NULL || account.status != ACCOUNT_STATUS_CONNECTED) continue;
        if(!account.copy_enabled) continue;

        UpdateAccountStatus(account);
        CalculatePerformance(account.connection_id);
    }

    CheckRiskLimits();
    CheckDrawdownLimits();

    return true;
}

//+------------------------------------------------------------------+
//| Execute Trade on Account                                         |
//+------------------------------------------------------------------+
bool CMultiAccountManager::ExecuteTrade(string account_id, STradeAction &action) {
    SAccountConnection *account = NULL;

    for(int i = 0; i < m_accounts.Total(); i++) {
        account = m_accounts.At(i);
        if(account != NULL && account.connection_id == account_id) {
            break;
        }
        account = NULL;
    }

    if(account == NULL) {
        Print("Account not found: ", account_id);
        return false;
    }

    if(account.status != ACCOUNT_STATUS_CONNECTED) {
        Print("Account not connected: ", account_id);
        return false;
    }

    if(!account.auto_trading_enabled) {
        Print("Auto-trading disabled for account: ", account_id);
        return false;
    }

    if(account.current_positions >= account.max_positions) {
        Print("Max positions reached for account: ", account_id);
        return false;
    }

    CTrade trade;
    trade.SetDeviationInPoints(100);

    bool result = false;

    if(action.action_type == 1) {
        result = trade.Buy(action.lot_size, action.symbol, action.sl_price,
                          action.tp_price, action.comment);
    } else if(action.action_type == 2) {
        result = trade.Sell(action.lot_size, action.symbol, action.sl_price,
                           action.tp_price, action.comment);
    } else if(action.action_type == 3) {
        result = trade.PositionClose(action.symbol, 100);
    }

    if(result) {
        account.current_positions++;
        account.last_activity = TimeCurrent();
        Print("Trade executed on ", account_id, ": ", action.symbol, " ", action.lot_size, " lots");
    } else {
        Print("Trade failed on ", account_id, ": ", GetLastError());
    }

    return result;
}

//+------------------------------------------------------------------+
//| Calculate Allocation Percentage                                  |
//+------------------------------------------------------------------+
double CMultiAccountManager::CalculateAllocationPct(string account_id) {
    SAccountConnection *account = NULL;

    for(int i = 0; i < m_accounts.Total(); i++) {
        account = m_accounts.At(i);
        if(account != NULL && account.connection_id == account_id) {
            return account.target_allocation_pct;
        }
    }

    return 0;
}

//+------------------------------------------------------------------+
//| Calculate Allocated Lots                                         |
//+------------------------------------------------------------------+
double CMultiAccountManager::CalculateAllocatedLots(string account_id, double master_lots) {
    double allocation_pct = CalculateAllocationPct(account_id) / 100.0;

    SAccountConnection *account = NULL;
    for(int i = 0; i < m_accounts.Total(); i++) {
        account = m_accounts.At(i);
        if(account != NULL && account.connection_id == account_id) {
            break;
        }
        account = NULL;
    }

    if(account == NULL) return 0;

    double base_allocation = master_lots * allocation_pct;

    double risk_adjusted = base_allocation * account.risk_multiplier;

    double max_allowed = m_max_lot_allocation;
    double min_required = m_min_lot_allocation;

    if(risk_adjusted > max_allowed) risk_adjusted = max_allowed;
    if(risk_adjusted < min_required) risk_adjusted = 0;

    return risk_adjusted;
}

//+------------------------------------------------------------------+
//| Check Group Risk Limits                                          |
//+------------------------------------------------------------------+
void CMultiAccountManager::CheckRiskLimits() {
    double total_exposure = 0;
    double total_margin_used = 0;
    double total_equity = 0;

    for(int i = 0; i < m_accounts.Total(); i++) {
        SAccountConnection *account = m_accounts.At(i);
        if(account == NULL || account.status != ACCOUNT_STATUS_CONNECTED) continue;

        total_margin_used += account.current_margin;
        total_equity += account.current_equity;
        total_exposure += account.current_positions * m_total_risk_per_trade;
    }

    double margin_usage_pct = total_equity > 0 ? (total_margin_used / total_equity) * 100 : 0;

    if(margin_usage_pct > 80) {
        Print("WARNING: Group margin usage high: ", margin_usage_pct, "%");
        ReduceRiskProportionally(0.5);
    }

    if(margin_usage_pct > 90) {
        PauseTradingAllAccounts("High margin usage");
    }
}

//+------------------------------------------------------------------+
//| Check Drawdown Limits                                            |
//+------------------------------------------------------------------+
void CMultiAccountManager::CheckDrawdownLimits() {
    for(int i = 0; i < m_accounts.Total(); i++) {
        SAccountConnection *account = m_accounts.At(i);
        if(account == NULL || account.status != ACCOUNT_STATUS_CONNECTED) continue;

        if(account.current_drawdown >= account.max_drawdown_pct * 0.8) {
            Print("WARNING: Drawdown approaching limit for ", account.connection_id, ": ",
                  account.current_drawdown, "%");
        }

        if(account.current_drawdown >= account.max_drawdown_pct) {
            Print("Drawdown limit reached for ", account.connection_id);
            PauseTradingForAccount(account.connection_id, "Drawdown limit reached");
        }
    }

    if(m_current_group_drawdown >= m_max_group_drawdown_pct) {
        Print("Group drawdown limit reached: ", m_current_group_drawdown, "%");
        PauseTradingAllAccounts("Group drawdown limit");
    }
}

//+------------------------------------------------------------------+
//| Check Profit Targets                                             |
//+------------------------------------------------------------------+
void CMultiAccountManager::CheckProfitTargets() {
    for(int i = 0; i < m_accounts.Total(); i++) {
        SAccountConnection *account = m_accounts.At(i);
        if(account == NULL || account.status != ACCOUNT_STATUS_CONNECTED) continue;

        if(account.current_profit_pct >= account.profit_target_pct) {
            Print("Profit target reached for ", account.connection_id, ": ",
                  account.current_profit_pct, "%");
            account.auto_trading_enabled = false;
        }
    }

    if(m_current_group_profit >= m_group_profit_target) {
        Print("Group profit target reached: ", m_current_group_profit, "%");
    }
}

//+------------------------------------------------------------------+
//| Pause Trading for Account                                        |
//+------------------------------------------------------------------+
void CMultiAccountManager::PauseTradingForAccount(string account_id, string reason) {
    for(int i = 0; i < m_accounts.Total(); i++) {
        SAccountConnection *account = m_accounts.At(i);
        if(account != NULL && account.connection_id == account_id) {
            account.auto_trading_enabled = false;
            account.copy_enabled = false;
            account.status = ACCOUNT_STATUS_SUSPENDED;
            Print("Trading paused for ", account_id, ": ", reason);
            return;
        }
    }
}

//+------------------------------------------------------------------+
//| Pause Trading All Accounts                                       |
//+------------------------------------------------------------------+
void CMultiAccountManager::PauseTradingAllAccounts(string reason) {
    for(int i = 0; i < m_accounts.Total(); i++) {
        SAccountConnection *account = m_accounts.At(i);
        if(account != NULL) {
            account.auto_trading_enabled = false;
            account.copy_enabled = false;
            account.status = ACCOUNT_STATUS_SUSPENDED;
        }
    }
    Print("All trading paused: ", reason);
}

//+------------------------------------------------------------------+
//| Calculate Performance                                            |
//+------------------------------------------------------------------+
void CMultiAccountManager::CalculatePerformance(string account_id) {
    SAccountConnection *account = NULL;

    for(int i = 0; i < m_accounts.Total(); i++) {
        account = m_accounts.At(i);
        if(account != NULL && account.connection_id == account_id) {
            break;
        }
        account = NULL;
    }

    if(account == NULL) return;

    account.current_profit_pct = account.initial_balance > 0 ?
        ((account.current_equity - account.initial_balance) / account.initial_balance) * 100 : 0;

    double peak_equity = account.initial_balance;
    double current_drawdown = 0;

    if(account.current_equity > peak_equity) {
        peak_equity = account.current_equity;
    } else {
        current_drawdown = ((peak_equity - account.current_equity) / peak_equity) * 100;
    }

    account.current_drawdown = current_drawdown;
}

//+------------------------------------------------------------------+
//| Get Account Performance                                          |
//+------------------------------------------------------------------+
SAccountPerformance* CMultiAccountManager::GetAccountPerformance(string account_id) {
    SAccountPerformance *perf = new SAccountPerformance();
    perf.account_id = account_id;
    perf.period_start = m_performance_period_start;
    perf.period_end = TimeCurrent();

    SAccountConnection *account = NULL;

    for(int i = 0; i < m_accounts.Total(); i++) {
        account = m_accounts.At(i);
        if(account != NULL && account.connection_id == account_id) {
            break;
        }
        account = NULL;
    }

    if(account == NULL) return perf;

    double profit = account.current_equity - account.initial_balance;
    perf.total_profit = profit > 0 ? profit : 0;
    perf.total_loss = profit < 0 ? MathAbs(profit) : 0;
    perf.net_profit = profit;
    perf.roi_pct = account.initial_balance > 0 ?
        (profit / account.initial_balance) * 100 : 0;

    perf.max_drawdown = account.max_drawdown_pct;
    perf.current_drawdown = account.current_drawdown;
    perf.current_profit_pct = account.current_profit_pct;

    return perf;
}

//+------------------------------------------------------------------+
//| Log Account Status                                               |
//+------------------------------------------------------------------+
void CMultiAccountManager::LogAccountStatus(string account_id) {
    SAccountConnection *account = NULL;

    for(int i = 0; i < m_accounts.Total(); i++) {
        account = m_accounts.At(i);
        if(account != NULL && account.connection_id == account_id) {
            break;
        }
        account = NULL;
    }

    if(account == NULL) return;

    Print("=== Account Status: ", account_id, " ===");
    Print("Broker: ", account.broker_name);
    Print("Status: ", EnumToString(account.status));
    Print("Balance: ", account.current_balance);
    Print("Equity: ", account.current_equity);
    Print("Free Margin: ", account.free_margin);
    Print("Margin Level: ", account.margin_level, "%");
    Print("Drawdown: ", account.current_drawdown, "%");
    Print("Profit: ", account.current_profit_pct, "%");
    Print("Positions: ", account.current_positions, " / ", account.max_positions);
    Print("===================================");
}

//+------------------------------------------------------------------+
//| Log All Account Statuses                                         |
//+------------------------------------------------------------------+
void CMultiAccountManager::LogAllAccountStatuses() {
    Print("=== Multi-Account Status Report ===");
    Print("Total Accounts: ", m_accounts.Total());

    double total_balance = 0;
    double total_equity = 0;
    double total_drawdown = 0;
    int active_accounts = 0;

    for(int i = 0; i < m_accounts.Total(); i++) {
        SAccountConnection *account = m_accounts.At(i);
        if(account == NULL) continue;

        LogAccountStatus(account.connection_id);

        if(account.status == ACCOUNT_STATUS_CONNECTED) {
            active_accounts++;
            total_balance += account.current_balance;
            total_equity += account.current_equity;
            total_drawdown += account.current_drawdown;
        }
    }

    m_pooled_total_balance = total_balance;
    m_pooled_total_equity = total_equity;
    m_current_group_drawdown = active_accounts > 0 ? total_drawdown / active_accounts : 0;
    m_current_group_profit = total_balance > 0 ?
        ((total_equity - total_balance) / total_balance) * 100 : 0;

    Print("=== Group Summary ===");
    Print("Active Accounts: ", active_accounts);
    Print("Total Balance: ", total_balance);
    Print("Total Equity: ", total_equity);
    Print("Average Drawdown: ", m_current_group_drawdown, "%");
    Print("Group Profit: ", m_current_group_profit, "%");
    Print("===========================");
}

//+------------------------------------------------------------------+
//| OnTick Event Handler                                             |
//+------------------------------------------------------------------+
void CMultiAccountManager::OnTick() {
    SyncSlavePositions();
}

//+------------------------------------------------------------------+
//| OnTimer Event Handler                                            |
//+------------------------------------------------------------------+
void CMultiAccountManager::OnTimer() {
    LogAllAccountStatuses();
    CheckProfitTargets();
}

//+------------------------------------------------------------------+
//| Placeholders for unimplemented methods                           |
//+------------------------------------------------------------------+
bool CMultiAccountManager::LoadConfiguration(string config_file) { return true; }
bool CMultiAccountManager::RemoveAccount(string account_id) { return false; }
bool CMultiAccountManager::SetMasterAccount(SAccountConnection &master) { return true; }
bool CMultiAccountManager::AddSlaveAccount(string account_id) { return true; }
bool CMultiAccountManager::RemoveSlaveAccount(string account_id) { return true; }
bool CMultiAccountManager::CloseAllPositions(string account_id) { return true; }
bool CMultiAccountManager::CloseAllPositionsAllAccounts() { return true; }
bool CMultiAccountManager::InitializePooledMode() { return true; }
double CMultiAccountManager::CalculatePooledPositionSize(double risk_amount) { return 0; }
bool CMultiAccountManager::ExecutePooledTrade(STradeAction &action) { return true; }
bool CMultiAccountManager::DistributeProfits() { return true; }
double CMultiAccountManager::GetPooledFreeMargin() { return 0; }
double CMultiAccountManager::GetPooledMarginLevel() { return 0; }
bool CMultiAccountManager::ClosePosition(string account_id, string ticket) { return true; }
bool CMultiAccountManager::ModifyStopLoss(string account_id, string ticket, double sl_price) { return true; }
bool CMultiAccountManager::ModifyTakeProfit(string account_id, string ticket, double tp_price) { return true; }
void CMultiAccountManager::UpdateAccountStatuses() { }
void CMultiAccountManager::SyncAllAccounts() { }
void CMultiAccountManager::CalculateAllPerformance() { }
double CMultiAccountManager::GetTotalGroupProfit() { return m_current_group_profit; }
double CMultiAccountManager::GetTotalGroupEquity() { return m_pooled_total_equity; }
double CMultiAccountManager::GetAverageWinRate() { return 0; }
double CMultiAccountManager::GetTotalProfitFactor() { return 0; }
bool CMultiAccountManager::ValidateAllocation(string account_id, double lots) { return true; }
void CMultiAccountManager::UpdateAllocations() { }
double CMultiAccountManager::CalculateGroupRisk(string symbol, double lots) { return 0; }
void CMultiAccountManager::ReduceRiskProportionally(double reduction_pct) { }
void CMultiAccountManager::ResumeTrading(string account_id) { }
void CMultiAccountManager::ResumeAllAccounts() { }
SAccountConnection* CMultiAccountManager::GetAccount(string account_id) { return NULL; }
bool CMultiAccountManager::IsConnected(string account_id) { return false; }
bool CMultiAccountManager::IsAnyAccountActive() { return false; }
void CMultiAccountManager::OnTrade() { }
void CMultiAccountManager::OnAccountChange(string account_id) { }
void CMultiAccountManager::OnPositionOpen(string account_id, string ticket) { }
void CMultiAccountManager::OnPositionClose(string account_id, string ticket) { }
bool CMultiAccountManager::SaveState(string state_file) { return true; }
bool CMultiAccountManager::LoadState(string state_file) { return true; }
bool CMultiAccountManager::ExportPerformanceReport(string report_file) { return true; }

#endif // MULTIACCOUNTMANAGERENV_MQH
