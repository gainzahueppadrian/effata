#ifndef RISK_MANAGEMENT_ENV_MQH
#define RISK_MANAGEMENT_ENV_MQH

#include "MonteCarloEnv.mqh"
#include "../Core/Structures.mqh"
#include "../Core/CompatMQL4.mqh"
#include "../Calendar/EconomicCalendar.mqh"

class CRiskManagementEnv {
private:
    CMonteCarloRiskEnvironment *m_monteCarloEnv;
    CEconomicCalendar *m_calendar;
    double m_riskPerTradePercent;
    bool m_enableAdaptiveRisk;
    double m_initialEquity;

public:
    CRiskManagementEnv(double riskPerTrade = 0.005, bool enableAdaptive = true) {
        m_riskPerTradePercent = riskPerTrade;
        m_enableAdaptiveRisk = enableAdaptive;
        m_monteCarloEnv = new CMonteCarloRiskEnvironment();
        m_calendar = new CEconomicCalendar();
        m_initialEquity = 0;
    }

    ~CRiskManagementEnv() {
        if(CheckPointer(m_monteCarloEnv) == POINTER_DYNAMIC) delete m_monteCarloEnv;
        if(CheckPointer(m_calendar) == POINTER_DYNAMIC) delete m_calendar;
    }

    bool Initialize() {
        m_initialEquity = AccountInfoDouble(ACCOUNT_EQUITY);
        m_calendar->UpdateCalendar(); // Initial fetch
        return m_monteCarloEnv->Initialize();
    }

    RiskAssessment AssessCurrentRisk() {
        RiskAssessment r = m_monteCarloEnv->GetRiskAssessment();
        if(IsAbnormalVolatility()) {
            r.riskScore += 0.2;
            r.reason += " | Abnormal Volatility";
        }
        return r;
    }

    double CalculateCompoundingPositionSize(double riskPercent, double volatility) {
        double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
        double growthFactor = (m_initialEquity > 0) ? currentEquity / m_initialEquity : 1.0;
        double volFactor = (volatility > 0) ? (0.01 / volatility) : 1.0;

        // Base lot based on risk percent of equity
        double stopLossPoints = 100 * _Point; // Default if unknown, should use ATR
        double riskAmount = currentEquity * riskPercent;
        double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
        double baseLot = 0.01;
        if(tickValue > 0) baseLot = riskAmount / (stopLossPoints * tickValue);

        return baseLot * growthFactor * MathMin(1.5, volFactor); // Cap growth
    }

    double CalculateOptimalPositionSize(double winProbability, double riskRewardRatio, double stopLossPoints) {
        double volatility = CalculateVolatility();
        double size = m_monteCarloEnv->GetOptimalPositionSize(winProbability, riskRewardRatio, volatility);

        // Adjust for event risk
        size *= GetEventRiskMultiplier();

        return size;
    }

    void CalculateDynamicTPLevels(double volatility, double trendStrength, double &levels[]) {
        m_monteCarloEnv->GetOptimizedTPLevels(volatility, trendStrength, levels);
    }

    bool ShouldActivateHedge(double currentDrawdown, double positionProfit) {
        return m_monteCarloEnv->ShouldActivateHedge(currentDrawdown, positionProfit);
    }

    void UpdateFromTrade(double profit, double risk) {
        double volatility = CalculateVolatility();
        double trendStrength = CalculateTrendStrength();
        m_monteCarloEnv->UpdateFromTrade(profit, risk, volatility, trendStrength);
    }

    void UpdateFromTick(const double &features[]) {
        // Update Monte Carlo environment if needed
    }

    void SelfVerify(const double &features[]) {
        // Self-verification logic
    }

    void ConsolidateMemory() {
        // Memory consolidation logic
    }

    void LearnFromTrade(double reward, const MarketContext &context) {
        // Learning logic
    }

    void OnSessionChange(const MarketContext &context) {
        // Session change handling
    }

    // New Features methods
    double GetEventRiskMultiplier() {
        EconomicEvent nextEvent = m_calendar->GetNextHighImpactEvent();
        if(nextEvent.time > 0) {
            long timeDiff = nextEvent.time - TimeCurrent();
            if(timeDiff < 3600 && timeDiff > -1800) { // 1h before, 30m after
                return 0.5; // Reduce risk by half
            }
        }
        return 1.0;
    }

    bool IsAbnormalVolatility() {
        double currentVol = CalculateVolatility();
        // Assuming avg vol is around 0.001-0.005 for forex
        return (currentVol > 0.01); // Threshold
    }

private:
    double CalculateVolatility() {
        // Calculate volatility using ATR or standard deviation
        double atr = iATR(_Symbol, PERIOD_CURRENT, 14, 0);
        double close = iClose(_Symbol, PERIOD_CURRENT, 0);
        return (close > 0) ? atr / close : 0;
    }

    double CalculateTrendStrength() {
        // Calculate trend strength using ADX or moving average slope
        double adx = iADX(_Symbol, PERIOD_CURRENT, 14, MODE_MAIN, 0);
        return adx / 100.0; // Normalize to 0-1
    }
};#endif // RISK_MANAGEMENT_ENV_MQH
