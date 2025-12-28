//+------------------------------------------------------------------+
//| PerformanceReporter.mqh                                         |
//| Advanced Performance Reporting and Statistical Analysis         |
//| Copyright 2025, Reinforcement Learning Trading Systems          |
//+------------------------------------------------------------------+
#property copyright "2025, RL Trading Systems"
#property link      "https://www.mql5.com"
#property version   "2.0"
#property strict

#include <Math\Stat\Math.mqh>
#include <Math\Stat\Normal.mqh>

struct PerformanceMetrics {
   int totalTrades;
   int winningTrades;
   int losingTrades;
   double winRate;
   double profitFactor;
   double netProfit;
   double grossProfit;
   double grossLoss;
   double maxDrawdown;
   double recoveryFactor;
   double sharpRatio;
   double expectedValue;
   double avgTradeDuration;
   datetime startDate;
   datetime endDate;
};

struct StatisticalAnalysis {
   bool isValid;
   bool isConsistent;
   double pValue;
   double confidence;
   string recommendation;
   double standardError;
   double confidenceIntervalLow;
   double confidenceIntervalHigh;
};

struct TradeRecord {
   datetime entryTime;
   datetime exitTime;
   double entryPrice;
   double exitPrice;
   double stopLoss;
   double takeProfit;
   double volume;
   int direction;        // 1=buy, -1=sell
   double profit;
   string symbol;
   string strategyName;
   double riskPerTrade;
};

class PerformanceReporter {
private:
   TradeRecord m_tradeHistory[];
   int m_maxRecords;
   datetime m_lastUpdate;

   PerformanceMetrics m_currentMetrics;
   StatisticalAnalysis m_statAnalysis;

   // Funciones internas
   void CalculateBasicMetrics();
   void CalculateRiskMetrics();
   void PerformTTest();
   void CalculateSharpeRatio();
   void CalculateExpectancy();

public:
   PerformanceReporter();
   void Configure(int maxRecords);
   void AddTradeRecord(const TradeRecord &trade);
   void UpdateReport();
   PerformanceMetrics GetMetrics();
   StatisticalAnalysis GetStatisticalAnalysis();
   string GeneratePerformanceReport();
   string GenerateRiskAnalysisReport();
   bool ExportToCSV(string filename);
   bool SaveReportToFile(string filename);
   void ClearHistory();
};