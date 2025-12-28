//+------------------------------------------------------------------+
//|                                          ParameterOptimizer.mqh  |
//|                      Dynamic Parameter Optimization System        |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "2025, Manus AI - Parameter Optimizer"
#property link      "https://www.mql5.com"
#property strict

//+------------------------------------------------------------------+
//| Optimization Result Structure                                    |
//+------------------------------------------------------------------+
struct SOptimizationResult
{
   double riskPercent;
   double rrRatio;
   double partialRR1;
   double partialVol1;
   double partialRR2;
   double partialVol2;

   double netProfit;
   double winRate;
   double profitFactor;
   double maxDD;
   double sharpeRatio;
   double score;
};

//+------------------------------------------------------------------+
//| Parameter Optimizer Class                                        |
//+------------------------------------------------------------------+
class CParameterOptimizer
{
private:
   SOptimizationResult m_results[];
   int m_resultCount;

   // Optimization ranges
   double m_riskMin, m_riskMax, m_riskStep;
   double m_rrMin, m_rrMax, m_rrStep;

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   CParameterOptimizer()
   {
      m_resultCount = 0;
      ArrayResize(m_results, 0);

      // Default ranges
      m_riskMin = 0.5;
      m_riskMax = 2.0;
      m_riskStep = 0.5;

      m_rrMin = 2.0;
      m_rrMax = 5.0;
      m_rrStep = 0.5;
   }

   //+------------------------------------------------------------------+
   //| Set Optimization Ranges                                         |
   //+------------------------------------------------------------------+
   void SetRiskRange(double min, double max, double step)
   {
      m_riskMin = min;
      m_riskMax = max;
      m_riskStep = step;
   }

   void SetRRRange(double min, double max, double step)
   {
      m_rrMin = min;
      m_rrMax = max;
      m_rrStep = step;
   }

   //+------------------------------------------------------------------+
   //| Add Optimization Result                                         |
   //+------------------------------------------------------------------+
   void AddResult(double risk, double rr, double partialRR1, double partialVol1,
                  double partialRR2, double partialVol2, double netProfit,
                  double winRate, double profitFactor, double maxDD, double sharpe)
   {
      SOptimizationResult result;
      result.riskPercent = risk;
      result.rrRatio = rr;
      result.partialRR1 = partialRR1;
      result.partialVol1 = partialVol1;
      result.partialRR2 = partialRR2;
      result.partialVol2 = partialVol2;
      result.netProfit = netProfit;
      result.winRate = winRate;
      result.profitFactor = profitFactor;
      result.maxDD = maxDD;
      result.sharpeRatio = sharpe;

      // Calculate composite score
      result.score = CalculateScore(winRate, profitFactor, maxDD, sharpe);

      ArrayResize(m_results, m_resultCount + 1);
      m_results[m_resultCount] = result;
      m_resultCount++;
   }

   //+------------------------------------------------------------------+
   //| Calculate Composite Score                                       |
   //+------------------------------------------------------------------+
   double CalculateScore(double winRate, double profitFactor, double maxDD, double sharpe)
   {
      // Weighted scoring system
      double score = 0;

      // Win rate (0-30 points)
      score += (winRate / 100.0) * 30.0;

      // Profit factor (0-30 points, capped at 3.0)
      score += MathMin(profitFactor / 3.0, 1.0) * 30.0;

      // Max DD penalty (0-20 points, lower is better)
      if(maxDD < 10)
         score += 20;
      else if(maxDD < 20)
         score += 15;
      else if(maxDD < 30)
         score += 10;
      else
         score += 5;

      // Sharpe ratio (0-20 points, capped at 2.0)
      score += MathMin(sharpe / 2.0, 1.0) * 20.0;

      return score;
   }

   //+------------------------------------------------------------------+
   //| Get Best Result                                                 |
   //+------------------------------------------------------------------+
   SOptimizationResult GetBestResult()
   {
      if(m_resultCount == 0)
      {
         SOptimizationResult empty;
         return empty;
      }

      int bestIdx = 0;
      double bestScore = m_results[0].score;

      for(int i = 1; i < m_resultCount; i++)
      {
         if(m_results[i].score > bestScore)
         {
            bestScore = m_results[i].score;
            bestIdx = i;
         }
      }

      return m_results[bestIdx];
   }

   //+------------------------------------------------------------------+
   //| Get Top N Results                                               |
   //+------------------------------------------------------------------+
   void GetTopResults(SOptimizationResult &results[], int n)
   {
      if(m_resultCount == 0)
         return;

      // Sort results by score (descending)
      SOptimizationResult sorted[];
      ArrayResize(sorted, m_resultCount);
      ArrayCopy(sorted, m_results);

      // Simple bubble sort
      for(int i = 0; i < m_resultCount - 1; i++)
      {
         for(int j = 0; j < m_resultCount - i - 1; j++)
         {
            if(sorted[j].score < sorted[j + 1].score)
            {
               SOptimizationResult temp = sorted[j];
               sorted[j] = sorted[j + 1];
               sorted[j + 1] = temp;
            }
         }
      }

      // Get top N
      int count = MathMin(n, m_resultCount);
      ArrayResize(results, count);

      for(int i = 0; i < count; i++)
         results[i] = sorted[i];
   }

   //+------------------------------------------------------------------+
   //| Generate Optimization Report                                    |
   //+------------------------------------------------------------------+
   void GenerateReport(string filename)
   {
      int handle = FileOpen(filename, FILE_WRITE | FILE_TXT | FILE_ANSI);

      if(handle == INVALID_HANDLE)
      {
         Print("Failed to create optimization report: ", filename);
         return;
      }

      FileWrite(handle, "========================================");
      FileWrite(handle, "   PARAMETER OPTIMIZATION REPORT");
      FileWrite(handle, "========================================");
      FileWrite(handle, "");

      FileWrite(handle, StringFormat("Total combinations tested: %d", m_resultCount));
      FileWrite(handle, "");

      // Get top 10 results
      SOptimizationResult topResults[];
      GetTopResults(topResults, 10);

      FileWrite(handle, "--- TOP 10 PARAMETER COMBINATIONS ---");
      FileWrite(handle, "");

      for(int i = 0; i < ArraySize(topResults); i++)
      {
         FileWrite(handle, StringFormat("Rank #%d (Score: %.2f)", i + 1, topResults[i].score));
         FileWrite(handle, StringFormat("  Risk: %.2f%% | RR: 1:%.1f",
                   topResults[i].riskPercent, topResults[i].rrRatio));
         FileWrite(handle, StringFormat("  Partial TP1: RR 1:%.1f (%.0f%%) | TP2: RR 1:%.1f (%.0f%%)",
                   topResults[i].partialRR1, topResults[i].partialVol1,
                   topResults[i].partialRR2, topResults[i].partialVol2));
         FileWrite(handle, StringFormat("  Net Profit: $%.2f | Win Rate: %.2f%%",
                   topResults[i].netProfit, topResults[i].winRate));
         FileWrite(handle, StringFormat("  Profit Factor: %.2f | Max DD: %.2f%%",
                   topResults[i].profitFactor, topResults[i].maxDD));
         FileWrite(handle, StringFormat("  Sharpe Ratio: %.2f", topResults[i].sharpeRatio));
         FileWrite(handle, "");
      }

      FileWrite(handle, "========================================");
      FileWrite(handle, "   RECOMMENDED SETTINGS");
      FileWrite(handle, "========================================");
      FileWrite(handle, "");

      if(ArraySize(topResults) > 0)
      {
         SOptimizationResult best = topResults[0];

         FileWrite(handle, "Use the following parameters for optimal performance:");
         FileWrite(handle, "");
         FileWrite(handle, StringFormat("InpRiskPercent = %.2f", best.riskPercent));
         FileWrite(handle, StringFormat("InpFinalRR = %.1f", best.rrRatio));
         FileWrite(handle, StringFormat("InpPartialRR1 = %.1f", best.partialRR1));
         FileWrite(handle, StringFormat("InpPartialVol1 = %.0f", best.partialVol1));
         FileWrite(handle, StringFormat("InpPartialRR2 = %.1f", best.partialRR2));
         FileWrite(handle, StringFormat("InpPartialVol2 = %.0f", best.partialVol2));
         FileWrite(handle, "");
         FileWrite(handle, "Expected Performance:");
         FileWrite(handle, StringFormat("  Win Rate: %.2f%%", best.winRate));
         FileWrite(handle, StringFormat("  Profit Factor: %.2f", best.profitFactor));
         FileWrite(handle, StringFormat("  Max Drawdown: %.2f%%", best.maxDD));
      }

      FileWrite(handle, "");
      FileWrite(handle, "========================================");
      FileWrite(handle, "   END OF REPORT");
      FileWrite(handle, "========================================");

      FileClose(handle);

      Print("Optimization report generated: ", filename);
   }

   //+------------------------------------------------------------------+
   //| Print Summary                                                   |
   //+------------------------------------------------------------------+
   void PrintSummary()
   {
      Print("========================================");
      Print("   OPTIMIZATION SUMMARY");
      Print("========================================");
      PrintFormat("Total combinations tested: %d", m_resultCount);

      if(m_resultCount > 0)
      {
         SOptimizationResult best = GetBestResult();

         Print("");
         Print("--- BEST RESULT ---");
         PrintFormat("Score: %.2f", best.score);
         PrintFormat("Risk: %.2f%% | RR: 1:%.1f", best.riskPercent, best.rrRatio);
         PrintFormat("Win Rate: %.2f%% | Profit Factor: %.2f", best.winRate, best.profitFactor);
         PrintFormat("Max DD: %.2f%% | Sharpe: %.2f", best.maxDD, best.sharpeRatio);
      }

      Print("========================================");
   }
};

//+------------------------------------------------------------------+
//| Dynamic Risk Adjuster Class                                      |
//+------------------------------------------------------------------+
class CDynamicRiskAdjuster
{
private:
   double m_baseRisk;
   double m_currentRisk;
   double m_maxRisk;
   double m_minRisk;

   int m_consecutiveWins;
   int m_consecutiveLosses;

   double m_currentDD;
   double m_maxAllowedDD;

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   CDynamicRiskAdjuster(double baseRisk = 1.0, double maxDD = 1.0)
   {
      m_baseRisk = baseRisk;
      m_currentRisk = baseRisk;
      m_maxRisk = baseRisk * 1.5;
      m_minRisk = baseRisk * 0.5;

      m_consecutiveWins = 0;
      m_consecutiveLosses = 0;

      m_currentDD = 0;
      m_maxAllowedDD = maxDD;
   }

   //+------------------------------------------------------------------+
   //| Update Risk Based on Trade Result                               |
   //+------------------------------------------------------------------+
   void UpdateRisk(bool wasWin, double currentDD)
   {
      m_currentDD = currentDD;

      if(wasWin)
      {
         m_consecutiveWins++;
         m_consecutiveLosses = 0;

         // Gradually increase risk after wins (max 1.5x base)
         if(m_consecutiveWins >= 3 && m_currentDD < m_maxAllowedDD * 0.5)
         {
            m_currentRisk = MathMin(m_maxRisk, m_currentRisk * 1.1);
         }
      }
      else
      {
         m_consecutiveLosses++;
         m_consecutiveWins = 0;

         // Reduce risk after losses
         if(m_consecutiveLosses >= 2)
         {
            m_currentRisk = MathMax(m_minRisk, m_currentRisk * 0.8);
         }
      }

      // Emergency risk reduction if approaching max DD
      if(m_currentDD > m_maxAllowedDD * 0.7)
      {
         m_currentRisk = m_minRisk;
      }

      PrintFormat("Dynamic Risk Adjusted: %.2f%% (Wins: %d, Losses: %d, DD: %.2f%%)",
                  m_currentRisk, m_consecutiveWins, m_consecutiveLosses, m_currentDD);
   }

   //+------------------------------------------------------------------+
   //| Get Current Risk                                                |
   //+------------------------------------------------------------------+
   double GetCurrentRisk() { return m_currentRisk; }

   //+------------------------------------------------------------------+
   //| Reset Risk to Base                                              |
   //+------------------------------------------------------------------+
   void ResetRisk()
   {
      m_currentRisk = m_baseRisk;
      m_consecutiveWins = 0;
      m_consecutiveLosses = 0;
   }
};
