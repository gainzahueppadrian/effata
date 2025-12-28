#ifndef RISK_MANAGEMENT_ENV_MQH
#define RISK_MANAGEMENT_ENV_MQH

#include "MonteCarloEnv.mqh"
#include "../Core/Structures.mqh"
#include "../Core/CompatMQL4.mqh"
#include "../Calendar/EconomicCalendar.mqh"
#include "StatisticsEnv.mqh"

class CRiskManagementEnv {
private:
    CMonteCarloRiskEnvironment *m_monteCarloEnv;
    CEconomicCalendar *m_calendar;
    double m_riskPerTradePercent;
    bool m_enableAdaptiveRisk;
    double m_initialEquity;

    // Internal state for tick updates
    double m_runningDrawdown;
    double m_peakEquity;

    // Reference to statistics for adaptive risk
    CStatisticsEnv *m_statsEnv;

public:
    CRiskManagementEnv(double riskPerTrade = 0.005, bool enableAdaptive = true) {
        m_riskPerTradePercent = riskPerTrade;
        m_enableAdaptiveRisk = enableAdaptive;
        m_monteCarloEnv = new CMonteCarloRiskEnvironment();
        m_calendar = new CEconomicCalendar();
        m_initialEquity = 0;
        m_runningDrawdown = 0;
        m_peakEquity = 0;
        m_statsEnv = NULL;
    }

    ~CRiskManagementEnv() {
        if(CheckPointer(m_monteCarloEnv) == POINTER_DYNAMIC) delete m_monteCarloEnv;
        if(CheckPointer(m_calendar) == POINTER_DYNAMIC) delete m_calendar;
    }

    void SetStatisticsEnv(CStatisticsEnv *stats) {
        m_statsEnv = stats;
    }

    bool Initialize() {
        m_initialEquity = AccountInfoDouble(ACCOUNT_EQUITY);
        m_peakEquity = m_initialEquity;
        m_calendar->UpdateCalendar(); // Initial fetch
        return m_monteCarloEnv->Initialize();
    }

    RiskAssessment AssessCurrentRisk() {
        RiskAssessment r = m_monteCarloEnv->GetRiskAssessment();

        // Incorporate statistical analysis if available
        if(m_statsEnv != NULL) {
            StatisticalAnalysis stats = m_statsEnv->GetStatisticalAnalysis();
            if(stats.isValid) {
               if(stats.recommendation == "SYSTEM_FAILING") {
                   r.allowTrading = false;
                   r.reason = "Statistical Breakdown (T-Test)";
                   r.riskScore = 1.0;
               } else if(stats.recommendation == "POSITIVE_BUT_UNCERTAIN") {
                   r.riskScore += 0.1; // Slight penalty for uncertainty
               }
            }

            PerformanceMetrics metrics = m_statsEnv->GetMetrics();
            if(metrics.maxDrawdown > 500.0) { // Arbitrary monetary threshold, better to use %
                r.riskScore += 0.2;
            }
        }

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

        // Adjust for statistical robustness
        if(m_statsEnv != NULL) {
            StatisticalAnalysis stats = m_statsEnv->GetStatisticalAnalysis();
            if(stats.isValid && stats.confidence < 0.90) {
                size *= 0.5; // Reduce size if low confidence in system expectancy
            }
        }

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
        // Track intra-tick drawdown
        double equity = AccountInfoDouble(ACCOUNT_EQUITY);
        if(equity > m_peakEquity) m_peakEquity = equity;

        double drawdown = 0.0;
        if(m_peakEquity > 0) drawdown = (m_peakEquity - equity) / m_peakEquity;
        m_runningDrawdown = drawdown;

        // Check for sudden liquidity gaps using features (spread/volatility)
        // features[6] is ATR, features[8] is volatility
    }

    void SelfVerify(const double &features[]) {
        // Check if internal states match expected reality
        double equity = AccountInfoDouble(ACCOUNT_EQUITY);
        if(equity < m_initialEquity * 0.5) {
            Print("CRITICAL: Equity mismatch or catastrophic loss detected in verification.");
        }
    }

    void ConsolidateMemory() {
        // Log risk metrics to file or long-term storage
        // For now, we just simulate cleanup
    }

    void LearnFromTrade(double reward, const MarketContext &context) {
        // Reinforce risk parameters. If reward is negative (loss), tighten risk.
        // If positive, maybe relax slightly or maintain.
        // This logic is partially handled in UpdateFromTrade via MonteCarloEnv
        UpdateFromTrade(reward, 1.0); // Assuming 1.0 risk unit
    }

    void OnSessionChange(const MarketContext &context) {
        // Adjust base risk per trade based on session liquidity
        if(context.sessionType == "ASIA") {
            m_riskPerTradePercent *= 0.8; // Lower risk in Asia
        } else if(context.sessionType == "LONDON" || context.sessionType == "NEW_YORK") {
            m_riskPerTradePercent = 0.005; // Reset to standard
        }
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
