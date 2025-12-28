//+------------------------------------------------------------------+
//|                                             BacktestAnalyzer.mqh |
//|                      Backtest Performance Analysis & Reporting    |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "2025, Manus AI - Backtest Analyzer"
#property link      "https://www.mql5.com"
#property strict

#include <Trade/AccountInfo.mqh>
#include <Trade/Trade.mqh>

//+------------------------------------------------------------------+
//| Trade Statistics Structure                                       |
//+------------------------------------------------------------------+
struct STradeStats
{
   int totalTrades;
   int winningTrades;
   int losingTrades;
   double winRate;

   double totalProfit;
   double totalLoss;
   double netProfit;
   double profitFactor;

   double averageWin;
   double averageLoss;
   double averageRR;

   double largestWin;
   double largestLoss;

   double maxDrawdown;
   double maxDrawdownPercent;

   int consecutiveWins;
   int consecutiveLosses;
   int maxConsecutiveWins;
   int maxConsecutiveLosses;

   double sharpeRatio;
   double recoveryFactor;
   double kellyCriterion;
   double var95;

   double initialBalance;
   double finalBalance;
   double totalReturn;
   double totalReturnPercent;
};

//+------------------------------------------------------------------+
//| Backtest Analyzer Class                                         |
//+------------------------------------------------------------------+
class CBacktestAnalyzer
{
private:
   STradeStats m_stats;
   CAccountInfo m_account;

   double m_tradeResults[];
   datetime m_tradeTimes[];

   string m_reportFile;

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   CBacktestAnalyzer(string reportFile = "backtest_report.txt")
   {
      m_reportFile = reportFile;
      ResetStats();
   }

   //+------------------------------------------------------------------+
   //| Reset Statistics                                                 |
   //+------------------------------------------------------------------+
   void ResetStats()
   {
      m_stats.totalTrades = 0;
      m_stats.winningTrades = 0;
      m_stats.losingTrades = 0;
      m_stats.winRate = 0;

      m_stats.totalProfit = 0;
      m_stats.totalLoss = 0;
      m_stats.netProfit = 0;
      m_stats.profitFactor = 0;

      m_stats.averageWin = 0;
      m_stats.averageLoss = 0;
      m_stats.averageRR = 0;

      m_stats.largestWin = 0;
      m_stats.largestLoss = 0;

      m_stats.maxDrawdown = 0;
      m_stats.maxDrawdownPercent = 0;

      m_stats.consecutiveWins = 0;
      m_stats.consecutiveLosses = 0;
      m_stats.maxConsecutiveWins = 0;
      m_stats.maxConsecutiveLosses = 0;

      m_stats.sharpeRatio = 0;
      m_stats.recoveryFactor = 0;
      m_stats.kellyCriterion = 0;
      m_stats.var95 = 0;

      m_stats.initialBalance = m_account.Balance();
      m_stats.finalBalance = 0;
      m_stats.totalReturn = 0;
      m_stats.totalReturnPercent = 0;

      ArrayResize(m_tradeResults, 0);
      ArrayResize(m_tradeTimes, 0);
   }

   //+------------------------------------------------------------------+
   //| OnTradeTransaction Event Handler                                 |
   //+------------------------------------------------------------------+
   void OnTradeTransaction(const MqlTradeTransaction& trans)
   {
      // We are interested only in closed positions
      if(trans.type == TRADE_TRANSACTION_DEAL_ADD && trans.deal_entry == DEAL_ENTRY_OUT)
      {
         // Get deal properties
         double profit = HistoryDealGetDouble(trans.deal, DEAL_PROFIT);
         datetime closeTime = (datetime)HistoryDealGetInteger(trans.deal, DEAL_TIME);

         RecordTrade(profit, closeTime);
      }
   }


   //+------------------------------------------------------------------+
   //| Record Trade Result                                             |
   //+------------------------------------------------------------------+
   void RecordTrade(double profit, datetime closeTime)
   {
      int size = ArraySize(m_tradeResults);
      ArrayResize(m_tradeResults, size + 1);
      ArrayResize(m_tradeTimes, size + 1);

      m_tradeResults[size] = profit;
      m_tradeTimes[size] = closeTime;

      m_stats.totalTrades++;

      if(profit > 0)
      {
         m_stats.winningTrades++;
         m_stats.totalProfit += profit;
         m_stats.consecutiveWins++;
         m_stats.consecutiveLosses = 0;

         if(profit > m_stats.largestWin)
            m_stats.largestWin = profit;

         if(m_stats.consecutiveWins > m_stats.maxConsecutiveWins)
            m_stats.maxConsecutiveWins = m_stats.consecutiveWins;
      }
      else if(profit < 0)
      {
         m_stats.losingTrades++;
         m_stats.totalLoss += MathAbs(profit);
         m_stats.consecutiveLosses++;
         m_stats.consecutiveWins = 0;

         if(MathAbs(profit) > m_stats.largestLoss)
            m_stats.largestLoss = MathAbs(profit);

         if(m_stats.consecutiveLosses > m_stats.maxConsecutiveLosses)
            m_stats.maxConsecutiveLosses = m_stats.consecutiveLosses;
      }
   }

   //+------------------------------------------------------------------+
   //| Calculate Statistics                                            |
   //+------------------------------------------------------------------+
   void CalculateStats()
   {
      if(m_stats.totalTrades == 0)
         return;

      // Win rate
      m_stats.winRate = (double)m_stats.winningTrades / m_stats.totalTrades * 100.0;

      // Net profit
      m_stats.netProfit = m_stats.totalProfit - m_stats.totalLoss;

      // Profit factor
      if(m_stats.totalLoss > 0)
         m_stats.profitFactor = m_stats.totalProfit / m_stats.totalLoss;
      else
         m_stats.profitFactor = 0;

      // Average win/loss
      if(m_stats.winningTrades > 0)
         m_stats.averageWin = m_stats.totalProfit / m_stats.winningTrades;

      if(m_stats.losingTrades > 0)
         m_stats.averageLoss = m_stats.totalLoss / m_stats.losingTrades;

      // Average RR
      if(m_stats.averageLoss > 0)
         m_stats.averageRR = m_stats.averageWin / m_stats.averageLoss;

      // Calculate drawdown
      CalculateDrawdown();

      // Calculate Sharpe ratio
      CalculateSharpeRatio();

      // Calculate Kelly Criterion
      CalculateKellyCriterion();

      // Calculate VaR
      CalculateVaR(0.95);

      // Final balance and return
      m_stats.finalBalance = m_account.Balance();
      m_stats.totalReturn = m_stats.finalBalance - m_stats.initialBalance;
      m_stats.totalReturnPercent = (m_stats.totalReturn / m_stats.initialBalance) * 100.0;

      // Recovery factor
      if(m_stats.maxDrawdown > 0)
         m_stats.recoveryFactor = m_stats.netProfit / m_stats.maxDrawdown;
   }

   //+------------------------------------------------------------------+
   //| Calculate Maximum Drawdown                                      |
   //+------------------------------------------------------------------+
   void CalculateDrawdown()
   {
      double peak = m_stats.initialBalance;
      double maxDD = 0;
      double currentBalance = m_stats.initialBalance;

      for(int i = 0; i < ArraySize(m_tradeResults); i++)
      {
         currentBalance += m_tradeResults[i];

         if(currentBalance > peak)
            peak = currentBalance;

         double dd = peak - currentBalance;
         if(dd > maxDD)
            maxDD = dd;
      }

      m_stats.maxDrawdown = maxDD;

      if(peak > 0)
         m_stats.maxDrawdownPercent = (maxDD / peak) * 100.0;
   }

   //+------------------------------------------------------------------+
   //| Calculate Sharpe Ratio                                          |
   //+------------------------------------------------------------------+
   void CalculateSharpeRatio()
   {
      if(ArraySize(m_tradeResults) < 2)
      {
         m_stats.sharpeRatio = 0;
         return;
      }

      // Calculate mean return
      double sum = 0;
      for(int i = 0; i < ArraySize(m_tradeResults); i++)
         sum += m_tradeResults[i];

      double mean = sum / ArraySize(m_tradeResults);

      // Calculate standard deviation
      double variance = 0;
      for(int i = 0; i < ArraySize(m_tradeResults); i++)
      {
         double diff = m_tradeResults[i] - mean;
         variance += diff * diff;
      }

      variance /= ArraySize(m_tradeResults);
      double stdDev = MathSqrt(variance);

      // Sharpe ratio (assuming risk-free rate = 0)
      if(stdDev > 0)
         m_stats.sharpeRatio = mean / stdDev;
      else
         m_stats.sharpeRatio = 0;
   }

   //+------------------------------------------------------------------+
   //| Calculate Kelly Criterion                                        |
   //+------------------------------------------------------------------+
   void CalculateKellyCriterion()
   {
      if(m_stats.averageLoss == 0)
      {
         m_stats.kellyCriterion = 0;
         return;
      }

      double W = m_stats.winRate / 100.0;
      double R = m_stats.averageWin / m_stats.averageLoss;

      m_stats.kellyCriterion = W - ((1 - W) / R);
   }

   //+------------------------------------------------------------------+
   //| Calculate Value at Risk (VaR)                                    |
   //+------------------------------------------------------------------+
   void CalculateVaR(double confidenceLevel)
   {
      if(m_stats.totalTrades == 0) return;

      double sortedReturns[];
      ArrayCopy(sortedReturns, m_tradeResults);
      ArraySort(sortedReturns);

      int index = (int)(m_stats.totalTrades * (1 - confidenceLevel));
      m_stats.var95 = sortedReturns[index];
   }

   //+------------------------------------------------------------------+
   //| Run Monte Carlo Simulation                                       |
   //+------------------------------------------------------------------+
   void RunMonteCarloSimulation(int simulations, int handle)
   {
      if(m_stats.totalTrades == 0) return;

      double finalEquities[];
      ArrayResize(finalEquities, simulations);

      for(int i = 0; i < simulations; i++)
      {
         double currentEquity = m_stats.initialBalance;
         int tradeIndices[];
         ArrayResize(tradeIndices, m_stats.totalTrades);
         for(int j=0; j<m_stats.totalTrades; j++)
         {
            tradeIndices[j] = j;
         }

         // Shuffle trade order
         for(int j = 0; j < m_stats.totalTrades; j++)
         {
            int randomIndex = (int)(MathRand() / 32767.0 * (m_stats.totalTrades - 1));
            int temp = tradeIndices[j];
            tradeIndices[j] = tradeIndices[randomIndex];
            tradeIndices[randomIndex] = temp;
         }

         for(int j = 0; j < m_stats.totalTrades; j++)
         {
            currentEquity += m_tradeResults[tradeIndices[j]];
         }
         finalEquities[i] = currentEquity;
      }

      ArraySort(finalEquities);

      FileWrite(handle, "\n--- MONTE CARLO SIMULATION ---");
      FileWrite(handle, StringFormat("Median Final Equity: $%.2f", finalEquities[simulations / 2]));
      FileWrite(handle, StringFormat("5th Percentile Final Equity: $%.2f", finalEquities[(int)(simulations * 0.05)]));
      FileWrite(handle, StringFormat("95th Percentile Final Equity: $%.2f", finalEquities[(int)(simulations * 0.95)]));
   }

   //+------------------------------------------------------------------+
   //| Run Rolling t-Test Analysis                                      |
   //+------------------------------------------------------------------+
   void RunRollingTTestAnalysis(int window, int handle)
   {
      if(m_stats.totalTrades < window) return;

      FileWrite(handle, "\n--- ROLLING T-TEST ANALYSIS ---");

      for(int i = 0; i <= m_stats.totalTrades - window; i += 15)
      {
         double sample[];
         ArrayCopy(sample, m_tradeResults, 0, i, window);

         double mean = 0;
         for(int j = 0; j < window; j++)
         {
            mean += sample[j];
         }
         mean /= window;

         double stdDev = 0;
         for(int j = 0; j < window; j++)
         {
            stdDev += MathPow(sample[j] - mean, 2);
         }
         stdDev = MathSqrt(stdDev / window);

         double t_stat = (mean - m_stats.averageWin) / (stdDev / MathSqrt(window));

         FileWrite(handle, StringFormat("Trades %d-%d: t-statistic = %.2f", i+1, i+window, t_stat));
      }
   }


   //+------------------------------------------------------------------+
   //| Generate Report                                                 |
   //+------------------------------------------------------------------+
   void GenerateReport(string fileName)
   {
      m_reportFile = fileName;
      CalculateStats();

      int handle = FileOpen(m_reportFile, FILE_WRITE | FILE_TXT | FILE_ANSI);

      if(handle == INVALID_HANDLE)
      {
         Print("Failed to create report file: ", m_reportFile);
         return;
      }

      FileWrite(handle, "========================================");
      FileWrite(handle, "   CRT XAUUSD EA - BACKTEST REPORT");
      FileWrite(handle, "========================================");
      FileWrite(handle, "");

      FileWrite(handle, "--- GENERAL STATISTICS ---");
      FileWrite(handle, StringFormat("Total Trades: %d", m_stats.totalTrades));
      FileWrite(handle, StringFormat("Winning Trades: %d", m_stats.winningTrades));
      FileWrite(handle, StringFormat("Losing Trades: %d", m_stats.losingTrades));
      FileWrite(handle, StringFormat("Win Rate: %.2f%%", m_stats.winRate));
      FileWrite(handle, "");

      FileWrite(handle, "--- PROFIT & LOSS ---");
      FileWrite(handle, StringFormat("Total Profit: $%.2f", m_stats.totalProfit));
      FileWrite(handle, StringFormat("Total Loss: $%.2f", m_stats.totalLoss));
      FileWrite(handle, StringFormat("Net Profit: $%.2f", m_stats.netProfit));
      FileWrite(handle, StringFormat("Profit Factor: %.2f", m_stats.profitFactor));
      FileWrite(handle, "");

      FileWrite(handle, "--- AVERAGE METRICS ---");
      FileWrite(handle, StringFormat("Average Win: $%.2f", m_stats.averageWin));
      FileWrite(handle, StringFormat("Average Loss: $%.2f", m_stats.averageLoss));
      FileWrite(handle, StringFormat("Average RR: 1:%.2f", m_stats.averageRR));
      FileWrite(handle, "");

      FileWrite(handle, "--- EXTREMES ---");
      FileWrite(handle, StringFormat("Largest Win: $%.2f", m_stats.largestWin));
      FileWrite(handle, StringFormat("Largest Loss: $%.2f", m_stats.largestLoss));
      FileWrite(handle, "");

      FileWrite(handle, "--- DRAWDOWN ---");
      FileWrite(handle, StringFormat("Max Drawdown: $%.2f (%.2f%%)", m_stats.maxDrawdown, m_stats.maxDrawdownPercent));
      FileWrite(handle, StringFormat("Recovery Factor: %.2f", m_stats.recoveryFactor));
      FileWrite(handle, "");

      FileWrite(handle, "--- CONSECUTIVE TRADES ---");
      FileWrite(handle, StringFormat("Max Consecutive Wins: %d", m_stats.maxConsecutiveWins));
      FileWrite(handle, StringFormat("Max Consecutive Losses: %d", m_stats.maxConsecutiveLosses));
      FileWrite(handle, "");

      FileWrite(handle, "--- RISK METRICS ---");
      FileWrite(handle, StringFormat("Sharpe Ratio: %.2f", m_stats.sharpeRatio));
      FileWrite(handle, StringFormat("Kelly Criterion: %.2f%%", m_stats.kellyCriterion * 100));
      FileWrite(handle, StringFormat("Value at Risk (95%%): $%.2f", m_stats.var95));
      FileWrite(handle, "");

      FileWrite(handle, "--- ACCOUNT PERFORMANCE ---");
      FileWrite(handle, StringFormat("Initial Balance: $%.2f", m_stats.initialBalance));
      FileWrite(handle, StringFormat("Final Balance: $%.2f", m_stats.finalBalance));
      FileWrite(handle, StringFormat("Total Return: $%.2f (%.2f%%)", m_stats.totalReturn, m_stats.totalReturnPercent));
      FileWrite(handle, "");

      RunMonteCarloSimulation(1000, handle);
      RunRollingTTestAnalysis(15, handle);

      FileWrite(handle, "\n========================================");
      FileWrite(handle, "   PERFORMANCE EVALUATION");
      FileWrite(handle, "========================================");
      FileWrite(handle, "");

      // Evaluation
      string evaluation = EvaluatePerformance();
      FileWrite(handle, evaluation);

      FileWrite(handle, "");
      FileWrite(handle, "========================================");
      FileWrite(handle, "   END OF REPORT");
      FileWrite(handle, "========================================");

      FileClose(handle);

      Print("Backtest report generated: ", m_reportFile);
   }

   //+------------------------------------------------------------------+
   //| Evaluate Performance                                            |
   //+------------------------------------------------------------------+
   string EvaluatePerformance()
   {
      string eval = "";

      // Win rate evaluation
      if(m_stats.winRate >= 60)
         eval += "Win Rate: EXCELLENT (>= 60%)\n";
      else if(m_stats.winRate >= 50)
         eval += "Win Rate: GOOD (50-60%)\n";
      else if(m_stats.winRate >= 40)
         eval += "Win Rate: ACCEPTABLE (40-50%)\n";
      else
         eval += "Win Rate: POOR (< 40%) - NEEDS IMPROVEMENT\n";

      // Profit factor evaluation
      if(m_stats.profitFactor >= 2.0)
         eval += "Profit Factor: EXCELLENT (>= 2.0)\n";
      else if(m_stats.profitFactor >= 1.5)
         eval += "Profit Factor: GOOD (1.5-2.0)\n";
      else if(m_stats.profitFactor >= 1.2)
         eval += "Profit Factor: ACCEPTABLE (1.2-1.5)\n";
      else
         eval += "Profit Factor: POOR (< 1.2) - NEEDS IMPROVEMENT\n";

      // Average RR evaluation
      if(m_stats.averageRR >= 2.0)
         eval += "Average RR: EXCELLENT (>= 1:2)\n";
      else if(m_stats.averageRR >= 1.5)
         eval += "Average RR: GOOD (1:1.5-2)\n";
      else if(m_stats.averageRR >= 1.0)
         eval += "Average RR: ACCEPTABLE (1:1-1.5)\n";
      else
         eval += "Average RR: POOR (< 1:1) - NEEDS IMPROVEMENT\n";

      // Drawdown evaluation
      if(m_stats.maxDrawdownPercent <= 10)
         eval += "Max Drawdown: EXCELLENT (<= 10%)\n";
      else if(m_stats.maxDrawdownPercent <= 20)
         eval += "Max Drawdown: GOOD (10-20%)\n";
      else if(m_stats.maxDrawdownPercent <= 30)
         eval += "Max Drawdown: ACCEPTABLE (20-30%)\n";
      else
         eval += "Max Drawdown: HIGH (> 30%) - REDUCE RISK\n";

      // Sharpe ratio evaluation
      if(m_stats.sharpeRatio >= 2.0)
         eval += "Sharpe Ratio: EXCELLENT (>= 2.0)\n";
      else if(m_stats.sharpeRatio >= 1.0)
         eval += "Sharpe Ratio: GOOD (1.0-2.0)\n";
      else if(m_stats.sharpeRatio >= 0.5)
         eval += "Sharpe Ratio: ACCEPTABLE (0.5-1.0)\n";
      else
         eval += "Sharpe Ratio: POOR (< 0.5) - HIGH VOLATILITY\n";

      // Overall recommendation
      eval += "\n--- OVERALL RECOMMENDATION ---\n";

      int score = 0;
      if(m_stats.winRate >= 50) score++;
      if(m_stats.profitFactor >= 1.5) score++;
      if(m_stats.averageRR >= 1.5) score++;
      if(m_stats.maxDrawdownPercent <= 20) score++;
      if(m_stats.sharpeRatio >= 1.0) score++;

      if(score >= 4)
         eval += "RECOMMENDATION: EXCELLENT - Ready for live trading\n";
      else if(score >= 3)
         eval += "RECOMMENDATION: GOOD - Consider optimization\n";
      else if(score >= 2)
         eval += "RECOMMENDATION: NEEDS IMPROVEMENT - Optimize parameters\n";
      else
         eval += "RECOMMENDATION: NOT READY - Significant improvements needed\n";

      return eval;
   }

   //+------------------------------------------------------------------+
   //| Print Statistics to Log                                         |
   //+------------------------------------------------------------------+
   void PrintStats()
   {
      CalculateStats();

      Print("========================================");
      Print("   BACKTEST STATISTICS");
      Print("========================================");
      PrintFormat("Total Trades: %d | Win Rate: %.2f%%", m_stats.totalTrades, m_stats.winRate);
      PrintFormat("Net Profit: $%.2f | Profit Factor: %.2f", m_stats.netProfit, m_stats.profitFactor);
      PrintFormat("Average RR: 1:%.2f", m_stats.averageRR);
      PrintFormat("Max DD: $%.2f (%.2f%%)", m_stats.maxDrawdown, m_stats.maxDrawdownPercent);
      PrintFormat("Sharpe Ratio: %.2f", m_stats.sharpeRatio);
      Print("========================================");
   }

   //+------------------------------------------------------------------+
   //| Get Statistics                                                   |
   //+------------------------------------------------------------------+
   STradeStats GetStats()
   {
      CalculateStats();
      return m_stats;
   }
};
