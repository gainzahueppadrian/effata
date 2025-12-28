//+------------------------------------------------------------------+
//| Structures.mqh - Core Data Structures                             |
//| EFFATA Orchestrator HFT Trading System                           |
//+------------------------------------------------------------------+
#property copyright "Effata Reinforcement Trading"
#property strict

#ifndef EFFATA_STRUCTURES_MQH
#define EFFATA_STRUCTURES_MQH

// Signal Types
enum SIGNAL_TYPE {
   NO_SIGNAL = 0,
   BUY_SIGNAL = 1,
   SELL_SIGNAL = 2,
   REVERSE_LONG = 3,
   REVERSE_SHORT = 4
};

// Risk Profiles
enum RISK_PROFILE {
   ULTRA_SAFE = 1,
   SAFE = 2,
   MODERATE = 3,
   AGGRESSIVE = 4,
   HEDGE_FUND = 5
};

// ML Algorithm Types
enum ML_ALGORITHM {
   NO_ML = 0,
   PPO = 1,
   SAC = 2,
   TD3 = 3,
   GRPO = 4,    // DeepSeek's Group Relative Policy Optimization
   HYBRID = 5
};

// Agent Types
enum AGENT_TYPE {
   PATTERN_AGENT = 0,
   STRATEGY_AGENT = 1,
   RISK_AGENT = 2,
   EXECUTION_AGENT = 3,
   STATISTICS_AGENT = 4
};

// Verification Status
enum VERIFICATION_STATUS {
   UNVERIFIED = 0,
   VERIFIED_LOW = 1,
   VERIFIED_MEDIUM = 2,
   VERIFIED_HIGH = 3,
   SELF_CONSISTENT = 4
};

//+------------------------------------------------------------------+
//| Core State Structure for RL                                       |
//+------------------------------------------------------------------+
struct RLState {
   double features[64];          // Feature vector
   double context[32];           // Context memory
   double hidden_state[128];     // Hidden state for recurrent processing
   datetime timestamp;           // State timestamp
   int market_regime;            // Market regime classification

   void Initialize() {
      ArrayInitialize(features, 0.0);
      ArrayInitialize(context, 0.0);
      ArrayInitialize(hidden_state, 0.0);
      timestamp = 0;
      market_regime = 0;
   }
};

//+------------------------------------------------------------------+
//| Action Structure with Confidence                                  |
//+------------------------------------------------------------------+
struct RLAction {
   int direction;                // 1: Buy, -1: Sell, 0: Hold
   double volume;                // Position size
   double confidence;            // Self-Verification confidence score
   double sl_ratio;              // Stop Loss ratio
   double tp_ratio;              // Take Profit ratio
   double urgency;               // Execution urgency (0-1)
   string reasoning;             // Chain-of-thought reasoning
   VERIFICATION_STATUS verified; // Verification status

   // Extra fields from RLEnvironment usage
   bool is_verified;
   double stopLoss;
   double takeProfit;
   double riskReward;
   double expectedWinRate;

   void Initialize() {
      direction = 0;
      volume = 0.0;
      confidence = 0.0;
      sl_ratio = 1.0;
      tp_ratio = 2.0;
      urgency = 0.5;
      reasoning = "";
      verified = UNVERIFIED;

      is_verified = false;
      stopLoss = 0.0;
      takeProfit = 0.0;
      riskReward = 0.0;
      expectedWinRate = 0.5;
   }
};

//+------------------------------------------------------------------+
//| Experience for Replay Memory                                      |
//+------------------------------------------------------------------+
struct Experience {
   RLState state;
   RLAction action;
   double reward;
   RLState next_state;
   bool done;
   double td_error;              // For prioritized replay
   double priority;              // Priority weight
   int age;                      // Experience age for freshness

   void Initialize() {
      state.Initialize();
      action.Initialize();
      reward = 0.0;
      next_state.Initialize();
      done = false;
      td_error = 0.0;
      priority = 1.0;
      age = 0;
   }
};

//+------------------------------------------------------------------+
//| Trade Decision Structure                                          |
//+------------------------------------------------------------------+
struct TradeDecision {
   SIGNAL_TYPE action;
   double positionSize;
   double stopLoss;
   double takeProfit;
   double confidence;
   double riskReward;
   string pattern;
   string reasoning;
   AGENT_TYPE source_agent;
   double agent_weights[5];      // Weights from each agent

   void Initialize() {
      action = NO_SIGNAL;
      positionSize = 0.0;
      stopLoss = 0.0;
      takeProfit = 0.0;
      confidence = 0.0;
      riskReward = 0.0;
      pattern = "";
      reasoning = "";
      source_agent = PATTERN_AGENT;
      ArrayInitialize(agent_weights, 0.2);
   }
};

//+------------------------------------------------------------------+
//| Market Data Structure                                             |
//+------------------------------------------------------------------+
struct MarketData {
   double open;
   double high;
   double low;
   double close;
   double volume;
   datetime time;
   double atr;
   double volatility;
   double spread;
   bool isInsideBar;
   bool isLargeRange;
   int trend_direction;          // 1: Up, -1: Down, 0: Sideways
   double momentum;
   double liquidity_score;
};

//+------------------------------------------------------------------+
//| Pattern Detection Result                                          |
//+------------------------------------------------------------------+
struct PatternResult {
   bool crtSignal;
   bool po3Signal;
   bool turtleSoup;
   bool kissOfDeath;
   bool smtDivergence;
   bool fiboLevel;
   bool wickPattern;
   bool orderBlock;
   bool fairValueGap;
   double patternStrength;
   double volumeConfirmation;
   double confidence;
   datetime detectionTime;
   string patternName;
};

//+------------------------------------------------------------------+
//| Neural Memory Entry                                               |
//+------------------------------------------------------------------+
// Renamed to avoid conflict if any, but sticking to existing usage
struct MemoryEntryCore {
   double key[64];               // Memory key for attention
   double value[64];             // Memory value
   double importance;            // Importance weight
   int access_count;             // Access frequency
   datetime created;             // Creation time
   datetime last_accessed;       // Last access time

   void Initialize() {
      ArrayInitialize(key, 0.0);
      ArrayInitialize(value, 0.0);
      importance = 0.0;
      access_count = 0;
      created = TimeCurrent();
      last_accessed = TimeCurrent();
   }
};

//+------------------------------------------------------------------+
//| Statistics Record                                                 |
//+------------------------------------------------------------------+
struct TradeStatistics {
   int total_trades;
   int winning_trades;
   int losing_trades;
   double total_profit;
   double total_loss;
   double max_drawdown;
   double sharpe_ratio;
   double profit_factor;
   double win_rate;
   double avg_win;
   double avg_loss;
   double expectancy;
   double recovery_factor;
   double calmar_ratio;
   datetime start_date;
   datetime end_date;

   void Initialize() {
      total_trades = 0;
      winning_trades = 0;
      losing_trades = 0;
      total_profit = 0.0;
      total_loss = 0.0;
      max_drawdown = 0.0;
      sharpe_ratio = 0.0;
      profit_factor = 0.0;
      win_rate = 0.0;
      avg_win = 0.0;
      avg_loss = 0.0;
      expectancy = 0.0;
      recovery_factor = 0.0;
      calmar_ratio = 0.0;
      start_date = 0;
      end_date = 0;
   }
};

// Risk Assessment Structure
struct RiskAssessment {
    bool allowTrading;
    string reason;
    double riskScore;
    double recommendedPositionSize;
};

// Market Context Structure (Common)
struct MarketContext {
   double volatility;
   double trendStrength;
   double liquidity;
   string sessionType;
   double drawdown;
   double neuralConfidence;
   double currentPrice; // Added to unify
   double volumeProfile; // Added to unify
   double liquidityScore; // Added to unify
   datetime timestamp; // Added to unify
};

#endif // EFFATA_STRUCTURES_MQH
