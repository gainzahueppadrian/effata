//+------------------------------------------------------------------+
//| CRTTheory.mqh                                                  |
//| Candle Range Theory Implementation                               |
//| Copyright 2025, Reinforcement Learning Trading Systems          |
//+------------------------------------------------------------------+
#property copyright "2025, RL Trading Systems"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include <Math/Math.mqh>

//+------------------------------------------------------------------+
//| CRT Signal Structure                                             |
//+------------------------------------------------------------------+
struct CRTSignal {
    string signalType;          // "BUY", "SELL", "NONE"
    double confidence;          // 0.0 - 1.0
    double supportLevel;        // Nivel de soporte
    double resistanceLevel;     // Nivel de resistencia
    double atrValue;            // Valor ATR
    int patternType;            // Tipo de patrón identificado
};

//+------------------------------------------------------------------+
//| CRT Theory Class                                                 |
//+------------------------------------------------------------------+
class CRTTheory {
private:
    int atrPeriod;
    double largeMultiplier;
    double smallMultiplier;
    int minInsideBars;

public:
    CRTTheory() {
        atrPeriod = 14;
        largeMultiplier = 1.5;
        smallMultiplier = 0.5;
        minInsideBars = 2;
    }

    void SetParameters(int atrPeriod, double largeMult, double smallMult, int minInside) {
        this.atrPeriod = atrPeriod;
        this.largeMultiplier = largeMult;
        this.smallMultiplier = smallMult;
        this.minInsideBars = minInside;
    }

    CRTSignal Analyze(ENUM_TIMEFRAMES timeframe) {
        CRTSignal signal = {"NONE", 0.0, 0.0, 0.0, 0.0, 0};

        // Obtener datos necesarios
        const int needBars = MathMax(atrPeriod + 5, minInsideBars + 3);
        if(Bars(_Symbol, timeframe) < needBars) {
            return signal;
        }

        double high[], low[], open[], close[];
        ArraySetAsSeries(high, true);
        ArraySetAsSeries(low, true);
        ArraySetAsSeries(open, true);
        ArraySetAsSeries(close, true);

        CopyHigh(_Symbol, timeframe, 0, needBars, high);
        CopyLow(_Symbol, timeframe, 0, needBars, low);
        CopyOpen(_Symbol, timeframe, 0, needBars, open);
        CopyClose(_Symbol, timeframe, 0, needBars, close);

        // Calcular ATR
        double atr = CalculateATR(high, low, close, atrPeriod, 0);
        signal.atrValue = atr;

        // Determinar niveles de soporte y resistencia
        signal.supportLevel = CalculateSupportLevel(low, needBars, 3);
        signal.resistanceLevel = CalculateResistanceLevel(high, needBars, 3);

        // Analizar patrones CRT
        bool isLargeCandle = IsLargeCandle(open[1], high[1], low[1], close[1], atr);
        bool isSmallCandle = IsSmallCandle(open[1], high[1], low[1], close[1], atr);
        bool isInsideBar = IsInsideBar(high[1], low[1], high[2], low[2]);
        int insideBarCount = CountConsecutiveInsideBars(high, low, needBars);
        bool isOutsideBar = IsOutsideBar(high[1], low[1], high[2], low[2]);

        // Analizar contexto de mercado
        bool isTrendUp = IsUptrend(close, needBars);
        bool isTrendDown = IsDowntrend(close, needBars);
        bool isVolatilityHigh = (atr / close[1]) > 0.005; // ATR > 0.5% del precio

        // Detectar señales de compra
        if(isTrendUp && (isLargeCandle || isOutsideBar) && close[1] > open[1]) {
            signal.signalType = "BUY";
            signal.confidence = CalculateBuyConfidence(isLargeCandle, isOutsideBar, isVolatilityHigh, insideBarCount);
            signal.patternType = 1;
        }
        // Detectar señales de venta
        else if(isTrendDown && (isLargeCandle || isOutsideBar) && close[1] < open[1]) {
            signal.signalType = "SELL";
            signal.confidence = CalculateSellConfidence(isLargeCandle, isOutsideBar, isVolatilityHigh, insideBarCount);
            signal.patternType = 2;
        }
        // Detectar patrón de consolidación que precede a ruptura
        else if(insideBarCount >= minInsideBars && (isLargeCandle || isOutsideBar)) {
            if(close[1] > open[1] && close[1] > close[2]) {
                signal.signalType = "BUY";
                signal.confidence = 0.7 + (insideBarCount - minInsideBars) * 0.1;
                signal.patternType = 3;
            }
            else if(close[1] < open[1] && close[1] < close[2]) {
                signal.signalType = "SELL";
                signal.confidence = 0.7 + (insideBarCount - minInsideBars) * 0.1;
                signal.patternType = 4;
            }
        }

        // Limitar confianza máxima
        signal.confidence = MathMin(signal.confidence, 0.95);

        return signal;
    }

private:
    double CalculateATR(const double &high[], const double &low[], const double &close[], int period, int shift) {
        double atr = 0.0;

        if(ArraySize(high) < period + 1 || ArraySize(low) < period + 1 || ArraySize(close) < period + 1) {
            return 0.0;
        }

        for(int i = shift; i < shift + period; i++) {
            double tr1 = high[i] - low[i];
            double tr2 = MathAbs(high[i] - close[i+1]);
            double tr3 = MathAbs(low[i] - close[i+1]);
            double tr = MathMax(tr1, MathMax(tr2, tr3));
            atr += tr;
        }

        return atr / period;
    }

    bool IsLargeCandle(double open, double high, double low, double close, double atr) {
        double range = high - low;
        return range >= atr * largeMultiplier;
    }

    bool IsSmallCandle(double open, double high, double low, double close, double atr) {
        double range = high - low;
        return range <= atr * smallMultiplier;
    }

    bool IsInsideBar(double high1, double low1, double high2, double low2) {
        return (high1 <= high2 && low1 >= low2);
    }

    int CountConsecutiveInsideBars(const double &high[], const double &low[], int totalBars) {
        int count = 0;

        for(int i = 2; i < totalBars - 1; i++) {
            if(IsInsideBar(high[i], low[i], high[i+1], low[i+1])) {
                count++;
            } else {
                break;
            }
        }

        return count;
    }

    bool IsOutsideBar(double high1, double low1, double high2, double low2) {
        return (high1 > high2 && low1 < low2);
    }

    bool IsUptrend(const double &close[], int totalBars) {
        if(totalBars < 5) return false;

        // Pendiente de una regresión lineal simple
        double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
        int points = 5;

        for(int i = 0; i < points; i++) {
            sumX += i;
            sumY += close[i];
            sumXY += i * close[i];
            sumX2 += i * i;
        }

        double slope = (points * sumXY - sumX * sumY) / (points * sumX2 - sumX * sumX);
        return slope > 0;
    }

    bool IsDowntrend(const double &close[], int totalBars) {
        if(totalBars < 5) return false;

        // Pendiente de una regresión lineal simple
        double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
        int points = 5;

        for(int i = 0; i < points; i++) {
            sumX += i;
            sumY += close[i];
            sumXY += i * close[i];
            sumX2 += i * i;
        }

        double slope = (points * sumXY - sumX * sumY) / (points * sumX2 - sumX * sumX);
        return slope < 0;
    }

    double CalculateSupportLevel(const double &low[], int totalBars, int lookback) {
        double min = low[0];

        for(int i = 1; i < MathMin(totalBars, lookback + 1); i++) {
            if(low[i] < min) {
                min = low[i];
            }
        }

        return min;
    }

    double CalculateResistanceLevel(const double &high[], int totalBars, int lookback) {
        double max = high[0];

        for(int i = 1; i < MathMin(totalBars, lookback + 1); i++) {
            if(high[i] > max) {
                max = high[i];
            }
        }

        return max;
    }

    double CalculateBuyConfidence(bool isLargeCandle, bool isOutsideBar, bool isVolatilityHigh, int insideBarCount) {
        double confidence = 0.5;

        if(isLargeCandle) confidence += 0.2;
        if(isOutsideBar) confidence += 0.3;
        if(isVolatilityHigh) confidence += 0.1;
        if(insideBarCount >= minInsideBars) confidence += (insideBarCount - minInsideBars + 1) * 0.05;

        return MathMin(confidence, 0.95);
    }

    double CalculateSellConfidence(bool isLargeCandle, bool isOutsideBar, bool isVolatilityHigh, int insideBarCount) {
        double confidence = 0.5;

        if(isLargeCandle) confidence += 0.2;
        if(isOutsideBar) confidence += 0.3;
        if(isVolatilityHigh) confidence += 0.1;
        if(insideBarCount >= minInsideBars) confidence += (insideBarCount - minInsideBars + 1) * 0.05;

        return MathMin(confidence, 0.95);
    }
};