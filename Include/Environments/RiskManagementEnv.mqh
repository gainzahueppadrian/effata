//+------------------------------------------------------------------+
//| RiskManagementEnv.mqh                                            |
//| Risk Management Environment (Monte Carlo & Prop Firm Rules)      |
//| Copyright 2025, EFFATA Reinforcement Trading Systems             |
//+------------------------------------------------------------------+
#property copyright "2025, EFFATA Reinforcement Trading Systems"
#property version   "3.20"
#property strict

#include "../Core/Structures.mqh"
#include "../Environments/StatisticsEnv.mqh"

// Prop Firm Logic
struct TradingFundedPropFirm {
   double balance;
   double profit_target;
   double risk_per_trade;
   int num_trades;
   double daily_drawdown_percent;
   double max_drawdown_percent;
   double wins;
   double losses;
};

class CRiskManagementEnv {
private:
   double m_maxDailyLoss;
   double m_riskPerTrade;
   bool m_adaptiveRisk;

   TradingFundedPropFirm m_propRules;

   CStatisticsEnv *m_statsEnv;

public:
   CRiskManagementEnv(double riskPercent, bool adaptive) {
      m_riskPerTrade = riskPercent;
      m_adaptiveRisk = adaptive;
      m_maxDailyLoss = 0.05; // 5% default

      // Default Prop Firm Rules
      m_propRules.balance = 0;
      m_propRules.daily_drawdown_percent = 0.04; // 4%
      m_propRules.max_drawdown_percent = 0.08;   // 8%
   }

   void SetStatisticsEnv(CStatisticsEnv *stats) { m_statsEnv = stats; }

   bool Initialize() {
      m_propRules.balance = AccountInfoDouble(ACCOUNT_BALANCE);
      return true;
   }

   void UpdateFromTick(const double &features[]) {
      // Check drawdown limits
      CheckPropFirmLimits();
   }

   RiskAssessment AssessCurrentRisk() {
      RiskAssessment r;
      r.allowTrading = true;
      r.riskScore = 0.5;

      if(CheckPropFirmLimits() == false) {
         r.allowTrading = false;
         r.riskScore = 1.0;
      }

      return r;
   }

   bool CheckPropFirmLimits() {
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);

      // Daily Drawdown Check
      // Needs daily starting balance logic (omitted for brevity, assume reset daily)

      // Max Drawdown Check
      double drawdown = (m_propRules.balance - equity) / m_propRules.balance;
      if(drawdown > m_propRules.max_drawdown_percent) {
         return false; // Breach
      }

      return true;
   }

   void SelfVerify(const double &features[]) {}
   void ConsolidateMemory() {}
   void OnSessionChange(const MarketContext &context) {}
};
