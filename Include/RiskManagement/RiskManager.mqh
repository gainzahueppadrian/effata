//+------------------------------------------------------------------+
//| RiskManager.mqh                                                |
//| Advanced Risk Management System                                  |
//| Copyright 2025, Reinforcement Learning Trading Systems          |
//+------------------------------------------------------------------+
#property copyright "2025, RL Trading Systems"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include <Math/Stat/Math.mqh>
#include <Math/Stat/Normal.mqh>
#include <Math/SpecialFunctions.mqh>
#include "..\Statistics\StatisticalFunctions.mqh"

//+------------------------------------------------------------------+
//| Risk Assessment Structure                                        |
//+------------------------------------------------------------------+
struct RiskAssessment {
    bool allowTrading;
    string reason;
    double riskScore;
    double recommendedPositionSize;
};

//+------------------------------------------------------------------+
//| Risk Parameters Structure                                        |
//+------------------------------------------------------------------+
struct RiskParameters {
    double expectedValue;      // Valor esperado de la operación
    double riskPerTrade;       // Riesgo por operación (%)
    double maxDrawdown;        // Drawdown máximo permitido (%)
    double accountBalance;     // Balance actual de la cuenta
    double volatilityFactor;   // Factor de volatilidad
};

//+------------------------------------------------------------------+
//| SL and TP Levels Structure                                       |
//+------------------------------------------------------------------+
struct SLTPLevels {
    double sl;                 // Nivel de stop loss
    double tp;                 // Nivel de take profit
};

//+------------------------------------------------------------------+
//| Risk Manager Class                                               |
//+------------------------------------------------------------------+
class RiskManager {
private:
    double maxDailyDrawdown;
    double riskPerTrade;
    double minRiskRewardRatio;
    bool dynamicLeverageAdjust;
    double leverageReductionFactor;
    double currentLeverage;
    double maxLeverage;
    double minLeverage;
    datetime lastTradeTime;
    int winStreak;
    int lossStreak;
    double dailyProfit;
    double startingBalance;
    double maxEquityToday;

public:
    RiskManager() {
        maxDailyDrawdown = 2.0;
        riskPerTrade = 1.0;
        minRiskRewardRatio = 2.0;
        dynamicLeverageAdjust = true;
        leverageReductionFactor = 0.8;
        currentLeverage = 100.0; // Valor por defecto
        maxLeverage = 200.0;
        minLeverage = 10.0;
        lastTradeTime = 0;
        winStreak = 0;
        lossStreak = 0;
        dailyProfit = 0.0;
        startingBalance = 0.0;
        maxEquityToday = 0.0;
    }

    void Configure(double maxDD, double riskPerTrade, double minRR, bool dynamicLeverage, double leverageReduction) {
        maxDailyDrawdown = maxDD;
        this.riskPerTrade = riskPerTrade;
        minRiskRewardRatio = minRR;
        dynamicLeverageAdjust = dynamicLeverage;
        leverageReductionFactor = leverageReduction;

        // Inicializar balance inicial
        startingBalance = AccountInfoDouble(ACCOUNT_BALANCE);
        maxEquityToday = AccountInfoDouble(ACCOUNT_EQUITY);

        // Obtener apalancamiento máximo permitido
        maxLeverage = AccountInfoInteger(ACCOUNT_LEVERAGE);
        currentLeverage = MathMin(maxLeverage, 100.0); // Empezar con 100:1 o el máximo permitido
    }

    RiskAssessment AssessCurrentRisk() {
        RiskAssessment assessment = {true, "", 0.0, 0.0};

        // Actualizar métricas diarias
        UpdateDailyMetrics();

        // Verificar drawdown diario
        double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
        double dailyDrawdown = (maxEquityToday - currentEquity) / maxEquityToday * 100.0;

        if(dailyDrawdown >= maxDailyDrawdown) {
            assessment.allowTrading = false;
            assessment.reason = "Daily drawdown limit reached: " + DoubleToString(dailyDrawdown, 2) + "%";
            assessment.riskScore = 1.0;
            return assessment;
        }

        // Verificar margen disponible
        double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
        double marginLevel = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);

        if(freeMargin < AccountInfoDouble(ACCOUNT_BALANCE) * 0.1) {
            assessment.allowTrading = false;
            assessment.reason = "Insufficient free margin";
            assessment.riskScore = 0.8;
            return assessment;
        }

        if(marginLevel < 150) { // Menor a 150% de nivel de margen
            assessment.allowTrading = false;
            assessment.reason = "Low margin level: " + DoubleToString(marginLevel, 0) + "%";
            assessment.riskScore = 0.7;
            return assessment;
        }

        // Verificar racha de pérdidas
        if(lossStreak >= 3) {
            assessment.allowTrading = false;
            assessment.reason = "Loss streak detected: " + IntegerToString(lossStreak) + " consecutive losses";
            assessment.riskScore = 0.6;
            return assessment;
        }

        // Verificar volatilidad extrema
        double currentATR = iATR(_Symbol, PERIOD_H1, 14, 1);
        double averageATR = iATR(_Symbol, PERIOD_D1, 14, 1);

        if(currentATR > averageATR * 2.0) {
            assessment.allowTrading = false;
            assessment.reason = "Extreme volatility detected";
            assessment.riskScore = 0.5;
            return assessment;
        }

        // Ajustar apalancamiento dinámicamente
        AdjustLeverageBasedOnPerformance();

        // Calcular puntuación de riesgo general
        assessment.riskScore = CalculateOverallRiskScore(dailyDrawdown, marginLevel, lossStreak, currentATR/averageATR);
        assessment.allowTrading = (assessment.riskScore < 0.7); // Umbral de riesgo

        if(!assessment.allowTrading && assessment.reason == "") {
            assessment.reason = "Overall risk score too high: " + DoubleToString(assessment.riskScore, 2);
        }

        return assessment;
    }

    double CalculateOptimalPositionSize(RiskParameters params) {
        if(params.accountBalance <= 0) {
            params.accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
        }

        // Calcular tamaño de posición usando Kelly Criterion ajustado
        double kellyFraction = CalculateKellyFraction(params.expectedValue, params.minRiskRewardRatio);

        // Ajustar por drawdown máximo
        double drawdownAdjustment = 1.0 - (AccountInfoDouble(ACCOUNT_EQUITY) / params.accountBalance - 1.0) / (maxDailyDrawdown / 100.0);
        drawdownAdjustment = MathMax(0.5, MathMin(1.0, drawdownAdjustment));

        // Ajustar por volatilidad
        double volatilityAdjustment = 1.0;
        if(params.volatilityFactor > 0) {
            volatilityAdjustment = 1.0 / params.volatilityFactor;
        }

        // Calcular tamaño de posición
        double riskAmount = params.accountBalance * (params.riskPerTrade / 100.0) * drawdownAdjustment * volatilityAdjustment;
        double positionSize = riskAmount / (100.0 * params.minRiskRewardRatio); // Asumiendo 100 USD por lote por pip

        // Ajustar por apalancamiento actual
        double leverageFactor = currentLeverage / maxLeverage;
        positionSize *= leverageFactor;

        // Limitar al tamaño mínimo y máximo permitido
        double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
        double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);

        positionSize = MathMax(minLot, MathMin(maxLot, positionSize));

        return NormalizeDouble(positionSize, 2);
    }

    void AdjustForVolatility(double factor) {
        if(dynamicLeverageAdjust) {
            currentLeverage = MathMax(minLeverage, currentLeverage / factor);
        }

        // Reducir riesgo por operación
        riskPerTrade = MathMax(0.1, riskPerTrade / factor);
    }

    void AdjustParametersForMarketState(string marketState) {
        if(marketState == "HIGH_VOLATILITY" || marketState == "EXTREME_VOLATILITY") {
            riskPerTrade *= 0.7;
            minRiskRewardRatio = MathMax(minRiskRewardRatio, 3.0);
            currentLeverage = MathMax(minLeverage, currentLeverage * 0.8);
        }
        else if(marketState == "LOW_LIQUIDITY") {
            riskPerTrade *= 0.5;
            currentLeverage = MathMax(minLeverage, currentLeverage * 0.6);
        }
        else if(marketState == "NORMAL") {
            // Restaurar valores por defecto
            riskPerTrade = 1.0;
            minRiskRewardRatio = 2.0;
            currentLeverage = MathMin(maxLeverage, 100.0);
        }
    }

    void UpdateAfterTrade(double profit) {
        if(profit > 0) {
            winStreak++;
            lossStreak = 0;
            dailyProfit += profit;
        } else {
            lossStreak++;
            winStreak = 0;
            dailyProfit += profit;
        }

        lastTradeTime = TimeCurrent();

        // Ajustar apalancamiento basado en rendimiento
        AdjustLeverageBasedOnPerformance();
    }

    void ManagePartialProfits(ulong ticket, double profit) {
        // Lógica para gestión de beneficios parciales
        double positionVolume = PositionGetDouble(POSITION_VOLUME);
        double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        double currentPrice = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ?
                             SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        double sl = PositionGetDouble(POSITION_SL);
        double tp = PositionGetDouble(POSITION_TP);

        double risk = MathAbs(entryPrice - sl);
        double reward = MathAbs(currentPrice - entryPrice);
        double rrRatio = reward / risk;

        // Cerrar 50% de la posición cuando RR >= 1.0
        if(rrRatio >= 1.0 && positionVolume > SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN)) {
            double partialVolume = positionVolume * 0.5;
            if(partialVolume >= SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN)) {
                // Mover SL al punto de entrada (breakeven)
                double newSL = entryPrice;

                // Cerrar parcialmente la posición
                CTrade trade;
                trade.PositionClosePartial(ticket, partialVolume);

                // Mover SL al breakeven
                if(PositionSelectByTicket(ticket)) {
                    trade.PositionModify(ticket, newSL, tp);
                }
            }
        }

        // Cerrar 25% adicional cuando RR >= 2.0
        if(rrRatio >= 2.0 && positionVolume > SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN)) {
            double partialVolume = positionVolume * 0.25;
            if(partialVolume >= SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN)) {
                CTrade trade;
                trade.PositionClosePartial(ticket, partialVolume);
            }
        }
    }

private:
    void UpdateDailyMetrics() {
        MqlDateTime currentTime;
        TimeCurrent(currentTime);

        MqlDateTime lastTradeTimeStruct;
        TimeToStruct(lastTradeTime, lastTradeTimeStruct);

        // Reiniciar métricas diarias si es un nuevo día
        if(currentTime.day != lastTradeTimeStruct.day || startingBalance == 0) {
            startingBalance = AccountInfoDouble(ACCOUNT_BALANCE);
            dailyProfit = 0.0;
            winStreak = 0;
            lossStreak = 0;
        }

        // Actualizar equity máximo del día
        double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
        if(currentEquity > maxEquityToday || maxEquityToday == 0) {
            maxEquityToday = currentEquity;
        }
    }

    void AdjustLeverageBasedOnPerformance() {
        if(!dynamicLeverageAdjust) {
            return;
        }

        double balance = AccountInfoDouble(ACCOUNT_BALANCE);
        double equity = AccountInfoDouble(ACCOUNT_EQUITY);

        // Reducir apalancamiento si hay drawdown
        if(equity < balance * 0.98) { // Drawdown > 2%
            currentLeverage = MathMax(minLeverage, currentLeverage * leverageReductionFactor);
        }
        // Aumentar apalancamiento ligeramente si hay ganancias consistentes
        else if(winStreak >= 3 && equity > balance * 1.02) { // Ganancias > 2% y 3 operaciones ganadoras
            currentLeverage = MathMin(maxLeverage, currentLeverage * 1.1);
        }
    }

    double CalculateKellyFraction(double winProbability, double riskRewardRatio) {
        // Corregir probabilidad para evitar valores extremos
        winProbability = MathMax(0.01, MathMin(0.99, winProbability));

        // Kelly Criterion estándar
        double kelly = winProbability - ((1 - winProbability) / riskRewardRatio);

        // Usar fracción de Kelly para mayor seguridad
        double fraction = 0.5; // Mitad de Kelly

        return MathMax(0.01, MathMin(0.25, kelly * fraction)); // Limitar entre 1% y 25%
    }

    double CalculateOverallRiskScore(double dailyDrawdown, double marginLevel, int consecutiveLosses, double volatilityRatio) {
        double score = 0.0;

        // Contribución del drawdown diario
        score += dailyDrawdown / maxDailyDrawdown;

        // Contribución del nivel de margen
        if(marginLevel < 150) {
            score += (150 - marginLevel) / 150;
        }

        // Contribución de racha de pérdidas
        score += consecutiveLosses * 0.1;

        // Contribución de volatilidad
        if(volatilityRatio > 1.5) {
            score += (volatilityRatio - 1.5) * 0.3;
        }

        // Normalizar a 0-1
        return MathMin(1.0, score / 2.0);
    }
};