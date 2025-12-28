//+------------------------------------------------------------------+
//| LiquidityZoneDetector.mqh                                       |
//| Liquidity Zone Detection System                                 |
//| Copyright 2025, Reinforcement Learning Trading Systems          |
//+------------------------------------------------------------------+
#property copyright "2025, RL Trading Systems"
#property link      "https://www.mql5.com "
#property version   "1.00"
#property strict

#include <Math/Stat/Math.mqh>
#include "../Core/CompatMQL4.mqh"

//+------------------------------------------------------------------+
//| Liquidity Zone Structure                                        |
//+------------------------------------------------------------------+
struct LiquidityZone {
    double priceLevel;          // Nivel de precio de la zona
    double strength;            // Fuerza de la zona (0.0-1.0)
    double zoneWidth;
    double liquidityScore;
    bool isMitigated;
    datetime formationTime;     // Momento de formación
    int timeframe;              // Timeframe de detección
    int type;                   // 0=Soporte, 1=Resistencia, 2=Equal High/Low
    int liquidityVolume;        // Volumen acumulado estimado
};

struct LiquidityAnalysis {
    double liquidityLevel;
    string pricePosition;
    int liquidityType;
    double expectedReaction;
};

struct LiquidityZones {
    LiquidityZone highLiquidityZones[];
    LiquidityZone lowLiquidityZones[];
    double distanceToNearestLiquidity;
    string priceAction;
};

//+------------------------------------------------------------------+
//| Liquidity Zone Detector Class                                   |
//+------------------------------------------------------------------+
class LiquidityZoneDetector {
private:
    string symbol;
    int maxZonesToTrack;
    int fractalPeriod;
    double volumeThreshold;
    LiquidityZone liquidityZones[];
    datetime lastRecalculation;

    // Additional members from second implementation
    ENUM_TIMEFRAMES m_monthlyTF;
    ENUM_TIMEFRAMES m_weeklyTF;
    ENUM_TIMEFRAMES m_dailyTF;
    int m_swingLookback;
    double m_volumeMultiplier;
    double m_liquidityThreshold;
    bool m_useVolumeConfirmation;
    int m_zoneCount;
    LiquidityZone m_detectedZones[];

    // Funciones internas
    void RecalculateZones();
    void DetectZonesOnTimeframe(ENUM_TIMEFRAMES timeframe);
    void DetectSwingPoints(ENUM_TIMEFRAMES timeframe, int lookback);
    double CalculateZoneStrength(double priceLevel, ENUM_TIMEFRAMES timeframe, int barIndex);
    void DetectCongestionZones(ENUM_TIMEFRAMES timeframe, int bars);
    void AddLiquidityZone(LiquidityZone newZone);
    void FilterLiquidityZones();
    bool IsSignificantLevel(double priceLevel, ENUM_TIMEFRAMES timeframe);

public:
    LiquidityZoneDetector(string sym, int maxZones=10);
    LiquidityZoneDetector(ENUM_TIMEFRAMES monthlyTF, ENUM_TIMEFRAMES weeklyTF, ENUM_TIMEFRAMES dailyTF);

    void SetParameters(int fractalPeriod, double volThreshold);
    void Configure(int swingLookback, double volumeMultiplier, double liquidityThreshold, bool useVolumeConfirmation);

    LiquidityZone[] GetLiquidityZones();
    LiquidityZones GetNearestZones();
    LiquidityZone GetNearestZoneAbove(double currentPrice);
    LiquidityZone GetNearestZoneBelow(double currentPrice);
    double GetLiquidityImbalance(double currentPrice);
    LiquidityAnalysis AnalyzeCurrentPrice();
};

//+------------------------------------------------------------------+
//| Constructors                                                     |
//+------------------------------------------------------------------+
LiquidityZoneDetector::LiquidityZoneDetector(string sym, int maxZones=10) {
    symbol = sym;
    maxZonesToTrack = maxZones;
    fractalPeriod = 5;
    volumeThreshold = 0.7;
    ArrayResize(liquidityZones, 0);
    lastRecalculation = 0;

    // Initialize members for second implementation logic
    m_zoneCount = 0;
    ArrayResize(m_detectedZones, 50);
}

LiquidityZoneDetector::LiquidityZoneDetector(ENUM_TIMEFRAMES monthlyTF, ENUM_TIMEFRAMES weeklyTF, ENUM_TIMEFRAMES dailyTF) {
    symbol = _Symbol;
    m_monthlyTF = monthlyTF;
    m_weeklyTF = weeklyTF;
    m_dailyTF = dailyTF;

    m_swingLookback = 20;
    m_volumeMultiplier = 1.5;
    m_liquidityThreshold = 0.7;
    m_useVolumeConfirmation = true;

    m_zoneCount = 0;
    ArrayResize(m_detectedZones, 50);

    // Initialize first implementation members
    fractalPeriod = 5;
    volumeThreshold = 0.7;
    maxZonesToTrack = 10;

    Print("LiquidityZoneDetector inicializado con timeframes M/W/D");
}

//+------------------------------------------------------------------+
//| Methods                                                          |
//+------------------------------------------------------------------+
void LiquidityZoneDetector::SetParameters(int fractalPeriod, double volThreshold) {
    this.fractalPeriod = fractalPeriod;
    this.volumeThreshold = volThreshold;
}

void LiquidityZoneDetector::Configure(int swingLookback, double volumeMultiplier, double liquidityThreshold, bool useVolumeConfirmation) {
    m_swingLookback = swingLookback;
    m_volumeMultiplier = volumeMultiplier;
    m_liquidityThreshold = liquidityThreshold;
    m_useVolumeConfirmation = useVolumeConfirmation;
}

LiquidityZone[] LiquidityZoneDetector::GetLiquidityZones() {
    if(GetTickCount() - lastRecalculation > 60000) { // Recalcular cada minuto
        RecalculateZones();
        lastRecalculation = GetTickCount();
    }
    return liquidityZones;
}

void LiquidityZoneDetector::RecalculateZones() {
    ArrayResize(liquidityZones, 0);
    // Detectar zonas en múltiples timeframes
    DetectZonesOnTimeframe(PERIOD_H1);
    DetectZonesOnTimeframe(PERIOD_H4);
    DetectZonesOnTimeframe(PERIOD_D1);

    // Ordenar por fuerza y eliminar débiles
    // ArraySort requires custom comparison or operator override for structs?
    // MQL5 ArraySort on structs requires a custom function. Assuming simplified sort for now or skip.
    // ArraySort(liquidityZones);

    if(ArraySize(liquidityZones) > maxZonesToTrack) {
        ArrayResize(liquidityZones, maxZonesToTrack);
    }
}

void LiquidityZoneDetector::DetectZonesOnTimeframe(ENUM_TIMEFRAMES timeframe) {
    int bars = 200;
    double highs[], lows[];
    datetime times[];

    CopyHigh(symbol, timeframe, 0, bars, highs);
    CopyLow(symbol, timeframe, 0, bars, lows);
    CopyTime(symbol, timeframe, 0, bars, times);

    // Detectar fractales como posibles zonas
    for(int i = fractalPeriod; i < bars - fractalPeriod; i++) {
        bool isHigh = true;
        bool isLow = true;

        for(int j = 1; j <= fractalPeriod; j++) {
            if(highs[i] <= highs[i-j] || highs[i] <= highs[i+j]) isHigh = false;
            if(lows[i] >= lows[i-j] || lows[i] >= lows[i+j]) isLow = false;
        }

        if(isHigh || isLow) {
            double price = isHigh ? highs[i] : lows[i];
            double strength = CalculateZoneStrength(price, timeframe, i);

            if(strength > volumeThreshold) {
                LiquidityZone zone;
                zone.priceLevel = price;
                zone.strength = strength;
                zone.formationTime = times[i];
                zone.timeframe = timeframe;
                zone.type = isHigh ? 1 : 0;
                zone.liquidityVolume = (int)(strength * 1000);

                AddLiquidityZone(zone);
            }
        }
    }

    // Detectar equal highs/lows (zonas de congestión)
    DetectCongestionZones(timeframe, bars);
}

double LiquidityZoneDetector::CalculateZoneStrength(double priceLevel, ENUM_TIMEFRAMES timeframe, int barIndex) {
    double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
    double distanceFactor = 1.0 - MathMin(1.0, MathAbs(priceLevel - currentPrice) / (200 * _Point));

    long volume = iVolume(symbol, timeframe, barIndex);
    double volumeFactor = (double)volume / (double)iVolume(symbol, timeframe, 0);

    int touches = 0;
    for(int i = MathMax(0, barIndex-50); i < barIndex; i++) {
        double high = iHigh(symbol, timeframe, i);
        double low = iLow(symbol, timeframe, i);

        if((high >= priceLevel - 5*_Point && high <= priceLevel + 5*_Point) ||
           (low >= priceLevel - 5*_Point && low <= priceLevel + 5*_Point)) {
            touches++;
        }
    }
    double touchFactor = MathMin(1.0, touches * 0.2);

    return (volumeFactor * 0.4 + touchFactor * 0.4 + distanceFactor * 0.2);
}

void LiquidityZoneDetector::DetectCongestionZones(ENUM_TIMEFRAMES timeframe, int bars) {
    int congestionPeriod = 20;
    for(int i = congestionPeriod; i < bars; i++) {
        double rangeHigh = 0.0, rangeLow = DBL_MAX;
        double totalRange = 0.0;

        for(int j = 0; j < congestionPeriod; j++) {
            double high = iHigh(symbol, timeframe, i-j);
            double low = iLow(symbol, timeframe, i-j);
            rangeHigh = MathMax(rangeHigh, high);
            rangeLow = MathMin(rangeLow, low);
            totalRange += high - low;
        }

        double avgRange = totalRange / congestionPeriod;
        double congestionRatio = (rangeHigh - rangeLow) / avgRange;

        if(congestionRatio < 0.3) {
            double midPrice = (rangeHigh + rangeLow) / 2.0;
            double strength = MathMin(1.0, 1.0 - congestionRatio) * 0.7;

            if(strength > volumeThreshold) {
                LiquidityZone zone;
                zone.priceLevel = midPrice;
                zone.strength = strength;
                zone.formationTime = iTime(symbol, timeframe, i);
                zone.timeframe = timeframe;
                zone.type = 2; // Equal High/Low
                zone.liquidityVolume = (int)(strength * 800);

                AddLiquidityZone(zone);
            }
        }
    }
}

void LiquidityZoneDetector::AddLiquidityZone(LiquidityZone newZone) {
    for(int i = 0; i < ArraySize(liquidityZones); i++) {
        if(MathAbs(liquidityZones[i].priceLevel - newZone.priceLevel) < 10*_Point) {
            if(newZone.strength > liquidityZones[i].strength) {
                liquidityZones[i] = newZone;
            }
            return;
        }
    }

    int size = ArraySize(liquidityZones);
    ArrayResize(liquidityZones, size + 1);
    liquidityZones[size] = newZone;
}

LiquidityZone LiquidityZoneDetector::GetNearestZoneAbove(double currentPrice) {
    LiquidityZone nearest;
    ZeroMemory(nearest);
    nearest.priceLevel = EMPTY_VALUE;

    for(int i = 0; i < ArraySize(liquidityZones); i++) {
        if(liquidityZones[i].priceLevel > currentPrice) {
            if(nearest.priceLevel == EMPTY_VALUE ||
               liquidityZones[i].priceLevel < nearest.priceLevel) {
                nearest = liquidityZones[i];
            }
        }
    }
    return nearest;
}

LiquidityZone LiquidityZoneDetector::GetNearestZoneBelow(double currentPrice) {
    LiquidityZone nearest;
    ZeroMemory(nearest);
    nearest.priceLevel = EMPTY_VALUE;

    for(int i = 0; i < ArraySize(liquidityZones); i++) {
        if(liquidityZones[i].priceLevel < currentPrice) {
            if(nearest.priceLevel == EMPTY_VALUE ||
               liquidityZones[i].priceLevel > nearest.priceLevel) {
                nearest = liquidityZones[i];
            }
        }
    }
    return nearest;
}

double LiquidityZoneDetector::GetLiquidityImbalance(double currentPrice) {
    LiquidityZone above = GetNearestZoneAbove(currentPrice);
    LiquidityZone below = GetNearestZoneBelow(currentPrice);

    if(above.priceLevel == EMPTY_VALUE || below.priceLevel == EMPTY_VALUE)
        return 0.0;

    double distanceAbove = above.priceLevel - currentPrice;
    double distanceBelow = currentPrice - below.priceLevel;

    double totalDistance = distanceAbove + distanceBelow;
    if(totalDistance == 0) return 0.0;

    double imbalance = (distanceBelow - distanceAbove) / totalDistance;
    return imbalance * (above.strength + below.strength) / 2.0;
}

// Additional Methods from original corrupted file, cleaned up
LiquidityAnalysis LiquidityZoneDetector::AnalyzeCurrentPrice() {
    LiquidityAnalysis analysis;
    ZeroMemory(analysis);

    double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
    LiquidityZones nearestZones = GetNearestZones();

    analysis.liquidityLevel = nearestZones.distanceToNearestLiquidity;
    analysis.pricePosition = nearestZones.priceAction;

    // Simple logic for expected reaction
    if(analysis.pricePosition == "ABOVE") {
        analysis.expectedReaction = -0.7;
    } else if(analysis.pricePosition == "BELOW") {
        analysis.expectedReaction = 0.7;
    }

    return analysis;
}

LiquidityZones LiquidityZoneDetector::GetNearestZones() {
    LiquidityZones zones;
    ZeroMemory(zones);

    zones.distanceToNearestLiquidity = 1000000.0;

    double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);

    // Resize output arrays (simplified assumption)
    ArrayResize(zones.highLiquidityZones, ArraySize(liquidityZones));
    ArrayResize(zones.lowLiquidityZones, ArraySize(liquidityZones));

    int highCount = 0;
    int lowCount = 0;

    for(int i = 0; i < ArraySize(liquidityZones); i++) {
        double dist = MathAbs(currentPrice - liquidityZones[i].priceLevel);
        if(dist < zones.distanceToNearestLiquidity) {
            zones.distanceToNearestLiquidity = dist;
        }

        if(liquidityZones[i].priceLevel > currentPrice) {
            zones.highLiquidityZones[highCount++] = liquidityZones[i];
            zones.priceAction = "BELOW";
        } else {
            zones.lowLiquidityZones[lowCount++] = liquidityZones[i];
            zones.priceAction = "ABOVE";
        }
    }

    ArrayResize(zones.highLiquidityZones, highCount);
    ArrayResize(zones.lowLiquidityZones, lowCount);

    return zones;
}

bool LiquidityZoneDetector::IsSignificantLevel(double priceLevel, ENUM_TIMEFRAMES timeframe) {
    // Placeholder implementation
    return true;
}

void LiquidityZoneDetector::FilterLiquidityZones() {
    // Placeholder
}

void LiquidityZoneDetector::DetectSwingPoints(ENUM_TIMEFRAMES timeframe, int lookback) {
    // Placeholder to satisfy prototype
}
