//+------------------------------------------------------------------+
//| AILLMTradingEnv.mqh                                              |
//| AI Powered LLM Trading Environment                               |
//+------------------------------------------------------------------+
#property copyright "2025, Advanced AI Trading Systems"
#property strict

#ifndef AILLM_TRADING_ENV_MQH
#define AILLM_TRADING_ENV_MQH

#include "../AI/AIIntegrator.mqh"
#include "../Calendar/EconomicCalendar.mqh"
#include "../Core/Structures.mqh"

struct AICache {
   datetime last_update;
   TradeDecision decision;
   string model_name;
};

class CAILLMTradingEnv {
private:
   CAIIntegrator *m_ai;
   CEconomicCalendar *m_calendar;

   string m_models[]; // List of models for ensemble
   AICache m_cache[]; // Cache for each model

   int m_cache_validity_seconds;

public:
   CAILLMTradingEnv() {
      m_ai = new CAIIntegrator();
      m_calendar = new CEconomicCalendar();
      m_cache_validity_seconds = 900; // 15 minutes

      ArrayResize(m_models, 3);
      m_models[0] = "gpt-4";
      m_models[1] = "claude-3-opus";
      m_models[2] = "gemini-pro";

      ArrayResize(m_cache, 3);
      for(int i=0; i<3; i++) {
         m_cache[i].last_update = 0;
         m_cache[i].decision.Initialize();
         m_cache[i].model_name = m_models[i];
      }
   }

   ~CAILLMTradingEnv() {
      delete m_ai;
      delete m_calendar;
   }

   void SetModelList(string &models[]) {
      int size = ArraySize(models);
      ArrayResize(m_models, size);
      ArrayResize(m_cache, size);
      for(int i=0; i<size; i++) {
         m_models[i] = models[i];
         m_cache[i].last_update = 0;
         m_cache[i].decision.Initialize();
         m_cache[i].model_name = models[i];
      }
   }

   TradeDecision GetRecommendation(const MarketData &data) {
       // Default single model recommendation (using first model)
       return GetModelDecision(0, data);
   }

   TradeDecision GetEnsembleRecommendation(const MarketData &data) {
      TradeDecision finalDecision;
      finalDecision.Initialize();

      double buyVote = 0;
      double sellVote = 0;
      double totalConfidence = 0;
      int activeModels = 0;

      for(int i=0; i<ArraySize(m_models); i++) {
         TradeDecision d = GetModelDecision(i, data);
         if(d.action != NO_SIGNAL) {
            if(d.action == BUY_SIGNAL) buyVote += d.confidence;
            if(d.action == SELL_SIGNAL) sellVote += d.confidence;
            totalConfidence += d.confidence;
            activeModels++;
         }
      }

      if(activeModels > 0) {
         if(buyVote > sellVote) {
            finalDecision.action = BUY_SIGNAL;
            finalDecision.confidence = buyVote / activeModels;
         } else if(sellVote > buyVote) {
            finalDecision.action = SELL_SIGNAL;
            finalDecision.confidence = sellVote / activeModels;
         } else {
            finalDecision.action = NO_SIGNAL;
         }

         // Average stops if available (simplification)
         // In real scenario, we should take the most conservative or average
      }

      return finalDecision;
   }

private:
   TradeDecision GetModelDecision(int index, const MarketData &data) {
      // Check cache validity
      if(TimeCurrent() - m_cache[index].last_update < m_cache_validity_seconds) {
         if(m_cache[index].last_update > 0) {
             return m_cache[index].decision;
         }
      }

      // Context
      EconomicEvent nextEvent = m_calendar->GetNextHighImpactEvent();
      string eventContext = "";
      if(nextEvent.time > 0) {
         eventContext = StringFormat("Next High Impact Event: %s for %s at %s. ",
            nextEvent.title, nextEvent.currency, TimeToString(nextEvent.time));
      }

      string prompt = StringFormat(
         "Analyze Market: Close=%.5f, ATR=%.5f. %s Provide JSON: {signal: 'BUY'/'SELL'/'HOLD', confidence: 0.0-1.0}",
         data.close, data.atr, eventContext
      );

      // Get Decision from Integrator
      TradeDecision decision = m_ai->GetDecisionFromModel(m_models[index], prompt);

      // Update Cache
      m_cache[index].last_update = TimeCurrent();
      m_cache[index].decision = decision;

      return decision;
   }
};
#endif // AILLM_TRADING_ENV_MQH
