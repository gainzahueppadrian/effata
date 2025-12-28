//+------------------------------------------------------------------+
//| AccountProtector.mqh                                           |
//| Broker Manipulation Protection System                            |
//| Copyright 2025, Reinforcement Learning Trading Systems          |
//+------------------------------------------------------------------+
#property copyright "2025, RL Trading Systems"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include <Math/Math.mqh>
#include <Math/Stat/Math.mqh>
#include <Math/Stat/Normal.mqh>

//+------------------------------------------------------------------+
//| Broker Manipulation Risk Structure                               |
//+------------------------------------------------------------------+
struct BrokerManipulationRisk {
    string riskLevel;           // "LOW", "MEDIUM", "HIGH", "EXTREME"
    double probability;         // Probabilidad de manipulación (0.0-1.0)
    double distanceToSL;        // Distancia al stop loss en puntos
    double distanceToTP;        // Distancia al take profit en puntos
    double historicalSlippage;  // Deslizamiento histórico promedio
    int slippageCount;         // Número de eventos de deslizamiento
};

//+------------------------------------------------------------------+
//| Account Protector Class                                           |
//+------------------------------------------------------------------+
class AccountProtector {
private:
    double minLotSize;
    double historicalData[100][5]; // [slippage, distanceToSL, distanceToTP, timeOfDay, dayOfWeek]
    int historicalCount;
    datetime lastSlippageCheck;
    int slippageThreshold;
    double slippageFactor;
    double marketDepth;

public:
    AccountProtector(double minLot) {
        minLotSize = minLot;
        historicalCount = 0;
        lastSlippageCheck = 0;
        slippageThreshold = 3; // 3 pip de deslizamiento para considerar manipulación
        slippageFactor = 1.5;  // Factor de ajuste para stop loss
        marketDepth = 0.0;
    }

    bool Initialize() {
        // Inicializar datos históricos
        LoadHistoricalData();
        return true;
    }

    BrokerManipulationRisk AssessPositionRisk(ulong ticket, double entryPrice, double sl, double tp) {
        BrokerManipulationRisk risk = {"LOW", 0.0, 0.0, 0.0, 0.0, 0};

        if(ticket == 0) {
            return risk;
        }

        // Obtener detalles de la posición
        double currentPrice = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ?
                             SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);

        // Calcular distancias
        risk.distanceToSL = MathAbs(currentPrice - sl) / SymbolInfoDouble(_Symbol, SYMBOL_POINT);
        risk.distanceToTP = MathAbs(tp - currentPrice) / SymbolInfoDouble(_Symbol, SYMBOL_POINT);

        // Verificar si el precio está cerca del SL
        double dangerZone = 10.0; // 10 pips
        if(risk.distanceToSL < dangerZone) {
            // Analizar patrones históricos de manipulación
            risk.probability = CalculateManipulationProbability(entryPrice, sl, tp, risk.distanceToSL, risk.distanceToTP);

            // Determinar nivel de riesgo
            if(risk.probability > 0.8) {
                risk.riskLevel = "EXTREME";
            } else if(risk.probability > 0.6) {
                risk.riskLevel = "HIGH";
            } else if(risk.probability > 0.4) {
                risk.riskLevel = "MEDIUM";
            } else {
                risk.riskLevel = "LOW";
            }
        }

        // Verificar deslizamiento histórico
        risk.historicalSlippage = GetAverageSlippage();
        risk.slippageCount = GetSlippageCount();

        return risk;
    }

    BrokerManipulationRisk AssessEntryRisk() {
        BrokerManipulationRisk risk = {"LOW", 0.0, 0.0, 0.0, 0.0, 0};

        // Analizar condiciones actuales del mercado
        double currentSpread = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID)) /
                               SymbolInfoDouble(_Symbol, SYMBOL_POINT);
        double averageSpread = GetAverageSpread();

        if(currentSpread > averageSpread * 2.0) {
            risk.probability = 0.7;
            risk.riskLevel = "HIGH";
        }

        // Verificar horarios de baja liquidez
        MqlDateTime currentTime;
        TimeCurrent(currentTime);

        if((currentTime.hour >= 23 || currentTime.hour < 6) && currentTime.day_of_week >= 1 && currentTime.day_of_week <= 5) {
            risk.probability = MathMax(risk.probability, 0.5);
            if(risk.riskLevel == "LOW") risk.riskLevel = "MEDIUM";
        }

        // Verificar proximidad a noticias importantes
        if(IsHighImpactNewsTime()) {
            risk.probability = MathMax(risk.probability, 0.6);
            if(risk.riskLevel == "LOW" || risk.riskLevel == "MEDIUM") risk.riskLevel = "HIGH";
        }

        return risk;
    }

    bool ShouldAdjustStopLoss(ulong ticket, const BrokerManipulationRisk &risk) {
        // Ajustar SL solo si el riesgo es alto o extremo
        return (risk.riskLevel == "HIGH" || risk.riskLevel == "EXTREME") && risk.distanceToSL < 15.0;
    }

    double CalculateProtectedStopLoss(ulong ticket, const BrokerManipulationRisk &risk) {
        double currentSL = PositionGetDouble(POSITION_SL);
        double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        double currentPrice = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ?
                             SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);

        double newSL = currentSL;
        double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

        if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
            // Para posiciones largas, mover SL más abajo
            if(risk.riskLevel == "HIGH") {
                newSL = currentSL - 5.0 * point;
            } else if(risk.riskLevel == "EXTREME") {
                newSL = currentSL - 10.0 * point;
            }

            // Asegurar distancia mínima al precio actual
            double minDistance = 15.0 * point; // 15 pips mínimo
            if(currentPrice - newSL < minDistance) {
                newSL = currentPrice - minDistance;
            }
        } else {
            // Para posiciones cortas, mover SL más arriba
            if(risk.riskLevel == "HIGH") {
                newSL = currentSL + 5.0 * point;
            } else if(risk.riskLevel == "EXTREME") {
                newSL = currentSL + 10.0 * point;
            }

            // Asegurar distancia mínima al precio actual
            double minDistance = 15.0 * point; // 15 pips mínimo
            if(newSL - currentPrice < minDistance) {
                newSL = currentPrice + minDistance;
            }
        }

        return newSL;
    }

    void RecordTradeExecution(ulong ticket, double requestedPrice, double executedPrice,
                             ENUM_ORDER_TYPE orderType, double volume) {
        double slippage = MathAbs(executedPrice - requestedPrice) / SymbolInfoDouble(_Symbol, SYMBOL_POINT);

        if(slippage > slippageThreshold) {
            // Registrar evento de deslizamiento
            SaveSlippageEvent(slippage, ticket, orderType, volume);

            // Analizar patrón
            AnalyzeSlippagePattern();
        }
    }

private:
    void LoadHistoricalData() {
        // Cargar datos históricos de deslizamiento
        // En una implementación real, esto vendría de un archivo o base de datos
        historicalCount = 0;
    }

    double CalculateManipulationProbability(double entryPrice, double sl, double tp,
                                           double distToSL, double distToTP) {
        double probability = 0.0;

        // Factor 1: Distancia al SL
        if(distToSL < 10.0) {
            probability += 0.3 * (10.0 - distToSL) / 10.0;
        }

        // Factor 2: Relación distancia SL/TP
        double slToTpRatio = distToSL / (distToSL + distToTP);
        if(slToTpRatio < 0.3) { // SL muy cerca comparado con TP
            probability += 0.4 * (0.3 - slToTpRatio) / 0.3;
        }

        // Factor 3: Patrones históricos de deslizamiento
        double avgSlippage = GetAverageSlippage();
        if(avgSlippage > 2.0) {
            probability += 0.2 * (avgSlippage - 2.0) / 5.0;
        }

        // Factor 4: Volatilidad actual
        double currentATR = iATR(_Symbol, PERIOD_M15, 14, 0);
        double avgATR = iATR(_Symbol, PERIOD_H1, 14, 0);
        if(currentATR > avgATR * 1.5) {
            probability += 0.1;
        }

        return MathMin(1.0, probability);
    }

    double GetAverageSlippage() {
        if(historicalCount == 0) {
            return 0.0;
        }

        double sum = 0.0;
        for(int i = 0; i < historicalCount; i++) {
            sum += historicalData[i][0];
        }

        return sum / historicalCount;
    }

    int GetSlippageCount() {
        int count = 0;
        for(int i = 0; i < historicalCount; i++) {
            if(historicalData[i][0] > slippageThreshold) {
                count++;
            }
        }
        return count;
    }

    double GetAverageSpread() {
        // Calcular spread promedio en los últimos 100 ticks
        long spreadSum = 0;
        int count = 0;

        for(int i = 0; i < 100; i++) {
            MqlTick tick;
            if(SymbolInfoTick(_Symbol, tick)) {
                spreadSum += (long)((tick.ask - tick.bid) / SymbolInfoDouble(_Symbol, SYMBOL_POINT));
                count++;
            }
        }

        return count > 0 ? (double)spreadSum / count : 1.0;
    }

    bool IsHighImpactNewsTime() {
        // Verificar si hay noticias de alto impacto en las próximas 2 horas
        MqlDateTime currentTime;
        TimeCurrent(currentTime);

        // En una implementación real, esto consultaría un calendario económico
        // Por ahora, verificar horarios típicos de noticias importantes
        if(currentTime.day_of_week == 3 && currentTime.hour >= 12 && currentTime.hour < 14) { // Miércoles 12-14 UTC (FOMC)
            return true;
        }
        if(currentTime.day_of_week == 5 && currentTime.hour >= 12 && currentTime.hour < 14) { // Viernes 12-14 UTC (NFP)
            return true;
        }

        return false;
    }

    void SaveSlippageEvent(double slippage, ulong ticket, ENUM_ORDER_TYPE orderType, double volume) {
        if(historicalCount >= 100) {
            // Desplazar datos antiguos
            for(int i = 0; i < 99; i++) {
                ArrayCopy(historicalData[i], historicalData[i+1], 0, 0, 5);
            }
            historicalCount = 99;
        }

        MqlDateTime currentTime;
        TimeCurrent(currentTime);

        historicalData[historicalCount][0] = slippage;
        historicalData[historicalCount][1] = 0.0; // Distancia al SL - se calcularía
        historicalData[historicalCount][2] = 0.0; // Distancia al TP - se calcularía
        historicalData[historicalCount][3] = currentTime.hour + currentTime.min/60.0;
        historicalData[historicalCount][4] = currentTime.day_of_week;

        historicalCount++;
    }

    void AnalyzeSlippagePattern() {
        if(historicalCount < 10) {
            return;
        }

        // Analizar patrones de deslizamiento por hora del día
        double hourPatterns[24] = {0};
        int hourCounts[24] = {0};

        for(int i = 0; i < historicalCount; i++) {
            int hour = (int)historicalData[i][3];
            if(hour >= 0 && hour < 24) {
                hourPatterns[hour] += historicalData[i][0];
                hourCounts[hour]++;
            }
        }

        // Calcular promedios por hora
        for(int i = 0; i < 24; i++) {
            if(hourCounts[i] > 0) {
                hourPatterns[i] /= hourCounts[i];
            }
        }

        // Identificar horas de alto deslizamiento
        MqlDateTime currentTime;
        TimeCurrent(currentTime);
        int currentHour = currentTime.hour;

        if(hourPatterns[currentHour] > slippageThreshold * 1.5) {
            slippageFactor = MathMax(slippageFactor, 2.0);
        }
    }
};