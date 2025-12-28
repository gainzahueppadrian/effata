//+------------------------------------------------------------------+
//| RL_RiskManagement_Environment.mqh                               |
//| Reinforcement Learning Risk Management Environment              |
//| Implements Kelly Criterion, Neural Position Sizing & Hedging    |
//| Copyright 2025, EFFATA Trading Systems                          |
//+------------------------------------------------------------------+
#property copyright "2025, EFFATA Trading Systems"
#property link      "https://www.effata.ai"
#property version   "3.20"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Math\Stat\Math.mqh>
#include <Math\Stat\Normal.mqh>
#include <Arrays\ArrayObj.mqh>
#include "..\Neural\NeuralMemoryController.mqh"
#include "..\Core\DeepSeekVerification.mqh"

//+------------------------------------------------------------------+
//| ENUMERATIONS                                                     |
//+------------------------------------------------------------------+
enum HEDGING_STRATEGY {
    NO_HEDGING,
    PARTIAL_HEDGING,
    FULL_HEDGING,
    ADAPTIVE_HEDGING
};

enum COMPOUNDING_MODE {
    FIXED_FRACTIONAL,
    KELLY_MODIFIED,
    VOLATILITY_ADJUSTED,
    NEURAL_OPTIMIZED
};

//+------------------------------------------------------------------+
//| STRUCTURES                                                       |
//+------------------------------------------------------------------+
struct RiskProfile {
    double maxRiskPerTrade;
    double maxDailyLoss;
    double maxDrawdown;
    double volatilityAdjustment;
    double sessionMultiplier;
    double newsAdjustment;
    COMPOUNDING_MODE compoundingMode;
    HEDGING_STRATEGY hedgingMode;
};

struct TradeProgression {
    double baseLotSize;
    double lotMultiplier;
    double maxConsecutiveIncreases;
    double winStreakThreshold;
    double drawdownThreshold;
};

struct DynamicTPLevels {
    double[] tpLevels;       // Array of TP levels in points (0.1-9.0)
    double[] volumeRatios;   // Percentage of position to close at each TP
    double dynamicAdjustment; // Factor for dynamic recalculation
    bool useNeuralOptimization;
};

struct HedgingParameters {
    bool enableHedging;
    double hedgeActivationLevel;
    double hedgeRatio;
    double maxHedges;
    double hedgeRecoveryThreshold;
};

struct RiskState {
    double accountBalance;
    double equity;
    double freeMargin;
    double marginLevel;
    double dailyDrawdown;
    double maxDrawdown;
    int consecutiveWins;
    int consecutiveLosses;
    double volatilityIndex;
    datetime lastTradeTime;
    int activePositions;
    double neuralConfidenceScore;
};

//+------------------------------------------------------------------+
//| RL Risk Management Environment Class                             |
//+------------------------------------------------------------------+
class RL_RiskManagementEnvironment {
private:
    CTrade m_trade;
    CPositionInfo m_position;
    CSymbolInfo m_symbol;
    CNeuralMemoryController* m_neuralController;

    RiskProfile m_riskProfile;
    TradeProgression m_tradeProgression;
    DynamicTPLevels m_tpLevels;
    HedgingParameters m_hedgingParams;
    RiskState m_riskState;

    // Neural network weights for position sizing
    double m_positionWeights[10][15];
    double m_tpWeights[8][12];
    double m_hedgeWeights[6][10];

    // Memory buffers
    double m_profitBuffer[50];
    double m_drawdownBuffer[30];
    double m_volatilityBuffer[20];

    int m_profitBufferIndex;
    int m_drawdownBufferIndex;
    int m_volatilityBufferIndex;

    double m_accountStartingBalance;
    double m_peakEquity;
    double m_dailyStartingEquity;
    datetime m_lastResetTime;

public:
    RL_RiskManagementEnvironment() {
        m_neuralController = new CNeuralMemoryController();
        m_accountStartingBalance = AccountInfoDouble(ACCOUNT_BALANCE);
        m_peakEquity = AccountInfoDouble(ACCOUNT_EQUITY);
        m_dailyStartingEquity = AccountInfoDouble(ACCOUNT_EQUITY);
        m_lastResetTime = TimeCurrent();

        // Initialize default risk profile
        InitializeDefaultProfile();

        // Initialize neural weights
        InitializeNeuralWeights();
    }

    ~RL_RiskManagementEnvironment() {
        if(CheckPointer(m_neuralController) == POINTER_DYNAMIC) {
            delete m_neuralController;
        }
    }

    bool Initialize() {
        if(!m_symbol.Name(_Symbol)) {
            Print("Error: Failed to initialize symbol info for ", _Symbol);
            return false;
        }

        if(!m_neuralController.Initialize()) {
            Print("Error: Failed to initialize neural controller");
            return false;
        }

        ResetDailyMetrics();
        UpdateRiskState();

        Print("✅ RL Risk Management Environment initialized");
        Print("📊 Account Balance: $", DoubleToString(m_accountStartingBalance, 2));
        Print("⚙️ Risk Profile: Max Risk ", DoubleToString(m_riskProfile.maxRiskPerTrade*100, 2), "% per trade");

        return true;
    }

    double CalculateOptimalPositionSize(double expectedWinProbability, double riskRewardRatio,
                                        double stopLossPoints, double volatilityIndex) {
        // Update risk state
        UpdateRiskState();

        // Base calculation using Modified Kelly Criterion
        double baseSize = CalculateKellyPositionSize(expectedWinProbability, riskRewardRatio);

        // Apply compounding adjustments
        baseSize = ApplyCompoundingAdjustment(baseSize);

        // Apply progression adjustments
        baseSize = ApplyProgressionAdjustment(baseSize);

        // Apply neural optimization
        if(m_riskProfile.compoundingMode == NEURAL_OPTIMIZED) {
            baseSize = ApplyNeuralPositionSizing(baseSize, expectedWinProbability, riskRewardRatio, volatilityIndex);
        }

        // Apply hedging adjustments
        baseSize = ApplyHedgingAdjustment(baseSize);

        // Apply risk limits
        baseSize = ApplyRiskLimits(baseSize, stopLossPoints);

        return baseSize;
    }

    DynamicTPLevels CalculateDynamicTPLevels(double entryPrice, double stopLossPrice,
                                             double volatilityIndex, double trendStrength) {
        DynamicTPLevels result;
        ArrayResize(result.tpLevels, 5);
        ArrayResize(result.volumeRatios, 5);

        // Base TP levels (0.1-9.0 points range)
        double baseTP[] = {0.5, 1.5, 3.0, 5.0, 9.0};

        // Base volume ratios for partial closures
        double baseRatios[] = {0.2, 0.2, 0.2, 0.2, 0.2};

        // Adjust based on volatility and trend
        double adjustmentFactor = 1.0 + (volatilityIndex * 0.5) + (trendStrength * 0.3);

        for(int i = 0; i < 5; i++) {
            result.tpLevels[i] = baseTP[i] * adjustmentFactor;
            result.volumeRatios[i] = baseRatios[i];

            // Ensure TP levels stay within 0.1-9.0 range
            result.tpLevels[i] = MathMax(0.1, MathMin(9.0, result.tpLevels[i]));
        }

        // Apply neural optimization if enabled
        if(m_tpLevels.useNeuralOptimization) {
            ApplyNeuralTPOptimization(result, entryPrice, stopLossPrice, volatilityIndex, trendStrength);
        }

        // Dynamic recalculation factor
        result.dynamicAdjustment = CalculateDynamicAdjustmentFactor(volatilityIndex, trendStrength);

        return result;
    }

    bool ShouldActivateHedge(double currentDrawdown, double positionProfit, double volatilityIndex) {
        if(!m_hedgingParams.enableHedging) return false;

        // Calculate hedge activation score
        double activationScore = 0.0;

        // Drawdown component
        if(currentDrawdown > m_hedgingParams.hedgeActivationLevel) {
            activationScore += (currentDrawdown - m_hedgingParams.hedgeActivationLevel) * 2.0;
        }

        // Position profit component (if losing)
        if(positionProfit < 0) {
            activationScore += MathAbs(positionProfit) * 0.1;
        }

        // Volatility component
        if(volatilityIndex > 1.5) {
            activationScore += (volatilityIndex - 1.5) * 0.8;
        }

        // Neural confidence component
        if(m_riskState.neuralConfidenceScore < 0.3) {
            activationScore += (0.3 - m_riskState.neuralConfidenceScore) * 1.5;
        }

        // Activation threshold
        return activationScore > 1.0;
    }

    double CalculateHedgeRatio(double activationScore) {
        double baseRatio = m_hedgingParams.hedgeRatio;

        // Scale ratio based on activation score
        double scaledRatio = baseRatio * (1.0 + (activationScore - 1.0) * 0.5);

        // Limit to maximum allowed
        return MathMin(m_hedgingParams.maxHedges, scaledRatio);
    }

    void UpdateWithTradeResult(bool isProfitable, double pnl, double riskScore) {
        // Update consecutive win/loss streaks
        if(isProfitable) {
            m_riskState.consecutiveWins++;
            m_riskState.consecutiveLosses = 0;
        } else {
            m_riskState.consecutiveLosses++;
            m_riskState.consecutiveWins = 0;
        }

        // Update drawdown buffer
        UpdateDrawdownBuffer(pnl);

        // Update neural memory with trade result
        m_neuralController.UpdateFromTrade(isProfitable, pnl, riskScore);

        // Adjust risk profile based on performance
        AdjustRiskProfileBasedOnPerformance();

        // Recalculate neural weights periodically
        if((m_riskState.consecutiveWins + m_riskState.consecutiveLosses) % 10 == 0) {
            RecalculateNeuralWeights();
        }
    }

    RiskAssessment GetRiskAssessment() {
        RiskAssessment assessment;
        assessment.allowTrading = true;
        assessment.reason = "All risk parameters within limits";
        assessment.riskScore = 0.0;
        assessment.recommendedPositionSize = 0.0;

        UpdateRiskState();

        // Check daily drawdown limit (0.19% as per requirements)
        if(m_riskState.dailyDrawdown > m_riskProfile.maxDailyLoss) {
            assessment.allowTrading = false;
            assessment.reason = "Daily drawdown limit exceeded: " +
                               DoubleToString(m_riskState.dailyDrawdown*100, 2) + "% > " +
                               DoubleToString(m_riskProfile.maxDailyLoss*100, 2) + "%";
            assessment.riskScore = 0.9;
            return assessment;
        }

        // Check equity drawdown
        if(m_riskState.maxDrawdown > m_riskProfile.maxDrawdown) {
            assessment.allowTrading = false;
            assessment.reason = "Maximum equity drawdown reached: " +
                               DoubleToString(m_riskState.maxDrawdown*100, 2) + "%";
            assessment.riskScore = 0.85;
            return assessment;
        }

        // Check margin level
        if(m_riskState.marginLevel < 150.0) {
            assessment.allowTrading = false;
            assessment.reason = "Low margin level: " + DoubleToString(m_riskState.marginLevel, 1) + "%";
            assessment.riskScore = 0.8;
            return assessment;
        }

        // Check loss streak
        if(m_riskState.consecutiveLosses >= 3) {
            assessment.allowTrading = false;
            assessment.reason = "Loss streak detected: " + IntegerToString(m_riskState.consecutiveLosses) + " consecutive losses";
            assessment.riskScore = 0.7;
        }

        // Calculate overall risk score
        assessment.riskScore = CalculateComprehensiveRiskScore();

        // If risk score is too high, restrict trading
        if(assessment.riskScore > 0.6) {
            assessment.allowTrading = false;
            if(assessment.reason == "All risk parameters within limits") {
                assessment.reason = "Overall risk score too high: " + DoubleToString(assessment.riskScore, 2);
            }
        }

        // Calculate recommended position size
        assessment.recommendedPositionSize = CalculateRecommendedPositionSize();

        return assessment;
    }

    void ResetDailyMetrics() {
        MqlDateTime currentTime;
        TimeCurrent(currentTime);
        MqlDateTime lastResetTimeStruct;
        TimeToStruct(m_lastResetTime, lastResetTimeStruct);

        if(currentTime.day != lastResetTimeStruct.day) {
            m_dailyStartingEquity = AccountInfoDouble(ACCOUNT_EQUITY);
            m_riskState.consecutiveWins = 0;
            m_riskState.consecutiveLosses = 0;
            m_lastResetTime = TimeCurrent();

            Print("🔄 Daily risk metrics reset");
        }
    }

private:
    void InitializeDefaultProfile() {
        // Risk profile based on Kelly Criterion principles
        m_riskProfile.maxRiskPerTrade = 0.01;    // 1% risk per trade
        m_riskProfile.maxDailyLoss = 0.0019;     // 0.19% daily drawdown limit
        m_riskProfile.maxDrawdown = 0.10;        // 10% maximum drawdown
        m_riskProfile.volatilityAdjustment = 1.0;
        m_riskProfile.sessionMultiplier = 1.0;
        m_riskProfile.newsAdjustment = 1.0;
        m_riskProfile.compoundingMode = NEURAL_OPTIMIZED;
        m_riskProfile.hedgingMode = ADAPTIVE_HEDGING;

        // Trade progression settings
        m_tradeProgression.baseLotSize = 0.01;
        m_tradeProgression.lotMultiplier = 1.25;
        m_tradeProgression.maxConsecutiveIncreases = 3;
        m_tradeProgression.winStreakThreshold = 2;
        m_tradeProgression.drawdownThreshold = 0.02; // 2%

        // TP levels configuration
        ArrayResize(m_tpLevels.tpLevels, 5);
        ArrayResize(m_tpLevels.volumeRatios, 5);
        m_tpLevels.tpLevels[0] = 0.5;  m_tpLevels.volumeRatios[0] = 0.2;
        m_tpLevels.tpLevels[1] = 1.5;  m_tpLevels.volumeRatios[1] = 0.2;
        m_tpLevels.tpLevels[2] = 3.0;  m_tpLevels.volumeRatios[2] = 0.2;
        m_tpLevels.tpLevels[3] = 5.0;  m_tpLevels.volumeRatios[3] = 0.2;
        m_tpLevels.tpLevels[4] = 9.0;  m_tpLevels.volumeRatios[4] = 0.2;
        m_tpLevels.dynamicAdjustment = 1.0;
        m_tpLevels.useNeuralOptimization = true;

        // Hedging parameters
        m_hedgingParams.enableHedging = true;
        m_hedgingParams.hedgeActivationLevel = 0.015; // 1.5% drawdown
        m_hedgingParams.hedgeRatio = 0.5;    // 50% hedge
        m_hedgingParams.maxHedges = 2.0;     // Maximum 2x exposure
        m_hedgingParams.hedgeRecoveryThreshold = 0.005; // 0.5% recovery
    }

    void InitializeNeuralWeights() {
        MathSrand((int)GetMicrosecondCount());

        // Initialize position sizing weights
        for(int i = 0; i < 10; i++) {
            for(int j = 0; j < 15; j++) {
                m_positionWeights[i][j] = (MathRand() / 32767.0 - 0.5) * 0.1;
            }
        }

        // Initialize TP optimization weights
        for(int i = 0; i < 8; i++) {
            for(int j = 0; j < 12; j++) {
                m_tpWeights[i][j] = (MathRand() / 32767.0 - 0.5) * 0.1;
            }
        }

        // Initialize hedging weights
        for(int i = 0; i < 6; i++) {
            for(int j = 0; j < 10; j++) {
                m_hedgeWeights[i][j] = (MathRand() / 32767.0 - 0.5) * 0.1;
            }
        }
    }

    double CalculateKellyPositionSize(double winProbability, double riskRewardRatio) {
        if(winProbability <= 0 || riskRewardRatio <= 0) return m_tradeProgression.baseLotSize;

        // Modified Kelly Criterion with safety fraction
        double kellyFraction = winProbability - ((1 - winProbability) / riskRewardRatio);

        // Safety factor (typically 0.5 of Kelly)
        double safetyFraction = 0.5;
        kellyFraction *= safetyFraction;

        // Ensure positive and reasonable values
        kellyFraction = MathMax(0.005, MathMin(0.05, kellyFraction)); // 0.5% to 5% of account

        // Calculate position size based on account equity
        double equity = AccountInfoDouble(ACCOUNT_EQUITY);
        double baseRiskAmount = equity * kellyFraction;

        // Calculate lot size based on risk amount and stop loss
        double tickValue = m_symbol.TickValue();
        double tickSize = m_symbol.TickSize();
        double point = m_symbol.Point();

        // For forex, 1 pip = 10 points typically
        double pipValue = (tickValue / tickSize) * point * 10;

        // Default to 10 pips stop loss if not provided
        double defaultStopLossPips = 10.0;
        double riskPerLot = defaultStopLossPips * pipValue;

        if(riskPerLot > 0) {
            double lotSize = baseRiskAmount / riskPerLot;
            return lotSize;
        }

        return m_tradeProgression.baseLotSize;
    }

    double ApplyCompoundingAdjustment(double baseSize) {
        double equity = AccountInfoDouble(ACCOUNT_EQUITY);
        double growthFactor = equity / m_accountStartingBalance;

        // Apply compounding based on mode
        switch(m_riskProfile.compoundingMode) {
            case FIXED_FRACTIONAL:
                return baseSize * growthFactor;

            case KELLY_MODIFIED:
                // Modified Kelly with growth adjustment
                return baseSize * MathPow(growthFactor, 0.75);

            case VOLATILITY_ADJUSTED:
                // Adjust based on current volatility
                double volatilityFactor = 1.0 / (1.0 + m_riskState.volatilityIndex);
                return baseSize * growthFactor * volatilityFactor;

            case NEURAL_OPTIMIZED:
            default:
                // Neural optimization will be applied separately
                return baseSize * MathMin(MathPow(growthFactor, 0.8), 3.0); // Cap at 3x growth
        }
    }

    double ApplyProgressionAdjustment(double baseSize) {
        if(m_riskState.consecutiveWins >= m_tradeProgression.winStreakThreshold &&
           m_riskState.consecutiveLosses == 0) {
            // Increase lot size based on win streak
            double multiplier = MathPow(m_tradeProgression.lotMultiplier,
                                      MathMin(m_riskState.consecutiveWins - m_tradeProgression.winStreakThreshold + 1,
                                             m_tradeProgression.maxConsecutiveIncreases));
            return baseSize * multiplier;
        }

        if(m_riskState.consecutiveLosses > 0) {
            // Reduce lot size after losses
            double reductionFactor = MathPow(0.8, m_riskState.consecutiveLosses);
            return baseSize * reductionFactor;
        }

        return baseSize;
    }

    double ApplyNeuralPositionSizing(double baseSize, double winProbability,
                                   double riskRewardRatio, double volatilityIndex) {
        // Create input features for neural network
        double inputs[15];
        ArrayInitialize(inputs, 0.0);

        inputs[0] = baseSize;
        inputs[1] = winProbability;
        inputs[2] = riskRewardRatio;
        inputs[3] = volatilityIndex;
        inputs[4] = m_riskState.dailyDrawdown;
        inputs[5] = m_riskState.maxDrawdown;
        inputs[6] = (double)m_riskState.consecutiveWins;
        inputs[7] = (double)m_riskState.consecutiveLosses;
        inputs[8] = m_riskState.marginLevel / 1000.0; // Normalize
        inputs[9] = m_accountStartingBalance / 10000.0; // Normalize
        inputs[10] = m_riskState.equity / m_accountStartingBalance;
        inputs[11] = m_riskProfile.maxRiskPerTrade;
        inputs[12] = m_riskState.volatilityIndex;
        inputs[13] = (double)m_riskState.activePositions;
        inputs[14] = m_riskState.neuralConfidenceScore;

        // Hidden layer calculation
        double hidden[10];
        ArrayInitialize(hidden, 0.0);

        for(int i = 0; i < 10; i++) {
            double sum = 0.0;
            for(int j = 0; j < 15; j++) {
                sum += inputs[j] * m_positionWeights[i][j];
            }
            hidden[i] = MathTanh(sum); // Activation function
        }

        // Output layer - adjustment factor
        double adjustmentFactor = 0.0;
        for(int i = 0; i < 10; i++) {
            adjustmentFactor += hidden[i] * (MathRand() / 32767.0 - 0.5) * 0.2;
        }

        // Normalize adjustment factor between 0.5 and 2.0
        adjustmentFactor = 1.0 + MathMax(-0.5, MathMin(1.0, adjustmentFactor));

        // Update neural confidence score
        m_riskState.neuralConfidenceScore = 1.0 - MathAbs(adjustmentFactor - 1.0);

        return baseSize * adjustmentFactor;
    }

    void ApplyNeuralTPOptimization(DynamicTPLevels &tpLevels, double entryPrice,
                                 double stopLossPrice, double volatilityIndex, double trendStrength) {
        // This would use neural network to optimize TP levels
        // For brevity, implementing a simplified version

        // Adjust TP levels based on market conditions
        for(int i = 0; i < ArraySize(tpLevels.tpLevels); i++) {
            // Increase TP levels in strong trending markets
            if(MathAbs(trendStrength) > 0.7) {
                tpLevels.tpLevels[i] *= 1.2;
            }

            // Reduce TP levels in high volatility
            if(volatilityIndex > 2.0) {
                tpLevels.tpLevels[i] *= 0.8;
            }

            // Ensure values stay within 0.1-9.0 range
            tpLevels.tpLevels[i] = MathMax(0.1, MathMin(9.0, tpLevels.tpLevels[i]));
        }

        // Adjust volume ratios based on confidence
        if(m_riskState.neuralConfidenceScore > 0.7) {
            // Take more profit early if high confidence
            tpLevels.volumeRatios[0] = 0.4;
            tpLevels.volumeRatios[1] = 0.3;
            tpLevels.volumeRatios[2] = 0.2;
            tpLevels.volumeRatios[3] = 0.1;
            tpLevels.volumeRatios[4] = 0.0;
        } else if(m_riskState.neuralConfidenceScore < 0.3) {
            // Take less profit early if low confidence
            tpLevels.volumeRatios[0] = 0.1;
            tpLevels.volumeRatios[1] = 0.1;
            tpLevels.volumeRatios[2] = 0.2;
            tpLevels.volumeRatios[3] = 0.3;
            tpLevels.volumeRatios[4] = 0.3;
        }
    }

    double CalculateDynamicAdjustmentFactor(double volatilityIndex, double trendStrength) {
        // Calculate factor for dynamic TP recalculation
        double factor = 1.0;

        // Increase factor in trending markets
        factor += MathAbs(trendStrength) * 0.3;

        // Adjust based on volatility
        if(volatilityIndex > 1.5) {
            factor *= 0.9; // Reduce targets in high volatility
        } else if(volatilityIndex < 0.5) {
            factor *= 1.1; // Increase targets in low volatility
        }

        return factor;
    }

    double ApplyHedgingAdjustment(double baseSize) {
        if(!m_hedgingParams.enableHedging) return baseSize;

        // Reduce position size if hedging is active or likely to be activated
        if(m_riskState.consecutiveLosses > 0 || m_riskState.dailyDrawdown > m_hedgingParams.hedgeActivationLevel * 0.5) {
            double reductionFactor = 0.8 - (m_riskState.consecutiveLosses * 0.1);
            return baseSize * MathMax(0.5, reductionFactor);
        }

        return baseSize;
    }

    double ApplyRiskLimits(double baseSize, double stopLossPoints) {
        // Get symbol limits
        double minLot = m_symbol.LotsMin();
        double maxLot = m_symbol.LotsMax();
        double lotStep = m_symbol.LotsStep();

        // Risk-based limit (0.19% daily drawdown constraint)
        double maxRiskAmount = m_riskState.equity * m_riskProfile.maxDailyLoss;
        double riskPerLot = stopLossPoints * m_symbol.Point() * 100000; // Approximate for forex

        if(riskPerLot > 0) {
            double maxRiskLots = maxRiskAmount / riskPerLot;
            baseSize = MathMin(baseSize, maxRiskLots);
        }

        // Margin-based limit
        double marginPerLot = m_symbol.MarginInitial() * m_symbol.Leverage();
        if(marginPerLot > 0) {
            double maxMarginLots = m_riskState.freeMargin / marginPerLot;
            baseSize = MathMin(baseSize, maxMarginLots * 0.5); // Use only 50% of available margin
        }

        // Apply limits
        baseSize = MathMax(minLot, MathMin(maxLot, baseSize));

        // Round to lot step
        baseSize = MathRound(baseSize / lotStep) * lotStep;

        return baseSize;
    }

    double CalculateRecommendedPositionSize() {
        // Calculate based on current equity and risk parameters
        double equity = m_riskState.equity;
        double riskAmount = equity * m_riskProfile.maxRiskPerTrade;

        // Assume 10 pips stop loss for calculation
        double stopLossPips = 10.0;
        double tickValue = m_symbol.TickValue();
        double tickSize = m_symbol.TickSize();
        double point = m_symbol.Point();

        double pipValue = (tickValue / tickSize) * point * 10;
        double riskPerLot = stopLossPips * pipValue;

        if(riskPerLot > 0) {
            double lotSize = riskAmount / riskPerLot;
            double minLot = m_symbol.LotsMin();
            double maxLot = m_symbol.LotsMax();

            return MathMax(minLot, MathMin(maxLot, lotSize));
        }

        return m_symbol.LotsMin();
    }

    double CalculateComprehensiveRiskScore() {
        double score = 0.0;

        // Daily drawdown component (0.19% max)
        double dailyDrawdownScore = m_riskState.dailyDrawdown / m_riskProfile.maxDailyLoss;
        score += dailyDrawdownScore * 0.3;

        // Equity drawdown component
        double equityDrawdownScore = m_riskState.maxDrawdown / m_riskProfile.maxDrawdown;
        score += equityDrawdownScore * 0.25;

        // Consecutive losses component
        double lossStreakScore = MathMin(1.0, m_riskState.consecutiveLosses / 5.0);
        score += lossStreakScore * 0.2;

        // Volatility component
        double volatilityScore = MathMin(1.0, m_riskState.volatilityIndex / 3.0);
        score += volatilityScore * 0.15;

        // Margin level component
        double marginScore = MathMax(0.0, 1.0 - (m_riskState.marginLevel / 300.0));
        score += marginScore * 0.1;

        // Normalize to 0-1 range
        return MathMin(1.0, score);
    }

    void UpdateRiskState() {
        m_riskState.accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
        m_riskState.equity = AccountInfoDouble(ACCOUNT_EQUITY);
        m_riskState.freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
        m_riskState.marginLevel = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);

        // Update peak equity
        if(m_riskState.equity > m_peakEquity) {
            m_peakEquity = m_riskState.equity;
        }

        // Calculate drawdowns
        m_riskState.maxDrawdown = (m_peakEquity - m_riskState.equity) / m_peakEquity;
        m_riskState.dailyDrawdown = (m_dailyStartingEquity - m_riskState.equity) / m_dailyStartingEquity;

        // Count active positions
        m_riskState.activePositions = 0;
        for(int i = PositionsTotal()-1; i >= 0; i--) {
            ulong ticket = PositionGetTicket(i);
            if(ticket > 0 && PositionGetString(POSITION_SYMBOL) == _Symbol) {
                m_riskState.activePositions++;
            }
        }

        // Calculate volatility index (simplified)
        m_riskState.volatilityIndex = CalculateVolatilityIndex();

        // Update neural confidence score
        m_riskState.neuralConfidenceScore = m_neuralController.GetConfidenceScore();
    }

    double CalculateVolatilityIndex() {
        // Calculate based on ATR and recent price movements
        double atr = iATR(_Symbol, PERIOD_H1, 14, 1);
        double averageTrueRange = iATR(_Symbol, PERIOD_D1, 14, 1);

        if(averageTrueRange > 0) {
            return atr / averageTrueRange;
        }

        return 1.0;
    }

    void UpdateDrawdownBuffer(double pnl) {
        m_drawdownBuffer[m_drawdownBufferIndex] = pnl;
        m_drawdownBufferIndex = (m_drawdownBufferIndex + 1) % ArraySize(m_drawdownBuffer);
    }

    void AdjustRiskProfileBasedOnPerformance() {
        // Adjust risk parameters based on performance
        if(m_riskState.consecutiveWins >= 3 && m_riskState.maxDrawdown < 0.05) {
            // Slightly increase risk after good performance
            m_riskProfile.maxRiskPerTrade = MathMin(0.015, m_riskProfile.maxRiskPerTrade * 1.1);
        }

        if(m_riskState.consecutiveLosses >= 2 || m_riskState.maxDrawdown > 0.07) {
            // Reduce risk after poor performance
            m_riskProfile.maxRiskPerTrade = MathMax(0.005, m_riskProfile.maxRiskPerTrade * 0.8);
            m_riskProfile.maxDailyLoss = MathMax(0.001, m_riskProfile.maxDailyLoss * 0.9);
        }

        // Adjust volatility adjustment
        if(m_riskState.volatilityIndex > 2.0) {
            m_riskProfile.volatilityAdjustment = 0.7;
        } else if(m_riskState.volatilityIndex < 0.7) {
            m_riskProfile.volatilityAdjustment = 1.3;
        } else {
            m_riskProfile.volatilityAdjustment = 1.0;
        }
    }

    void RecalculateNeuralWeights() {
        // This would implement backpropagation or other weight update algorithms
        // For production, this would be more sophisticated

        MathSrand((int)GetMicrosecondCount() + (int)m_riskState.consecutiveWins);

        // Random weight adjustment based on performance
        double adjustmentFactor = (m_riskState.consecutiveWins > m_riskState.consecutiveLosses) ? 1.1 : 0.9;

        for(int i = 0; i < 10; i++) {
            for(int j = 0; j < 15; j++) {
                m_positionWeights[i][j] *= adjustmentFactor;
                // Add small random noise for exploration
                m_positionWeights[i][j] += (MathRand() / 32767.0 - 0.5) * 0.01;
                // Clip weights to prevent explosion
                m_positionWeights[i][j] = MathMax(-1.0, MathMin(1.0, m_positionWeights[i][j]));
            }
        }
    }
};

//+------------------------------------------------------------------+
//| Risk Assessment Structure (for compatibility)                    |
//+------------------------------------------------------------------+
struct RiskAssessment {
    bool allowTrading;
    string reason;
    double riskScore;
    double recommendedPositionSize;
};