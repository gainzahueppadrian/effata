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
#include "../Statistics/StatisticalFunctions.mqh"

class CStatisticsEnv {
private:
    TradeStatistics m_stats;
    double m_dailyProfits[];
    int m_tradesToday;

public:
    CStatisticsEnv() {
        m_stats.Initialize();
        m_stats.start_date = TimeCurrent();
        m_tradesToday = 0;
    }

    bool Initialize() {
        return true;
    }

    void RecordTradeDecision(const TradeDecision &decision) {
        // Log decision logic if needed
        // For statistical purposes, we mainly care about the outcome,
        // but we can track confidence vs outcome later
    }

    void UpdatePerformanceMetrics() {
        // Recalculate derived metrics
        if(m_stats.total_trades > 0) {
            m_stats.win_rate = (double)m_stats.winning_trades / m_stats.total_trades;
            m_stats.avg_win = (m_stats.winning_trades > 0) ? m_stats.total_profit / m_stats.winning_trades : 0;
            m_stats.avg_loss = (m_stats.losing_trades > 0) ? m_stats.total_loss / m_stats.losing_trades : 0;
            m_stats.profit_factor = (m_stats.total_loss != 0) ? m_stats.total_profit / MathAbs(m_stats.total_loss) : 999.0;

            // Expectancy = (Win% * AvgWin) - (Loss% * AvgLoss)
            double lossRate = 1.0 - m_stats.win_rate;
            m_stats.expectancy = (m_stats.win_rate * m_stats.avg_win) - (lossRate * MathAbs(m_stats.avg_loss));
        }
    }

    string GenerateDailyReport() {
        UpdatePerformanceMetrics();

        string report = "\n=== DAILY REPORT ===\n";
        report += "Date: " + TimeToString(TimeCurrent(), TIME_DATE) + "\n";
        report += "Total Trades: " + IntegerToString(m_stats.total_trades) + "\n";
        report += "Win Rate: " + DoubleToString(m_stats.win_rate * 100, 2) + "%\n";
        report += "Profit Factor: " + DoubleToString(m_stats.profit_factor, 2) + "\n";
        report += "Total Profit: " + DoubleToString(m_stats.total_profit - MathAbs(m_stats.total_loss), 2) + "\n";
        report += "Expectancy: " + DoubleToString(m_stats.expectancy, 2) + "\n";

        return report;
    }

    void OnTradeTransaction(const MqlTradeTransaction& trans,
                           const MqlTradeRequest& request,
                           const MqlTradeResult& result) {

        if(trans.type == TRADE_TRANSACTION_DEAL_ADD) {
            long dealType = trans.deal_type;
            if(dealType == DEAL_TYPE_BUY || dealType == DEAL_TYPE_SELL) {
                // Entry deal - maybe track open
            } else if (dealType == DEAL_TYPE_BUY || dealType == DEAL_TYPE_SELL) {
                // This logic is flawed for netting/hedging.
                // Better to look at DEAL_ENTRY_OUT
            }

            if(trans.deal_type == DEAL_TYPE_BUY || trans.deal_type == DEAL_TYPE_SELL) {
                // Check if it's an exit
                if(trans.entry == DEAL_ENTRY_OUT || trans.entry == DEAL_ENTRY_INOUT) {
                    double profit = trans.profit + trans.commission + trans.swap;

                    m_stats.total_trades++;
                    if(profit > 0) {
                        m_stats.winning_trades++;
                        m_stats.total_profit += profit;
                    } else {
                        m_stats.losing_trades++;
                        m_stats.total_loss += profit; // profit is negative
                    }

                    // Track daily stats
                    m_tradesToday++;
                    int size = ArraySize(m_dailyProfits);
                    ArrayResize(m_dailyProfits, size + 1);
                    m_dailyProfits[size] = profit;
                }
            }
        }
    }
};
#endif // STATISTICS_ENV_MQH
