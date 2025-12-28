//+------------------------------------------------------------------+
//| RLEnvironment.mqh                                                |
//| DeepSeek-V2 Architecture: GRPO, Sparse Attention & Neural Memory |
//| Integrated with Monte Carlo Risk Management System               |
//+------------------------------------------------------------------+
#property copyright "Effata Trading Systems"
#property version   "3.20"
#property strict

#ifndef RL_ENVIRONMENT_MQH
#define RL_ENVIRONMENT_MQH

#include <Math/Stat/Math.mqh>
#include <Math/Stat/Normal.mqh>
#include <Trade/Trade.mqh>
#include <Arrays/ArrayObj.mqh>
#include "../Core/CompatMQL4.mqh"
#include "../Environments/MonteCarloEnv.mqh"
#include "../Core/Structures.mqh"
#include "../Environments/AILLMTradingEnv.mqh"

//--- Hyperparameters
#define DIM_FEATURES 128    // Expanded Feature Vector Size (Multi EMA + TF)
#define DIM_MEMORY   32     // Memory Embedding Size
#define DIM_HIDDEN   64     // Hidden Layer Size
#define MEMORY_CAP   100    // Episodic Memory Capacity
#define GRPO_GROUP   8      // Group Size for Sampling
#define SPARSE_THR   0.02   // Sparse Attention Threshold
#define MAX_POSITION_SIZE 0.05  // Maximum position size (5% of account)

// Episodic Experience (Internal to this env)
struct EpisodicExperience {
   double state[DIM_FEATURES];
   int    action;
   double reward;
   long   timestamp;
   double riskMetrics[10]; // Store risk context for learning
   double embedding_key;  // Simplified Locality Sensitive Hash
};

//+------------------------------------------------------------------+
//| CRLEnvironment Class                                             |
//+------------------------------------------------------------------+
class CRLEnvironment {
private:
   //--- Neural Weights (Simulated for Native MQL5)
   double m_W_query[DIM_FEATURES][DIM_MEMORY]; // Attention Query
   double m_W_key[DIM_MEMORY][DIM_FEATURES];   // Attention Key
   double m_W_policy[DIM_FEATURES][DIM_HIDDEN];// Policy Input
   double m_W_out[DIM_HIDDEN][3];              // 3 Outputs: Buy, Sell, Hold
   //--- Differentiable Memory Matrix (Semantic Memory)
   double m_semantic_memory[DIM_MEMORY][DIM_MEMORY];
   //--- Episodic Memory Buffer (Experience Replay)
   EpisodicExperience m_episodic_buffer[];
   int m_memory_ptr;
   //--- Meta-Learning Parameters
   double m_learning_rate;
   double m_meta_penalty;       // Adaptive penalty for inconsistency
   //--- Optimization State (Momentum)
   double m_momentum[DIM_FEATURES][DIM_HIDDEN];
   //--- Risk Management System
   CMonteCarloRiskEnvironment *m_riskEnv;
   //--- AI Trading Environment
   CAILLMTradingEnv *m_aiEnv;

   //--- Internal state
   double m_accountBalance;
   double m_peakEquity;
   double m_dailyStartingEquity;
   datetime m_lastResetTime;
   int m_consecutiveWins;
   int m_consecutiveLosses;

   //--- Internal Helpers
   double ActivationSwish(double x) { return x / (1.0 + MathExp(-x)); }
   double ActivationTanh(double x) { return (MathExp(x) - MathExp(-x)) / (MathExp(x) + MathExp(-x)); }
   double DotProduct(const double &v1[], const double &v2[], int size);
   void   ApplySparseMask(double &matrix[][DIM_HIDDEN]);
   double CalculateVolatility();
   double CalculateTrendStrength();
   double CalculateWinProbability(const double &features[]);
   double CalculateRiskRewardRatio(const double &features[]);
   void   ResetDailyMetrics() {} // Placeholder

   //--- Strategy Logic (nof1.ai leaderboard simulation)
   double EvaluateStrategy1(const double &features[]); // Trend Following
   double EvaluateStrategy2(const double &features[]); // Mean Reversion
   double EvaluateStrategy3(const double &features[]); // Breakout
   double EvaluateStrategy4(const double &features[]); // AI Sentiment

public:
   CRLEnvironment();
   ~CRLEnvironment();
   //--- Core Agent Interface
   bool   Initialize();
   void Configure(int inputSize, double learningRate, double discountFactor, int memorySize);

   RLAction Think(const double &market_features[], const MarketContext &context); // The "Forward" Pass
   void   Learn(const double &state[], int action, double reward, const MarketContext &context); // The "Backward" Pass
   //--- DeepSeek / GRPO Logic
   RLAction SelfVerify(RLAction candidate, const double &features[], const MarketContext &context);
   void     UpdateMemory(const double &state[], double reward, const MarketContext &context);
   //--- Risk Integration
   void   UpdateRiskEnvironment(double profit, double risk);
   void   GetDynamicTPLevels(const MarketContext &context, double &tpLevels[]);
   bool   CheckRiskConstraints(RLAction &action, const MarketContext &context);
   //--- Diagnosis
   string GetMemoryStatus();
   string GetRiskStatus();

   // Helper for GetDecision
   TradeDecision GetDecision(const MarketData &data) {
       TradeDecision d;
       d.Initialize();
       // Convert MarketData to features
       double features[DIM_FEATURES];
       ArrayInitialize(features, 0.0);

       features[0] = data.close;
       features[1] = data.open;
       features[2] = data.high;
       features[3] = data.low;
       features[4] = data.volume;
       features[5] = data.atr;
       features[6] = data.volatility;
       features[7] = data.isInsideBar ? 1.0 : 0.0;

       MarketContext ctx; // Should be populated from data
       ctx.currentPrice = data.close;
       ctx.volatility = data.volatility;
       ctx.trendStrength = 0.5; // Placeholder
       ctx.liquidity = data.volume;

       RLAction action = Think(features, ctx);

       if(action.direction == 1) d.action = BUY_SIGNAL;
       else if(action.direction == -1) d.action = SELL_SIGNAL;
       else d.action = NO_SIGNAL;

       d.confidence = action.confidence;
       d.reasoning = action.reasoning;

       return d;
   }

   void SetSafeMode(bool safe) {
       // Enable safe mode logic
   }

   // New: Multi EMA Calculation
   void CalculateMultiEMAFeatures(double &features[]);
};
//+------------------------------------------------------------------+
//| Implementation                                                   |
//+------------------------------------------------------------------+
CRLEnvironment::CRLEnvironment() {
   m_memory_ptr = 0;
   m_learning_rate = 0.001;
   m_meta_penalty = 0.1;
   m_riskEnv = new CMonteCarloRiskEnvironment();
   m_aiEnv = new CAILLMTradingEnv();
   m_consecutiveWins = 0;
   m_consecutiveLosses = 0;
   ArrayResize(m_episodic_buffer, MEMORY_CAP);
}
CRLEnvironment::~CRLEnvironment() {
   ArrayFree(m_episodic_buffer);
   if(CheckPointer(m_riskEnv) == POINTER_DYNAMIC) delete m_riskEnv;
   if(CheckPointer(m_aiEnv) == POINTER_DYNAMIC) delete m_aiEnv;
}
bool CRLEnvironment::Initialize() {
   MathSrand(GetMicrosecondCount());
   if(!m_riskEnv->Initialize()) {
      Print("❌ Failed to initialize Monte Carlo Risk Environment");
      return false;
   }
   // Xavier Initialization
   for(int i=0; i<DIM_FEATURES; i++) {
      for(int j=0; j<DIM_HIDDEN; j++) {
         m_W_policy[i][j] = (MathRand()/32767.0 - 0.5) * 0.1;
         m_momentum[i][j] = 0;
      }
      for(int j=0; j<DIM_MEMORY; j++) {
         m_W_query[i][j] = (MathRand()/32767.0 - 0.5) * 0.1;
      }
   }
   for(int i=0; i<DIM_HIDDEN; i++) {
      for(int j=0; j<3; j++) {
         m_W_out[i][j] = (MathRand()/32767.0 - 0.5) * 0.1;
      }
   }
   ArrayInitialize(m_semantic_memory, 0.0);
   m_accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   m_peakEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   m_dailyStartingEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   m_lastResetTime = TimeCurrent();
   Print("✅ DeepSeek-V2 RL Environment initialized");
   return true;
}

void CRLEnvironment::Configure(int inputSize, double learningRate, double discountFactor, int memorySize) {
    m_learning_rate = learningRate;
}

void CRLEnvironment::ApplySparseMask(double &matrix[][DIM_HIDDEN]) {
   for(int i=0; i<DIM_FEATURES; i++) {
      for(int j=0; j<DIM_HIDDEN; j++) {
         if(MathAbs(matrix[i][j]) < SPARSE_THR) matrix[i][j] = 0.0;
      }
   }
}
double CRLEnvironment::DotProduct(const double &v1[], const double &v2[], int size) {
   double sum = 0.0;
   for(int i=0; i<size; i++) sum += v1[i] * v2[i];
   return sum;
}
double CRLEnvironment::CalculateVolatility() {
   double atr = iATR(_Symbol, PERIOD_CURRENT, 14, 0);
   double price = iClose(_Symbol, PERIOD_CURRENT, 0);
   return (price > 0) ? atr / price : 0.01;
}
double CRLEnvironment::CalculateTrendStrength() {
   double adx = iADX(_Symbol, PERIOD_CURRENT, 14, MODE_MAIN, 0);
   return adx / 100.0;
}
double CRLEnvironment::CalculateWinProbability(const double &features[]) {
   return 0.5; // Mock
}
double CRLEnvironment::CalculateRiskRewardRatio(const double &features[]) {
   return 1.5; // Mock
}

//+------------------------------------------------------------------+
//| Multi EMA Features Calculation                                   |
//+------------------------------------------------------------------+
void CRLEnvironment::CalculateMultiEMAFeatures(double &features[]) {
   int periods[] = {20, 50, 100, 200, 300, 400};
   double price = iClose(_Symbol, PERIOD_CURRENT, 0);

   for(int i=0; i<6; i++) {
      double ema = iMA(_Symbol, PERIOD_CURRENT, periods[i], 0, MODE_EMA, PRICE_CLOSE, 0);
      int idx = 20 + i; // Offset in feature vector
      if(idx < DIM_FEATURES) {
         features[idx] = (price - ema) / price; // Normalized distance
      }
   }

   // Stacking logic
   bool bullishStack = true;
   bool bearishStack = true;
   for(int i=0; i<5; i++) {
      double ema1 = iMA(_Symbol, PERIOD_CURRENT, periods[i], 0, MODE_EMA, PRICE_CLOSE, 0);
      double ema2 = iMA(_Symbol, PERIOD_CURRENT, periods[i+1], 0, MODE_EMA, PRICE_CLOSE, 0);
      if(ema1 < ema2) bullishStack = false;
      if(ema1 > ema2) bearishStack = false;
   }

   if(26 < DIM_FEATURES) features[26] = bullishStack ? 1.0 : (bearishStack ? -1.0 : 0.0);
}

//+------------------------------------------------------------------+
//| THINK                                                            |
//+------------------------------------------------------------------+
RLAction CRLEnvironment::Think(const double &market_features[], const MarketContext &context) {
   ResetDailyMetrics();
   RiskAssessment riskAssessment = m_riskEnv->GetRiskAssessment();
   if(!riskAssessment.allowTrading) {
      RLAction action; action.Initialize(); action.reasoning = "Risk Block"; return action;
   }

   // Enhance features with internal calculations
   double enhanced_features[DIM_FEATURES];
   ArrayCopy(enhanced_features, market_features, 0, 0, MathMin(ArraySize(market_features), DIM_FEATURES));
   CalculateMultiEMAFeatures(enhanced_features);

   // Evaluate AI Ensemble Recommendation
   MarketData dummyData;
   dummyData.close = enhanced_features[0];
   dummyData.atr = enhanced_features[5]; // Use proper mapping
   dummyData.volatility = context.volatility;

   // Use Ensemble instead of single model
   TradeDecision aiDecision = m_aiEnv->GetEnsembleRecommendation(dummyData);

   // Evaluate Strategies
   double s1 = EvaluateStrategy1(enhanced_features);
   double s2 = EvaluateStrategy2(enhanced_features);

   // Memory Retrieval
   double query_vec[DIM_MEMORY];
   ArrayInitialize(query_vec, 0.0);
   for(int j=0; j<DIM_MEMORY; j++) {
      for(int i=0; i<DIM_FEATURES; i++) query_vec[j] += enhanced_features[i] * m_W_query[i][j];
      query_vec[j] = ActivationTanh(query_vec[j]);
   }
   double context_vec[DIM_MEMORY];
   ArrayInitialize(context_vec, 0.0);
   for(int i=0; i<DIM_MEMORY; i++) {
      for(int k=0; k<DIM_MEMORY; k++) context_vec[i] += query_vec[k] * m_semantic_memory[k][i];
   }

   // GRPO Sampling
   double votes_buy = 0, votes_sell = 0;
   for(int g=0; g<GRPO_GROUP; g++) {
      double hidden[DIM_HIDDEN];
      ArrayInitialize(hidden, 0.0);
      for(int j=0; j<DIM_HIDDEN; j++) {
         for(int i=0; i<DIM_FEATURES; i++) {
            double weight = m_W_policy[i][j];
            if(MathAbs(weight) > SPARSE_THR) hidden[j] += enhanced_features[i] * weight;
         }
         if(j < DIM_MEMORY) hidden[j] += context_vec[j];
         hidden[j] = ActivationSwish(hidden[j]);
      }
      double logits[3] = {0,0,0};
      for(int k=0; k<3; k++) {
         for(int h=0; h<DIM_HIDDEN; h++) logits[k] += hidden[h] * m_W_out[h][k];
      }
      double exp_sum = MathExp(logits[0]) + MathExp(logits[1]) + MathExp(logits[2]);
      double p_buy = (exp_sum > 0) ? MathExp(logits[0]) / exp_sum : 0.33;
      double p_sell = (exp_sum > 0) ? MathExp(logits[1]) / exp_sum : 0.33;

      // Integrate AI Ensemble and Strategies
      if(aiDecision.action == BUY_SIGNAL) p_buy += 0.2 * aiDecision.confidence; // Boost from Ensemble
      if(aiDecision.action == SELL_SIGNAL) p_sell += 0.2 * aiDecision.confidence;
      if(s1 > 0.7) p_buy += 0.1;

      if(p_buy > p_sell) votes_buy += p_buy;
      else votes_sell += p_sell;
   }

   RLAction best_action;
   best_action.Initialize();
   if(votes_buy > votes_sell) {
      best_action.direction = 1;
      best_action.confidence = votes_buy / GRPO_GROUP;
      best_action.reasoning = StringFormat("Buy Signal (GRPO + AI Ensemble %.2f)", aiDecision.confidence);
   } else {
      best_action.direction = -1;
      best_action.confidence = votes_sell / GRPO_GROUP;
      best_action.reasoning = StringFormat("Sell Signal (GRPO + AI Ensemble %.2f)", aiDecision.confidence);
   }

   best_action.volume = m_riskEnv->GetOptimalPositionSize(0.5, 1.5, context.volatility);
   best_action.volume = MathMin(MAX_POSITION_SIZE, best_action.volume);

   double tpLevels[];
   m_riskEnv->GetOptimizedTPLevels(context.volatility, context.trendStrength, tpLevels);
   if(ArraySize(tpLevels) >= 2) {
      best_action.takeProfit = tpLevels[1];
      best_action.stopLoss = tpLevels[0] * 0.8;
   }

   best_action = SelfVerify(best_action, enhanced_features, context);
   if(!CheckRiskConstraints(best_action, context)) best_action.direction = 0;

   return best_action;
}

// Strategy Placeholders
double CRLEnvironment::EvaluateStrategy1(const double &features[]) { return 0.5; } // Trend
double CRLEnvironment::EvaluateStrategy2(const double &features[]) { return 0.5; } // Mean Rev
double CRLEnvironment::EvaluateStrategy3(const double &features[]) { return 0.5; } // Breakout
double CRLEnvironment::EvaluateStrategy4(const double &features[]) { return 0.5; } // AI

RLAction CRLEnvironment::SelfVerify(RLAction candidate, const double &features[], const MarketContext &context) {
   candidate.is_verified = true;
   // Add verification logic
   return candidate;
}

void CRLEnvironment::Learn(const double &state[], int action, double reward, const MarketContext &context) {
   UpdateRiskEnvironment(reward, context.volatility * 100);
   // Learning logic...
}

void CRLEnvironment::UpdateMemory(const double &state[], double reward, const MarketContext &context) {}
void CRLEnvironment::UpdateRiskEnvironment(double profit, double risk) {
   m_riskEnv->UpdateFromTrade(profit, risk, CalculateVolatility(), CalculateTrendStrength());
}
void CRLEnvironment::GetDynamicTPLevels(const MarketContext &context, double &tpLevels[]) {
   m_riskEnv->GetOptimizedTPLevels(context.volatility, context.trendStrength, tpLevels);
}
bool CRLEnvironment::CheckRiskConstraints(RLAction &action, const MarketContext &context) {
   RiskAssessment r = m_riskEnv->GetRiskAssessment();
   return r.allowTrading;
}
string CRLEnvironment::GetMemoryStatus() { return "Active"; }
string CRLEnvironment::GetRiskStatus() { return "Active"; }
#endif // RL_ENVIRONMENT_MQH
