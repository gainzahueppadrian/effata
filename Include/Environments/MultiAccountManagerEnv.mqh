//+------------------------------------------------------------------+
//| MultiAccountManagerEnv.mqh                                       |
//| Manages multiple accounts/strategies allocation                  |
//+------------------------------------------------------------------+
#property copyright "Effata Trading Systems"
#property strict

#ifndef MULTI_ACCOUNT_MANAGER_ENV_MQH
#define MULTI_ACCOUNT_MANAGER_ENV_MQH

#include <Arrays/ArrayObj.mqh>
#include "../RL/RLEnvironment.mqh"

// Structure to hold account configuration
class CManagedAccount : public CObject {
public:
   string accountID;
   double balance;
   double riskAllocation; // 0.0 to 1.0
   bool isActive;
   string strategyName;

   CManagedAccount(string id, double bal, double risk) {
       accountID = id;
       balance = bal;
       riskAllocation = risk;
       isActive = true;
       strategyName = "DeepSeek_RL";
   }
};

class CMultiAccountManagerEnv {
private:
   CArrayObj *m_accounts; // List of ManagedAccount objects
   CRLEnvironment *m_rlEnv; // Main RL logic

public:
   CMultiAccountManagerEnv() {
      m_accounts = new CArrayObj();
      m_rlEnv = new CRLEnvironment();
   }

   ~CMultiAccountManagerEnv() {
      if(CheckPointer(m_accounts) == POINTER_DYNAMIC) delete m_accounts;
      if(CheckPointer(m_rlEnv) == POINTER_DYNAMIC) delete m_rlEnv;
   }

   void AddAccount(string id, double balance, double risk) {
       CManagedAccount *acc = new CManagedAccount(id, balance, risk);
       m_accounts.Add(acc);
       Print("✅ Account Added: ", id, " | Alloc: ", risk*100, "%");
   }

   void DistributeSignal(int direction, double baseVolume) {
       for(int i=0; i<m_accounts.Total(); i++) {
           CManagedAccount *acc = (CManagedAccount*)m_accounts.At(i);
           if(acc != NULL && acc.isActive) {
               double vol = baseVolume * acc.riskAllocation;
               // In a real multi-terminal setup, this would write to a file or socket
               // for the slave terminals to pick up.
               Print("📡 Signal -> Account ", acc.accountID, ": ",
                     (direction==1 ? "BUY" : "SELL"), " Vol: ", vol);
           }
       }
   }

   void OnTick() {
       // Centralized orchestration
       // 1. Get Global Signal from RL Env
       // (Logic requires MarketContext building, omitted for brevity)
   }
};

#endif
