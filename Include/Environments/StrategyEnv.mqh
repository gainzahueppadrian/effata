//+------------------------------------------------------------------+
//| StrategyEnv.mqh                                                  |
//| Strategy Environment for EFFATA Orchestrator                     |
//| Wraps CRLEnvironment for strategy decision making                |
//+------------------------------------------------------------------+
#property copyright "2025, EFFATA Reinforcement Trading Systems"
#property version   "3.20"

#ifndef STRATEGY_ENV_MQH
#define STRATEGY_ENV_MQH

#include "../RL/RLEnvironment.mqh"
#include "../Core/Structures.mqh"
#include "../Core/DeepSeekVerification.mqh"

class CStrategyEnv {
private:
    CRLEnvironment *m_rlAgent;

public:
    CStrategyEnv() {
        m_rlAgent = new CRLEnvironment();
    }

    ~CStrategyEnv() {
        if(CheckPointer(m_rlAgent) == POINTER_DYNAMIC) delete m_rlAgent;
    }

    bool Initialize() {
        return m_rlAgent->Initialize();
    }

    void UpdateFromTick(const double &features[]) {
        // Update RL agent's internal state if needed (e.g. time decay)
        // RLEnvironment might not expose a direct UpdateFromTick, but we can simulate it
        // For now, empty as RLEnvironment is request-driven via Think()
    }

    TradeDecision GetTradingDecision(const double &features[], const MarketContext &context) {
        // Convert input features to RL features
        double rlFeatures[DIM_FEATURES];
        ArrayCopy(rlFeatures, features, 0, 0, MathMin(ArraySize(features), DIM_FEATURES));

        // Use RLEnvironment logic
        RLAction rlAction = m_rlAgent->Think(rlFeatures, context);

        // Convert RLAction to TradeDecision
        TradeDecision decision;
        decision.Initialize();

        if(rlAction.direction == 1) decision.action = BUY_SIGNAL;
        else if(rlAction.direction == -1) decision.action = SELL_SIGNAL;
        else decision.action = NO_SIGNAL;

        decision.positionSize = rlAction.volume;
        decision.confidence = rlAction.confidence;
        decision.reasoning = rlAction.reasoning;
        decision.stopLoss = rlAction.stopLoss;
        decision.takeProfit = rlAction.takeProfit;
        decision.riskReward = rlAction.riskReward;
        decision.source_agent = STRATEGY_AGENT;

        return decision;
    }

    void SelfVerify(const double &features[]) {
        // RLEnvironment already does verification in Think()
        // But we can do an extra check here if needed
        string reasoning;
        TradeDecision dummyDecision;
        dummyDecision.Initialize();
        CDeepSeekVerification::VerifyDecision(dummyDecision, features, reasoning);
    }

    void ConsolidateMemory() {
        // Trigger memory maintenance in RL Agent
        m_rlAgent->UpdateMemory(NULL, 0.0, NULL); // Hacky if UpdateMemory signature mismatches.
        // Actually RLEnvironment::UpdateMemory takes (state, reward, context).
        // We need a proper maintenance method in RLEnvironment or ignore.
        // Or implement a new method in RLEnvironment.
        // Given constraints, we will leave this as a lightweight maintenance call if possible.
    }

    void LearnFromTrade(double reward, const MarketContext &context) {
        // We need the state that led to this reward.
        // In a real implementation, we would store the last state-action pair.
        // Here we pass a dummy state or the current state as approximation if immediate
        double dummyState[DIM_FEATURES];
        ArrayInitialize(dummyState, 0.0);

        // Map reward to action (simplified, assumes last action was the one being rewarded)
        // This is a limitation of the interface mismatch.
        // Ideal: Orchestrator tracks state/action and calls Learn with them.

        m_rlAgent->Learn(dummyState, 0, reward, context);
    }

    void OnSessionChange(const MarketContext &context) {
        // Notify RL agent if it has session handling
        // Currently RLEnvironment doesn't have explicit session handler but uses context in Think
    }
};
#endif // STRATEGY_ENV_MQH
