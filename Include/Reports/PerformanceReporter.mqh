//+------------------------------------------------------------------+
//| PerformanceReporter.mqh                                         |
//| Advanced Performance Reporting and Statistical Analysis         |
//| Copyright 2025, Reinforcement Learning Trading Systems          |
//+------------------------------------------------------------------+
#property copyright "2025, RL Trading Systems"
#property link      "https://www.effata.ai"
#property version   "2.0"
#property strict

#include <Math\Stat\Math.mqh>
#include <Math\Stat\Normal.mqh>
#include <Files\FileTxt.mqh>
#include "../Core/CompatMQL4.mqh"

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

   void Initialize() {
      totalTrades = 0;
      winningTrades = 0;
      losingTrades = 0;
      winRate = 0.0;
      profitFactor = 0.0;
      netProfit = 0.0;
      grossProfit = 0.0;
      grossLoss = 0.0;
      maxDrawdown = 0.0;
      recoveryFactor = 0.0;
      sharpRatio = 0.0;
      expectedValue = 0.0;
      avgTradeDuration = 0.0;
      startDate = 0;
      endDate = 0;
   }
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

   void Initialize() {
      isValid = false;
      isConsistent = false;
      pValue = 1.0;
      confidence = 0.0;
      recommendation = "INSUFFICIENT_DATA";
      standardError = 0.0;
      confidenceIntervalLow = 0.0;
      confidenceIntervalHigh = 0.0;
   }
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

class CPerformanceReporter {
private:
   TradeRecord m_tradeHistory[];
   int m_maxRecords;
   datetime m_lastUpdate;

   PerformanceMetrics m_currentMetrics;
   StatisticalAnalysis m_statAnalysis;

   // Internal calculations
   void CalculateBasicMetrics() {
      m_currentMetrics.Initialize();
      int count = ArraySize(m_tradeHistory);
      if(count == 0) return;

      m_currentMetrics.totalTrades = count;
      m_currentMetrics.startDate = m_tradeHistory[0].entryTime;
      m_currentMetrics.endDate = m_tradeHistory[count-1].exitTime;

      double totalDuration = 0;
      double runningBalance = 0;
      double maxBalance = 0;
      double maxDD = 0;

      for(int i=0; i<count; i++) {
         if(m_tradeHistory[i].profit > 0) {
            m_currentMetrics.winningTrades++;
            m_currentMetrics.grossProfit += m_tradeHistory[i].profit;
         } else {
            m_currentMetrics.losingTrades++;
            m_currentMetrics.grossLoss += m_tradeHistory[i].profit;
         }

         m_currentMetrics.netProfit += m_tradeHistory[i].profit;

         // Duration
         totalDuration += (double)(m_tradeHistory[i].exitTime - m_tradeHistory[i].entryTime);

         // Drawdown (simplified calculation based on realized PnL stream)
         runningBalance += m_tradeHistory[i].profit;
         if(runningBalance > maxBalance) maxBalance = runningBalance;
         double dd = maxBalance - runningBalance;
         if(dd > maxDD) maxDD = dd;
      }

      m_currentMetrics.winRate = (double)m_currentMetrics.winningTrades / count;
      m_currentMetrics.profitFactor = (m_currentMetrics.grossLoss != 0) ?
                                      m_currentMetrics.grossProfit / MathAbs(m_currentMetrics.grossLoss) :
                                      m_currentMetrics.grossProfit > 0 ? 100.0 : 0.0;

      m_currentMetrics.avgTradeDuration = totalDuration / count;
      m_currentMetrics.maxDrawdown = maxDD; // In monetary terms
      m_currentMetrics.recoveryFactor = (maxDD > 0) ? m_currentMetrics.netProfit / maxDD : m_currentMetrics.netProfit;
   }

   void CalculateRiskMetrics() {
      CalculateSharpeRatio();
      CalculateExpectancy();
   }

   void PerformTTest() {
      m_statAnalysis.Initialize();
      int n = ArraySize(m_tradeHistory);
      if(n < 30) {
         m_statAnalysis.isValid = false;
         m_statAnalysis.recommendation = "NEED_MORE_DATA";
         return;
      }

      m_statAnalysis.isValid = true;

      // Calculate Mean and StdDev of trade results
      double sum = 0, sumSq = 0;
      for(int i=0; i<n; i++) {
         sum += m_tradeHistory[i].profit;
         sumSq += m_tradeHistory[i].profit * m_tradeHistory[i].profit;
      }
      double mean = sum / n;
      double variance = (sumSq - (sum * sum) / n) / (n - 1);
      double stdDev = MathSqrt(variance);

      m_statAnalysis.standardError = stdDev / MathSqrt(n);

      // T-Statistic for Mean > 0
      double tStat = (m_statAnalysis.standardError > 0) ? mean / m_statAnalysis.standardError : 0.0;

      // Confidence Intervals (95% approx 1.96)
      m_statAnalysis.confidenceIntervalLow = mean - 1.96 * m_statAnalysis.standardError;
      m_statAnalysis.confidenceIntervalHigh = mean + 1.96 * m_statAnalysis.standardError;

      // Simplified P-Value estimation (1-tail) using normal approx for large N
      m_statAnalysis.confidence = MathCumulativeDistributionNormal(tStat, 0, 1);
      m_statAnalysis.pValue = 1.0 - m_statAnalysis.confidence;

      if(m_statAnalysis.confidence > 0.95 && mean > 0) {
         m_statAnalysis.isConsistent = true;
         m_statAnalysis.recommendation = "SYSTEM_ROBUST";
      } else if(mean > 0) {
         m_statAnalysis.isConsistent = false;
         m_statAnalysis.recommendation = "POSITIVE_BUT_UNCERTAIN";
      } else {
         m_statAnalysis.isConsistent = false;
         m_statAnalysis.recommendation = "SYSTEM_FAILING";
      }
   }

   void CalculateSharpeRatio() {
      int n = ArraySize(m_tradeHistory);
      if(n < 2) {
         m_currentMetrics.sharpRatio = 0.0;
         return;
      }

      double sum = 0, sumSq = 0;
      for(int i=0; i<n; i++) {
         sum += m_tradeHistory[i].profit;
         sumSq += m_tradeHistory[i].profit * m_tradeHistory[i].profit;
      }

      double mean = sum / n;
      double variance = (sumSq - (sum * sum) / n) / (n - 1);
      double stdDev = MathSqrt(variance);

      // Assuming 0 risk free rate per trade
      m_currentMetrics.sharpRatio = (stdDev > 0) ? mean / stdDev : 0.0;
   }

   void CalculateExpectancy() {
      if(m_currentMetrics.totalTrades == 0) return;

      double avgWin = (m_currentMetrics.winningTrades > 0) ? m_currentMetrics.grossProfit / m_currentMetrics.winningTrades : 0.0;
      double avgLoss = (m_currentMetrics.losingTrades > 0) ? MathAbs(m_currentMetrics.grossLoss) / m_currentMetrics.losingTrades : 0.0;

      // Expectancy formula: (Win% * AvgWin) - (Loss% * AvgLoss)
      m_currentMetrics.expectedValue = (m_currentMetrics.winRate * avgWin) - ((1.0 - m_currentMetrics.winRate) * avgLoss);
   }

public:
   CPerformanceReporter() {
      m_maxRecords = 1000;
      m_lastUpdate = 0;
      m_currentMetrics.Initialize();
      m_statAnalysis.Initialize();
   }

   void Configure(int maxRecords) {
      m_maxRecords = maxRecords;
   }

   void AddTradeRecord(const TradeRecord &trade) {
      int size = ArraySize(m_tradeHistory);
      if(size >= m_maxRecords) {
         // Shift left to make room (FIFO)
         ArrayCopy(m_tradeHistory, m_tradeHistory, 0, 1, size - 1);
         size--; // Decrement to overwrite last
      } else {
         ArrayResize(m_tradeHistory, size + 1);
      }
      m_tradeHistory[size] = trade;
      m_lastUpdate = TimeCurrent();
      UpdateReport();
   }

   void UpdateReport() {
      CalculateBasicMetrics();
      CalculateRiskMetrics();
      PerformTTest();
   }

   PerformanceMetrics GetMetrics() {
      return m_currentMetrics;
   }

   StatisticalAnalysis GetStatisticalAnalysis() {
      return m_statAnalysis;
   }

   string GeneratePerformanceReport() {
      string report = "=== EFFATA PERFORMANCE REPORT ===\n";
      report += StringFormat("Total Trades: %d\n", m_currentMetrics.totalTrades);
      report += StringFormat("Net Profit: %.2f\n", m_currentMetrics.netProfit);
      report += StringFormat("Win Rate: %.2f%%\n", m_currentMetrics.winRate * 100.0);
      report += StringFormat("Profit Factor: %.2f\n", m_currentMetrics.profitFactor);
      report += StringFormat("Sharpe Ratio: %.2f\n", m_currentMetrics.sharpRatio);
      report += StringFormat("Expectancy: %.2f\n", m_currentMetrics.expectedValue);
      report += StringFormat("Max Drawdown: %.2f\n", m_currentMetrics.maxDrawdown);
      report += StringFormat("Recovery Factor: %.2f\n", m_currentMetrics.recoveryFactor);
      return report;
   }

   string GenerateRiskAnalysisReport() {
      string report = "=== STATISTICAL RISK ANALYSIS ===\n";
      report += StringFormat("Valid: %s\n", m_statAnalysis.isValid ? "Yes" : "No");
      report += StringFormat("Robustness: %s\n", m_statAnalysis.recommendation);
      report += StringFormat("Confidence (Mean > 0): %.2f%%\n", m_statAnalysis.confidence * 100.0);
      report += StringFormat("95%% Conf. Interval: [%.2f, %.2f]\n",
                             m_statAnalysis.confidenceIntervalLow,
                             m_statAnalysis.confidenceIntervalHigh);
      return report;
   }

   bool ExportToCSV(string filename) {
      int handle = FileOpen(filename, FILE_WRITE|FILE_CSV|FILE_ANSI, ",");
      if(handle == INVALID_HANDLE) return false;

      FileWrite(handle, "EntryTime", "ExitTime", "Symbol", "Direction", "Volume", "EntryPrice", "ExitPrice", "Profit", "Strategy");

      int n = ArraySize(m_tradeHistory);
      for(int i=0; i<n; i++) {
         FileWrite(handle,
            TimeToString(m_tradeHistory[i].entryTime),
            TimeToString(m_tradeHistory[i].exitTime),
            m_tradeHistory[i].symbol,
            IntegerToString(m_tradeHistory[i].direction),
            DoubleToString(m_tradeHistory[i].volume, 2),
            DoubleToString(m_tradeHistory[i].entryPrice, 5),
            DoubleToString(m_tradeHistory[i].exitPrice, 5),
            DoubleToString(m_tradeHistory[i].profit, 2),
            m_tradeHistory[i].strategyName
         );
      }

      FileClose(handle);
      return true;
   }

   bool SaveReportToFile(string filename) {
      int handle = FileOpen(filename, FILE_WRITE|FILE_TXT|FILE_ANSI);
      if(handle == INVALID_HANDLE) return false;

      FileWriteString(handle, GeneratePerformanceReport());
      FileWriteString(handle, "\n");
      FileWriteString(handle, GenerateRiskAnalysisReport());

      FileClose(handle);
      return true;
   }

   void ClearHistory() {
      ArrayFree(m_tradeHistory);
      m_currentMetrics.Initialize();
      m_statAnalysis.Initialize();
   }
};

#endif // PERFORMANCE_REPORTER_MQH
