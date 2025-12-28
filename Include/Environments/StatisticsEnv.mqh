//+------------------------------------------------------------------+
//| StatisticsEnv.mqh                                                |
//| Statistics Environment for EFFATA Orchestrator                   |
//| Tracks performance metrics and generates reports                 |
//+------------------------------------------------------------------+
#property copyright "2025, EFFATA Reinforcement Trading Systems"
#property version   "3.20"

#ifndef STATISTICS_ENV_MQH
#define STATISTICS_ENV_MQH

#include "../Core/Structures.mqh"
#include "../Reports/PerformanceReporter.mqh"

class CStatisticsEnv {
private:
    CPerformanceReporter *m_reporter;

public:
    CStatisticsEnv() {
        m_reporter = new CPerformanceReporter();
        m_reporter->Configure(1000); // Keep last 1000 trades
    }

    ~CStatisticsEnv() {
        if(CheckPointer(m_reporter) == POINTER_DYNAMIC) delete m_reporter;
    }

    bool Initialize() {
        return true;
    }

    void RecordTradeDecision(const TradeDecision &decision) {
        // We can record intent here, but realized performance comes from transactions
    }

    void UpdatePerformanceMetrics() {
        m_reporter->UpdateReport();
    }

    // Wrapper to get metrics
    PerformanceMetrics GetMetrics() {
        return m_reporter->GetMetrics();
    }

    StatisticalAnalysis GetStatisticalAnalysis() {
        return m_reporter->GetStatisticalAnalysis();
    }

    string GenerateDailyReport() {
        return m_reporter->GeneratePerformanceReport();
    }

    void OnTradeTransaction(const MqlTradeTransaction& trans,
                           const MqlTradeRequest& request,
                           const MqlTradeResult& result) {

        if(trans.type == TRADE_TRANSACTION_DEAL_ADD) {
             if(trans.deal_type == DEAL_TYPE_BUY || trans.deal_type == DEAL_TYPE_SELL) {
                // Check if it's an exit
                if(trans.entry == DEAL_ENTRY_OUT || trans.entry == DEAL_ENTRY_INOUT) {
                    TradeRecord record;
                    record.entryTime = 0; // Ideally we find the entry deal time via position ID
                    record.exitTime = trans.time;
                    record.entryPrice = trans.price; // Approximation if netting
                    record.exitPrice = trans.price;
                    record.profit = trans.profit + trans.commission + trans.swap;
                    record.volume = trans.volume;
                    record.direction = (trans.deal_type == DEAL_TYPE_BUY) ? 1 : -1;
                    record.symbol = trans.symbol;
                    record.strategyName = "EFFATA_RL"; // Default

                    m_reporter->AddTradeRecord(record);
                }
            }
        }
    }
};
#endif // STATISTICS_ENV_MQH
