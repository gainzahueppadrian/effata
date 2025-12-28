//+------------------------------------------------------------------+
//| ICTFramework.mqh                                                |
//| Inner Circle Trader Framework Implementation                    |
//| Copyright 2025, Reinforcement Learning Trading Systems          |
//+------------------------------------------------------------------+
#property copyright "2025, RL Trading Systems"
#property link      "https://www.mql5.com"
#property version   "2.00"
#property strict

// Compatibilidad MQL4/MQL5
#ifdef __MQL4__
   #define PERIOD_CURRENT 0
   #define SYMBOL_POINT Point
   #define SYMBOL_ASK Ask
   #define SYMBOL_BID Bid

   // Función de compatibilidad para datetime
   datetime iTime(string symbol, int timeframe, int shift) {
      return Time[shift];
   }

   // Función de compatibilidad para obtener highs
   double iHigh(string symbol, int timeframe, int shift) {
      return High[shift];
   }

   // Función de compatibilidad para obtener lows
   double iLow(string symbol, int timeframe, int shift) {
      return Low[shift];
   }

   // Función de compatibilidad para obtener opens
   double iOpen(string symbol, int timeframe, int shift) {
      return Open[shift];
   }

   // Función de compatibilidad para obtener closes
   double iClose(string symbol, int timeframe, int shift) {
      return Close[shift];
   }

   // Función de compatibilidad para obtener volumen
   long iVolume(string symbol, int timeframe, int shift) {
      return (long)Volume[shift];
   }

   // Función de compatibilidad para obtener ATR
   double iATR(string symbol, int timeframe, int period, int shift) {
      return iATR(symbol, timeframe, period, shift);
   }

   // Función de compatibilidad para obtener número de barras
   int iBars(string symbol, int timeframe) {
      return Bars;
   }
#else
   // Definir constantes de compatibilidad para MQL5
   #define Point _Point
   #define Ask SymbolInfoDouble(_Symbol, SYMBOL_ASK)
   #define Bid SymbolInfoDouble(_Symbol, SYMBOL_BID)
   #define High[] iHigh(_Symbol, PERIOD_CURRENT, 0)
   #define Low[] iLow(_Symbol, PERIOD_CURRENT, 0)
   #define Open[] iOpen(_Symbol, PERIOD_CURRENT, 0)
   #define Close[] iClose(_Symbol, PERIOD_CURRENT, 0)
   #define Volume[] (double)iVolume(_Symbol, PERIOD_CURRENT, 0)
   #define Time[] iTime(_Symbol, PERIOD_CURRENT, 0)
#endif

//+------------------------------------------------------------------+
//| Estructuras ICT                                                  |
//+------------------------------------------------------------------+
struct FairValueGap {
    double top;
    double bottom;
    datetime formationTime;
    int timeframe;
    bool isBullish;
    double mitigationLevel;
    bool isMitigated;
    datetime mitigationTime;
};

struct OrderBlock {
    double entryPrice;
    double stopLevel;
    datetime formationTime;
    int timeframe;
    bool isBullish;
    double strength;
    bool isMitigated;
    datetime mitigationTime;
};

struct LiquidityPool {
    double priceLevel;
    double volume;
    datetime timestamp;
    int type; // 0=Sell-side, 1=Buy-side
    bool isTaken;
    datetime takenTime;
};

struct PO3Signal {
    bool isValid;
    int phase;           // 1=accumulation, 2=manipulation, 3=distribution
    string bias;         // "BULLISH", "BEARISH", "NEUTRAL"
    double po3High;      // Nivel superior PO3
    double po3Low;       // Nivel inferior PO3
    datetime signalTime;
};

struct BOSCHOCH {
    bool isBOS;          // Break of Structure
    bool isCHOCH;        // Change of Character
    int direction;       // 1=bullish, -1=bearish
    double breakoutLevel;
    datetime breakoutTime;
};

struct HTFBias {
    string monthlyBias;  // "BULLISH", "BEARISH"
    string weeklyBias;   // "BULLISH", "BEARISH"
    string dailyBias;    // "BULLISH", "BEARISH"
};

//+------------------------------------------------------------------+
//| ICT Framework Class                                             |
//+------------------------------------------------------------------+
class ICTFramework {
private:
    string m_symbol;
    int m_maxFVGs;
    int m_maxOrderBlocks;
    int m_maxLiquidityPools;

    FairValueGap m_fvgList[];
    OrderBlock m_orderBlockList[];
    LiquidityPool m_liquidityPools[];

    ENUM_TIMEFRAMES m_analysisTimeframe;
    ENUM_TIMEFRAMES m_entryTimeframe;
    double m_minProbabilityThreshold;

    datetime m_lastUpdate;
    HTFBias m_htfBias;

    // Variables para zonas premium/discount
    double m_premiumZoneHigh;
    double m_premiumZoneLow;
    double m_discountZoneHigh;
    double m_discountZoneLow;

    // Funciones de utilidad
    double GetHighest(int start, int count, ENUM_TIMEFRAMES timeframe);
    double GetLowest(int start, int count, ENUM_TIMEFRAMES timeframe);
    bool IsPriceNearLevel(double price, double level, double threshold);
    double CalculateATR(int period, ENUM_TIMEFRAMES timeframe);

    // Métodos privados
    void DetectFairValueGaps(ENUM_TIMEFRAMES timeframe);
    void DetectOrderBlocks(ENUM_TIMEFRAMES timeframe);
    void DetectLiquidityPools(ENUM_TIMEFRAMES timeframe);
    void AnalyzeHTFBias();
    bool IsFVGValid(FairValueGap &fvg);
    bool IsOrderBlockValid(OrderBlock &ob);
    void UpdateMitigationStatus();
    double CalculateMarketStructure(ENUM_TIMEFRAMES timeframe);
    void CalculatePremiumDiscountZones();
    void DetectLiquidityGrabs();

public:
    ICTFramework();
    void Configure(ENUM_TIMEFRAMES analysisTF, ENUM_TIMEFRAMES entryTF, double minProbability);
    void Update(string symbol);
    PO3Signal AnalyzePO3(ENUM_TIMEFRAMES timeframe);
    BOSCHOCH DetectBOSCHOCH(ENUM_TIMEFRAMES timeframe);
    HTFBias GetHTFBias();
    bool IsPriceInFVG(double price);
    double GetNearestValidOrderBlock(double price, bool isBullish);
    double GetNearestLiquidityPool(double price, bool abovePrice);
    bool IsInPremiumZone();
    bool IsInDiscountZone();
    bool IsAtLiquidityGrabLevel(double currentPrice);
    void SetSymbol(string symbol);
    void CleanOldPatterns(int maxAgeInBars);
};

//+------------------------------------------------------------------+
//| Constructor                                                         |
//+------------------------------------------------------------------+
ICTFramework::ICTFramework() {
    m_maxFVGs = 10;
    m_maxOrderBlocks = 10;
    m_maxLiquidityPools = 20;
    m_analysisTimeframe = PERIOD_H4;
    m_entryTimeframe = PERIOD_H1;
    m_minProbabilityThreshold = 0.65;
    m_lastUpdate = 0;
    m_symbol = _Symbol;

    // Inicializar arrays
    ArrayResize(m_fvgList, 0);
    ArrayResize(m_orderBlockList, 0);
    ArrayResize(m_liquidityPools, 0);

    // Inicializar sesgo HTF
    m_htfBias.monthlyBias = "NEUTRAL";
    m_htfBias.weeklyBias = "NEUTRAL";
    m_htfBias.dailyBias = "NEUTRAL";

    // Inicializar zonas premium/discount
    m_premiumZoneHigh = 0;
    m_premiumZoneLow = 0;
    m_discountZoneHigh = 0;
    m_discountZoneLow = 0;
}

//+------------------------------------------------------------------+
//| Configurar parámetros del framework                             |
//+------------------------------------------------------------------+
void ICTFramework::Configure(ENUM_TIMEFRAMES analysisTF, ENUM_TIMEFRAMES entryTF, double minProbability) {
    m_analysisTimeframe = analysisTF;
    m_entryTimeframe = entryTF;
    m_minProbabilityThreshold = minProbability;
}

//+------------------------------------------------------------------+
//| Actualizar el framework con nuevos datos                       |
//+------------------------------------------------------------------+
void ICTFramework::Update(string symbol) {
    m_symbol = symbol;

    // Actualizar solo cada 30 segundos para optimizar rendimiento
    if(GetTickCount() - m_lastUpdate < 30000) {
        return;
    }

    // Detectar patrones en diferentes timeframes
    DetectFairValueGaps(m_analysisTimeframe);
    DetectOrderBlocks(m_analysisTimeframe);
    DetectLiquidityPools(m_entryTimeframe);

    // Analizar sesgo HTF
    AnalyzeHTFBias();

    // Calcular zonas premium/discount
    CalculatePremiumDiscountZones();

    // Detectar liquidity grabs
    DetectLiquidityGrabs();

    // Actualizar estado de mitigación
    UpdateMitigationStatus();

    // Limpiar patrones antiguos
    CleanOldPatterns(100);

    m_lastUpdate = GetTickCount();
}

//+------------------------------------------------------------------+
//| Analizar Power of 3 (PO3)                                        |
//+------------------------------------------------------------------+
PO3Signal ICTFramework::AnalyzePO3(ENUM_TIMEFRAMES timeframe) {
    PO3Signal signal;
    ZeroMemory(signal);

    // Obtener datos de precio
    const int maxBars = 200;
    double highs[], lows[], closes[];
    datetime times[];

    // Cargar datos según MQL4 o MQL5
    #ifdef __MQL4__
        ArrayResize(highs, maxBars);
        ArrayResize(lows, maxBars);
        ArrayResize(closes, maxBars);
        ArrayResize(times, maxBars);

        for(int i = 0; i < maxBars; i++) {
            highs[i] = iHigh(m_symbol, timeframe, i);
            lows[i] = iLow(m_symbol, timeframe, i);
            closes[i] = iClose(m_symbol, timeframe, i);
            times[i] = iTime(m_symbol, timeframe, i);
        }
    #else
        int copied = CopyHigh(m_symbol, timeframe, 0, maxBars, highs);
        if(copied < maxBars) return signal;

        copied = CopyLow(m_symbol, timeframe, 0, maxBars, lows);
        if(copied < maxBars) return signal;

        copied = CopyClose(m_symbol, timeframe, 0, maxBars, closes);
        if(copied < maxBars) return signal;

        copied = CopyTime(m_symbol, timeframe, 0, maxBars, times);
        if(copied < maxBars) return signal;
    #endif

    // Detectar swing points
    double swingHighs[10], swingLows[10];
    datetime swingHighTimes[10], swingLowTimes[10];
    int highCount = 0, lowCount = 0;

    // Buscar máximos y mínimos recientes
    for(int i = 5; i < maxBars - 5; i++) {
        bool isHigh = true;
        bool isLow = true;

        // Verificar si es máximo
        for(int j = 1; j <= 5; j++) {
            if(highs[i] <= highs[i-j] || highs[i] <= highs[i+j]) {
                isHigh = false;
                break;
            }
        }

        // Verificar si es mínimo
        for(int j = 1; j <= 5; j++) {
            if(lows[i] >= lows[i-j] || lows[i] >= lows[i+j]) {
                isLow = false;
                break;
            }
        }

        if(isHigh && highCount < 10) {
            swingHighs[highCount] = highs[i];
            swingHighTimes[highCount] = times[i];
            highCount++;
        }

        if(isLow && lowCount < 10) {
            swingLows[lowCount] = lows[i];
            swingLowTimes[lowCount] = times[i];
            lowCount++;
        }
    }

    if(highCount < 3 || lowCount < 3) {
        return signal;
    }

    // Calcular niveles PO3
    double po3HighLevel = 0;
    double po3LowLevel = DBL_MAX;

    // Encontrar los tres máximos más altos recientes
    for(int i = 0; i < 3 && i < highCount; i++) {
        if(swingHighs[i] > po3HighLevel) {
            po3HighLevel = swingHighs[i];
        }
    }

    // Encontrar los tres mínimos más bajos recientes
    for(int i = 0; i < 3 && i < lowCount; i++) {
        if(swingLows[i] < po3LowLevel) {
            po3LowLevel = swingLows[i];
        }
    }

    // Determinar fase y sesgo
    double currentPrice = iClose(m_symbol, timeframe, 0);
    double priceRange = po3HighLevel - po3LowLevel;
    double middleLevel = po3LowLevel + priceRange * 0.5;

    signal.po3High = po3HighLevel;
    signal.po3Low = po3LowLevel;
    signal.signalTime = TimeCurrent();
    signal.isValid = true;

    // Determinar fase y sesgo
    if(currentPrice > po3HighLevel) {
        signal.phase = 3; // Fase de distribución
        signal.bias = "BEARISH";
    } else if(currentPrice < po3LowLevel) {
        signal.phase = 3; // Fase de distribución
        signal.bias = "BULLISH";
    } else if(currentPrice > middleLevel) {
        signal.phase = 2; // Fase de manipulación
        signal.bias = "BULLISH";
    } else {
        signal.phase = 2; // Fase de manipulación
        signal.bias = "BEARISH";
    }

    return signal;
}

//+------------------------------------------------------------------+
//| Detectar BOS y CHOCH                                           |
//+------------------------------------------------------------------+
BOSCHOCH ICTFramework::DetectBOSCHOCH(ENUM_TIMEFRAMES timeframe) {
    BOSCHOCH result;
    ZeroMemory(result);

    const int lookback = 50;
    double highs[], lows[], closes[];
    datetime times[];

    // Cargar datos
    #ifdef __MQL4__
        ArrayResize(highs, lookback);
        ArrayResize(lows, lookback);
        ArrayResize(closes, lookback);
        ArrayResize(times, lookback);

        for(int i = 0; i < lookback; i++) {
            highs[i] = iHigh(m_symbol, timeframe, i);
            lows[i] = iLow(m_symbol, timeframe, i);
            closes[i] = iClose(m_symbol, timeframe, i);
            times[i] = iTime(m_symbol, timeframe, i);
        }
    #else
        int copied = CopyHigh(m_symbol, timeframe, 0, lookback, highs);
        if(copied < lookback) return result;

        copied = CopyLow(m_symbol, timeframe, 0, lookback, lows);
        if(copied < lookback) return result;

        copied = CopyClose(m_symbol, timeframe, 0, lookback, closes);
        if(copied < lookback) return result;

        copied = CopyTime(m_symbol, timeframe, 0, lookback, times);
        if(copied < lookback) return result;
    #endif

    // Encontrar el último swing high y swing low
    double lastSwingHigh = 0;
    double lastSwingLow = DBL_MAX;
    datetime lastSwingHighTime = 0;
    datetime lastSwingLowTime = 0;

    for(int i = 5; i < lookback - 5; i++) {
        bool isHigh = true;
        bool isLow = true;

        for(int j = 1; j <= 5; j++) {
            if(highs[i] <= highs[i-j] || highs[i] <= highs[i+j]) isHigh = false;
            if(lows[i] >= lows[i-j] || lows[i] >= lows[i+j]) isLow = false;
        }

        if(isHigh && highs[i] > lastSwingHigh) {
            lastSwingHigh = highs[i];
            lastSwingHighTime = times[i];
        }

        if(isLow && lows[i] < lastSwingLow) {
            lastSwingLow = lows[i];
            lastSwingLowTime = times[i];
        }
    }

    double currentPrice = iClose(m_symbol, timeframe, 0);
    double prevPrice = iClose(m_symbol, timeframe, 1);

    // Detectar BOS (Break of Structure)
    if(currentPrice > lastSwingHigh && prevPrice <= lastSwingHigh) {
        result.isBOS = true;
        result.direction = 1; // Bullish
        result.breakoutLevel = lastSwingHigh;
        result.breakoutTime = TimeCurrent();
    } else if(currentPrice < lastSwingLow && prevPrice >= lastSwingLow) {
        result.isBOS = true;
        result.direction = -1; // Bearish
        result.breakoutLevel = lastSwingLow;
        result.breakoutTime = TimeCurrent();
    }

    // Detectar CHOCH (Change of Character)
    if(lastSwingHighTime > lastSwingLowTime) {
        // Último swing fue un high (tendencia alcista)
        if(currentPrice < lastSwingLow) {
            result.isCHOCH = true;
            result.direction = -1; // Cambio a tendencia bajista
        }
    } else {
        // Último swing fue un low (tendencia bajista)
        if(currentPrice > lastSwingHigh) {
            result.isCHOCH = true;
            result.direction = 1; // Cambio a tendencia alcista
        }
    }

    return result;
}

//+------------------------------------------------------------------+
//| Obtener sesgo HTF                                              |
//+------------------------------------------------------------------+
HTFBias ICTFramework::GetHTFBias() {
    return m_htfBias;
}

//+------------------------------------------------------------------+
//| Verificar si el precio está en un FVG                          |
//+------------------------------------------------------------------+
bool ICTFramework::IsPriceInFVG(double price) {
    for(int i = 0; i < ArraySize(m_fvgList); i++) {
        if(!m_fvgList[i].isMitigated &&
           ((m_fvgList[i].isBullish && price > m_fvgList[i].bottom && price < m_fvgList[i].top) ||
            (!m_fvgList[i].isBullish && price > m_fvgList[i].bottom && price < m_fvgList[i].top))) {
            return true;
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| Obtener el Order Block válido más cercano                     |
//+------------------------------------------------------------------+
double ICTFramework::GetNearestValidOrderBlock(double price, bool isBullish) {
    double nearestDistance = DBL_MAX;
    double nearestBlockPrice = 0;

    for(int i = 0; i < ArraySize(m_orderBlockList); i++) {
        if(m_orderBlockList[i].isBullish == isBullish && !m_orderBlockList[i].isMitigated) {
            double distance = MathAbs(m_orderBlockList[i].entryPrice - price);
            if(distance < nearestDistance) {
                nearestDistance = distance;
                nearestBlockPrice = m_orderBlockList[i].entryPrice;
            }
        }
    }

    return nearestBlockPrice;
}

//+------------------------------------------------------------------+
//| Obtener el pool de liquidez más cercano                        |
//+------------------------------------------------------------------+
double ICTFramework::GetNearestLiquidityPool(double price, bool abovePrice) {
    double nearestDistance = DBL_MAX;
    double nearestPoolPrice = 0;

    for(int i = 0; i < ArraySize(m_liquidityPools); i++) {
        if(!m_liquidityPools[i].isTaken) {
            double distance = MathAbs(m_liquidityPools[i].priceLevel - price);
            bool condition = abovePrice ? (m_liquidityPools[i].priceLevel > price) : (m_liquidityPools[i].priceLevel < price);

            if(condition && distance < nearestDistance) {
                nearestDistance = distance;
                nearestPoolPrice = m_liquidityPools[i].priceLevel;
            }
        }
    }

    return nearestPoolPrice;
}

//+------------------------------------------------------------------+
//| Verificar si el precio está en zona premium                    |
//+------------------------------------------------------------------+
bool ICTFramework::IsInPremiumZone() {
    double currentPrice = (iHigh(m_symbol, PERIOD_CURRENT, 0) + iLow(m_symbol, PERIOD_CURRENT, 0)) / 2;
    return (currentPrice >= m_premiumZoneLow && currentPrice <= m_premiumZoneHigh);
}

//+------------------------------------------------------------------+
//| Verificar si el precio está en zona de descuento               |
//+------------------------------------------------------------------+
bool ICTFramework::IsInDiscountZone() {
    double currentPrice = (iHigh(m_symbol, PERIOD_CURRENT, 0) + iLow(m_symbol, PERIOD_CURRENT, 0)) / 2;
    return (currentPrice >= m_discountZoneLow && currentPrice <= m_discountZoneHigh);
}

//+------------------------------------------------------------------+
//| Verificar si el precio está en nivel de liquidity grab         |
//+------------------------------------------------------------------+
bool ICTFramework::IsAtLiquidityGrabLevel(double currentPrice) {
    const double threshold = CalculateATR(14, PERIOD_CURRENT) * 0.5;

    for(int i = 0; i < ArraySize(m_liquidityPools); i++) {
        if(!m_liquidityPools[i].isTaken &&
           IsPriceNearLevel(currentPrice, m_liquidityPools[i].priceLevel, threshold)) {
            return true;
        }
    }

    return false;
}

//+------------------------------------------------------------------+
//| Establecer símbolo para el análisis                            |
//+------------------------------------------------------------------+
void ICTFramework::SetSymbol(string symbol) {
    m_symbol = symbol;
}

//+------------------------------------------------------------------+
//| Detectar Fair Value Gaps                                       |
//+------------------------------------------------------------------+
void ICTFramework::DetectFairValueGaps(ENUM_TIMEFRAMES timeframe) {
    ArrayResize(m_fvgList, 0);

    const int maxBars = 200;
    double highs[], lows[], closes[];
    datetime times[];

    // Cargar datos
    #ifdef __MQL4__
        ArrayResize(highs, maxBars);
        ArrayResize(lows, maxBars);
        ArrayResize(closes, maxBars);
        ArrayResize(times, maxBars);

        for(int i = 0; i < maxBars; i++) {
            highs[i] = iHigh(m_symbol, timeframe, i);
            lows[i] = iLow(m_symbol, timeframe, i);
            closes[i] = iClose(m_symbol, timeframe, i);
            times[i] = iTime(m_symbol, timeframe, i);
        }
    #else
        int copied = CopyHigh(m_symbol, timeframe, 0, maxBars, highs);
        if(copied < maxBars) return;

        copied = CopyLow(m_symbol, timeframe, 0, maxBars, lows);
        if(copied < maxBars) return;

        copied = CopyClose(m_symbol, timeframe, 0, maxBars, closes);
        if(copied < maxBars) return;

        copied = CopyTime(m_symbol, timeframe, 0, maxBars, times);
        if(copied < maxBars) return;
    #endif

    // Buscar FVGs
    for(int i = 2; i < maxBars - 3; i++) {
        // Detectar FVG alcista
        if(closes[i] < lows[i+1] && highs[i+1] < lows[i+2]) {
            FairValueGap fvg;
            fvg.bottom = highs[i+1];
            fvg.top = lows[i+2];
            fvg.formationTime = times[i+1];
            fvg.timeframe = timeframe;
            fvg.isBullish = true;
            fvg.mitigationLevel = highs[i+2];
            fvg.isMitigated = false;
            fvg.mitigationTime = 0;

            if(IsFVGValid(fvg)) {
                int size = ArraySize(m_fvgList);
                ArrayResize(m_fvgList, size + 1);
                m_fvgList[size] = fvg;
            }
        }

        // Detectar FVG bajista
        else if(closes[i] > highs[i+1] && lows[i+1] > highs[i+2]) {
            FairValueGap fvg;
            fvg.bottom = highs[i+2];
            fvg.top = lows[i+1];
            fvg.formationTime = times[i+1];
            fvg.timeframe = timeframe;
            fvg.isBullish = false;
            fvg.mitigationLevel = lows[i+2];
            fvg.isMitigated = false;
            fvg.mitigationTime = 0;

            if(IsFVGValid(fvg)) {
                int size = ArraySize(m_fvgList);
                ArrayResize(m_fvgList, size + 1);
                m_fvgList[size] = fvg;
            }
        }
    }

    // Mantener solo FVGs más recientes
    if(ArraySize(m_fvgList) > m_maxFVGs) {
        ArrayResize(m_fvgList, m_maxFVGs);
    }
}

//+------------------------------------------------------------------+
//| Detectar Order Blocks                                          |
//+------------------------------------------------------------------+
void ICTFramework::DetectOrderBlocks(ENUM_TIMEFRAMES timeframe) {
    ArrayResize(m_orderBlockList, 0);

    const int maxBars = 200;
    double opens[], highs[], lows[], closes[];
    datetime times[];
    long volumes[];

    // Cargar datos
    #ifdef __MQL4__
        ArrayResize(opens, maxBars);
        ArrayResize(highs, maxBars);
        ArrayResize(lows, maxBars);
        ArrayResize(closes, maxBars);
        ArrayResize(times, maxBars);
        ArrayResize(volumes, maxBars);

        for(int i = 0; i < maxBars; i++) {
            opens[i] = iOpen(m_symbol, timeframe, i);
            highs[i] = iHigh(m_symbol, timeframe, i);
            lows[i] = iLow(m_symbol, timeframe, i);
            closes[i] = iClose(m_symbol, timeframe, i);
            times[i] = iTime(m_symbol, timeframe, i);
            volumes[i] = iVolume(m_symbol, timeframe, i);
        }
    #else
        int copied = CopyOpen(m_symbol, timeframe, 0, maxBars, opens);
        if(copied < maxBars) return;

        copied = CopyHigh(m_symbol, timeframe, 0, maxBars, highs);
        if(copied < maxBars) return;

        copied = CopyLow(m_symbol, timeframe, 0, maxBars, lows);
        if(copied < maxBars) return;

        copied = CopyClose(m_symbol, timeframe, 0, maxBars, closes);
        if(copied < maxBars) return;

        copied = CopyTime(m_symbol, timeframe, 0, maxBars, times);
        if(copied < maxBars) return;

        long tempVolumes[];
        CopyTickVolume(m_symbol, timeframe, 0, maxBars, tempVolumes);
        ArrayCopy(volumes, tempVolumes);
    #endif

    // Detectar Order Blocks
    for(int i = 1; i < maxBars - 1; i++) {
        double range = highs[i] - lows[i];
        double body = MathAbs(closes[i] - opens[i]);

        // Verificar si la vela tiene cuerpo significativo
        if(body < range * 0.3) continue;

        // Verificar volumen significativo
        double avgVolume = 0;
        for(int j = i; j <= i+5 && j < maxBars; j++) {
            avgVolume += volumes[j];
        }
        avgVolume /= MathMin(6, maxBars - i);

        if(volumes[i] < avgVolume * 1.2) continue;

        // Detectar Order Block alcista
        if(closes[i] > opens[i] && body > range * 0.6) {
            // Verificar si el precio retrocede en las velas siguientes
            bool retracement = false;
            for(int j = 1; j <= 3; j++) {
                if(i+j < maxBars && closes[i+j] < closes[i]) {
                    retracement = true;
                    break;
                }
            }

            if(retracement) {
                OrderBlock ob;
                ob.entryPrice = lows[i];
                ob.stopLevel = highs[i];
                ob.formationTime = times[i];
                ob.timeframe = timeframe;
                ob.isBullish = true;
                ob.strength = body / range;
                ob.isMitigated = false;
                ob.mitigationTime = 0;

                if(IsOrderBlockValid(ob)) {
                    int size = ArraySize(m_orderBlockList);
                    ArrayResize(m_orderBlockList, size + 1);
                    m_orderBlockList[size] = ob;
                }
            }
        }

        // Detectar Order Block bajista
        else if(closes[i] < opens[i] && body > range * 0.6) {
            // Verificar si el precio retrocede en las velas siguientes
            bool retracement = false;
            for(int j = 1; j <= 3; j++) {
                if(i+j < maxBars && closes[i+j] > closes[i]) {
                    retracement = true;
                    break;
                }
            }

            if(retracement) {
                OrderBlock ob;
                ob.entryPrice = highs[i];
                ob.stopLevel = lows[i];
                ob.formationTime = times[i];
                ob.timeframe = timeframe;
                ob.isBullish = false;
                ob.strength = body / range;
                ob.isMitigated = false;
                ob.mitigationTime = 0;

                if(IsOrderBlockValid(ob)) {
                    int size = ArraySize(m_orderBlockList);
                    ArrayResize(m_orderBlockList, size + 1);
                    m_orderBlockList[size] = ob;
                }
            }
        }
    }

    // Mantener solo Order Blocks más recientes
    if(ArraySize(m_orderBlockList) > m_maxOrderBlocks) {
        ArrayResize(m_orderBlockList, m_maxOrderBlocks);
    }
}

//+------------------------------------------------------------------+
//| Detectar Pools de Liquidez                                     |
//+------------------------------------------------------------------+
void ICTFramework::DetectLiquidityPools(ENUM_TIMEFRAMES timeframe) {
    ArrayResize(m_liquidityPools, 0);

    const int maxBars = 100;
    double highs[], lows[];
    datetime times[];
    long volumes[];

    // Cargar datos
    #ifdef __MQL4__
        ArrayResize(highs, maxBars);
        ArrayResize(lows, maxBars);
        ArrayResize(times, maxBars);
        ArrayResize(volumes, maxBars);

        for(int i = 0; i < maxBars; i++) {
            highs[i] = iHigh(m_symbol, timeframe, i);
            lows[i] = iLow(m_symbol, timeframe, i);
            times[i] = iTime(m_symbol, timeframe, i);
            volumes[i] = iVolume(m_symbol, timeframe, i);
        }
    #else
        int copied = CopyHigh(m_symbol, timeframe, 0, maxBars, highs);
        if(copied < maxBars) return;

        copied = CopyLow(m_symbol, timeframe, 0, maxBars, lows);
        if(copied < maxBars) return;

        copied = CopyTime(m_symbol, timeframe, 0, maxBars, times);
        if(copied < maxBars) return;

        long tempVolumes[];
        CopyTickVolume(m_symbol, timeframe, 0, maxBars, tempVolumes);
        ArrayCopy(volumes, tempVolumes);
    #endif

    // Encontrar swings recientes
    for(int i = 5; i < maxBars - 5; i++) {
        bool isHigh = true;
        bool isLow = true;

        for(int j = 1; j <= 5; j++) {
            if(highs[i] <= highs[i-j] || highs[i] <= highs[i+j]) isHigh = false;
            if(lows[i] >= lows[i-j] || lows[i] >= lows[i+j]) isLow = false;
        }

        if(isHigh) {
            LiquidityPool pool;
            pool.priceLevel = highs[i];
            pool.volume = (double)volumes[i];
            pool.timestamp = times[i];
            pool.type = 0; // Sell-side
            pool.isTaken = false;
            pool.takenTime = 0;

            int size = ArraySize(m_liquidityPools);
            ArrayResize(m_liquidityPools, size + 1);
            m_liquidityPools[size] = pool;
        }

        if(isLow) {
            LiquidityPool pool;
            pool.priceLevel = lows[i];
            pool.volume = (double)volumes[i];
            pool.timestamp = times[i];
            pool.type = 1; // Buy-side
            pool.isTaken = false;
            pool.takenTime = 0;

            int size = ArraySize(m_liquidityPools);
            ArrayResize(m_liquidityPools, size + 1);
            m_liquidityPools[size] = pool;
        }
    }

    // Mantener solo pools más recientes
    if(ArraySize(m_liquidityPools) > m_maxLiquidityPools) {
        ArrayResize(m_liquidityPools, m_maxLiquidityPools);
    }
}

//+------------------------------------------------------------------+
//| Analizar sesgo HTF                                             |
//+------------------------------------------------------------------+
void ICTFramework::AnalyzeHTFBias() {
    // Análisis mensual
    double monthlyHigh = GetHighest(0, 3, PERIOD_MN1);
    double monthlyLow = GetLowest(0, 3, PERIOD_MN1);
    double monthlyClose = iClose(m_symbol, PERIOD_MN1, 0);

    if(monthlyClose > (monthlyHigh + monthlyLow) / 2) {
        m_htfBias.monthlyBias = "BULLISH";
    } else {
        m_htfBias.monthlyBias = "BEARISH";
    }

    // Análisis semanal
    double weeklyHigh = GetHighest(0, 5, PERIOD_W1);
    double weeklyLow = GetLowest(0, 5, PERIOD_W1);
    double weeklyClose = iClose(m_symbol, PERIOD_W1, 0);

    if(weeklyClose > (weeklyHigh + weeklyLow) / 2) {
        m_htfBias.weeklyBias = "BULLISH";
    } else {
        m_htfBias.weeklyBias = "BEARISH";
    }

    // Análisis diario
    double dailyHigh = GetHighest(0, 5, PERIOD_D1);
    double dailyLow = GetLowest(0, 5, PERIOD_D1);
    double dailyClose = iClose(m_symbol, PERIOD_D1, 0);

    if(dailyClose > (dailyHigh + dailyLow) / 2) {
        m_htfBias.dailyBias = "BULLISH";
    } else {
        m_htfBias.dailyBias = "BEARISH";
    }
}

//+------------------------------------------------------------------+
//| Verificar si un FVG es válido                                   |
//+------------------------------------------------------------------+
bool ICTFramework::IsFVGValid(FairValueGap &fvg) {
    // Un FVG es válido si no ha sido mitigado y está dentro de parámetros razonables
    double range = fvg.top - fvg.bottom;
    double atr = CalculateATR(14, m_analysisTimeframe);

    // El rango debe ser significativo pero no excesivo
    return (range > atr * 0.1 && range < atr * 2.0);
}

//+------------------------------------------------------------------+
//| Verificar si un Order Block es válido                           |
//+------------------------------------------------------------------+
bool ICTFramework::IsOrderBlockValid(OrderBlock &ob) {
    // Un Order Block es válido si tiene fuerza suficiente y no ha sido mitigado
    return (ob.strength > 0.4 && !ob.isMitigated);
}

//+------------------------------------------------------------------+
//| Actualizar estado de mitigación                                |
//+------------------------------------------------------------------+
void ICTFramework::UpdateMitigationStatus() {
    double currentPrice = (iHigh(m_symbol, PERIOD_CURRENT, 0) + iLow(m_symbol, PERIOD_CURRENT, 0)) / 2;

    // Actualizar estado de FVGs
    for(int i = 0; i < ArraySize(m_fvgList); i++) {
        if(!m_fvgList[i].isMitigated) {
            if(m_fvgList[i].isBullish && currentPrice < m_fvgList[i].bottom) {
                m_fvgList[i].isMitigated = true;
                m_fvgList[i].mitigationTime = TimeCurrent();
            } else if(!m_fvgList[i].isBullish && currentPrice > m_fvgList[i].top) {
                m_fvgList[i].isMitigated = true;
                m_fvgList[i].mitigationTime = TimeCurrent();
            }
        }
    }

    // Actualizar estado de Order Blocks
    for(int i = 0; i < ArraySize(m_orderBlockList); i++) {
        if(!m_orderBlockList[i].isMitigated) {
            if(m_orderBlockList[i].isBullish && currentPrice < m_orderBlockList[i].entryPrice) {
                m_orderBlockList[i].isMitigated = true;
                m_orderBlockList[i].mitigationTime = TimeCurrent();
            } else if(!m_orderBlockList[i].isBullish && currentPrice > m_orderBlockList[i].entryPrice) {
                m_orderBlockList[i].isMitigated = true;
                m_orderBlockList[i].mitigationTime = TimeCurrent();
            }
        }
    }

    // Actualizar estado de Liquidity Pools
    for(int i = 0; i < ArraySize(m_liquidityPools); i++) {
        if(!m_liquidityPools[i].isTaken) {
            double threshold = CalculateATR(14, PERIOD_CURRENT) * 0.3;
            if(IsPriceNearLevel(currentPrice, m_liquidityPools[i].priceLevel, threshold)) {
                m_liquidityPools[i].isTaken = true;
                m_liquidityPools[i].takenTime = TimeCurrent();
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Calcular estructura de mercado                                 |
//+------------------------------------------------------------------+
double ICTFramework::CalculateMarketStructure(ENUM_TIMEFRAMES timeframe) {
    const int lookback = 50;
    double highs[], lows[];
    datetime times[];

    // Cargar datos
    #ifdef __MQL4__
        ArrayResize(highs, lookback);
        ArrayResize(lows, lookback);
        ArrayResize(times, lookback);

        for(int i = 0; i < lookback; i++) {
            highs[i] = iHigh(m_symbol, timeframe, i);
            lows[i] = iLow(m_symbol, timeframe, i);
            times[i] = iTime(m_symbol, timeframe, i);
        }
    #else
        int copied = CopyHigh(m_symbol, timeframe, 0, lookback, highs);
        if(copied < lookback) return 0;

        copied = CopyLow(m_symbol, timeframe, 0, lookback, lows);
        if(copied < lookback) return 0;

        copied = CopyTime(m_symbol, timeframe, 0, lookback, times);
        if(copied < lookback) return 0;
    #endif

    // Encontrar swing points más recientes
    double lastHigh = 0;
    double lastLow = DBL_MAX;
    datetime lastHighTime = 0;
    datetime lastLowTime = 0;

    for(int i = 5; i < lookback - 5; i++) {
        bool isHigh = true;
        bool isLow = true;

        for(int j = 1; j <= 5; j++) {
            if(highs[i] <= highs[i-j] || highs[i] <= highs[i+j]) isHigh = false;
            if(lows[i] >= lows[i-j] || lows[i] >= lows[i+j]) isLow = false;
        }

        if(isHigh && highs[i] > lastHigh) {
            lastHigh = highs[i];
            lastHighTime = times[i];
        }

        if(isLow && lows[i] < lastLow) {
            lastLow = lows[i];
            lastLowTime = times[i];
        }
    }

    // Calcular estructura de mercado
    double structure = 0;
    if(lastHighTime > lastLowTime) {
        // Último swing fue un high (tendencia alcista)
        structure = 1.0;
    } else {
        // Último swing fue un low (tendencia bajista)
        structure = -1.0;
    }

    return structure;
}

double GetNearestOrderBlock(double price, bool isBullish) {
    double nearest = EMPTY_VALUE;
    for(int i = 0; i < ArraySize(m_orderBlockList); i++) {
        if(m_orderBlockList[i].isBullish == isBullish) {
            double distance = MathAbs(m_orderBlockList[i].entryPrice - price);
            if(nearest == EMPTY_VALUE || distance < MathAbs(nearest - price)) {
                nearest = m_orderBlockList[i].entryPrice;
            }
        }
    }
    return nearest;
}

//+------------------------------------------------------------------+
//| Obtener el precio más alto en un rango                         |
//+------------------------------------------------------------------+
double ICTFramework::GetHighest(int start, int count, ENUM_TIMEFRAMES timeframe) {
    double highest = 0;

    for(int i = start; i < start + count; i++) {
        double high = iHigh(m_symbol, timeframe, i);
        if(high > highest) highest = high;
    }

    return highest;
}

//+------------------------------------------------------------------+
//| Obtener el precio más bajo en un rango                         |
//+------------------------------------------------------------------+
double ICTFramework::GetLowest(int start, int count, ENUM_TIMEFRAMES timeframe) {
    double lowest = DBL_MAX;

    for(int i = start; i < start + count; i++) {
        double low = iLow(m_symbol, timeframe, i);
        if(low < lowest) lowest = low;
    }

    return lowest;
}

//+------------------------------------------------------------------+
//| Verificar si el precio está cerca de un nivel                  |
//+------------------------------------------------------------------+
bool ICTFramework::IsPriceNearLevel(double price, double level, double threshold) {
    return (MathAbs(price - level) < threshold);
}

//+------------------------------------------------------------------+
//| Calcular ATR                                                    |
//+------------------------------------------------------------------+
double ICTFramework::CalculateATR(int period, ENUM_TIMEFRAMES timeframe) {
    return iATR(m_symbol, timeframe, period, 0);
}

//+------------------------------------------------------------------+
//| Calcular zonas premium/discount                                |
//+------------------------------------------------------------------+
void ICTFramework::CalculatePremiumDiscountZones() {
    // Calcular basado en el rango del día anterior
    double yesterdayHigh = iHigh(m_symbol, PERIOD_D1, 1);
    double yesterdayLow = iLow(m_symbol, PERIOD_D1, 1);
    double yesterdayRange = yesterdayHigh - yesterdayLow;
    double yesterdayMid = (yesterdayHigh + yesterdayLow) / 2;

    // Zona Premium: 61.8% a 78.6% del rango desde el mínimo
    m_premiumZoneLow = yesterdayLow + yesterdayRange * 0.618;
    m_premiumZoneHigh = yesterdayLow + yesterdayRange * 0.786;

    // Zona Discount: 23.6% a 38.2% del rango desde el mínimo
    m_discountZoneLow = yesterdayLow + yesterdayRange * 0.236;
    m_discountZoneHigh = yesterdayLow + yesterdayRange * 0.382;
}

//+------------------------------------------------------------------+
//| Detectar Liquidity Grabs                                        |
//+------------------------------------------------------------------+
void ICTFramework::DetectLiquidityGrabs() {
    // Esta función ya está integrada en UpdateMitigationStatus()
    // y en IsAtLiquidityGrabLevel()
}

//+------------------------------------------------------------------+
//| Limpiar patrones antiguos                                       |
//+------------------------------------------------------------------+
void ICTFramework::CleanOldPatterns(int maxAgeInBars) {
    datetime cutoffTime = TimeCurrent() - maxAgeInBars * PeriodSeconds(m_analysisTimeframe);

    // Limpiar FVGs antiguos
    int newSize = 0;
    for(int i = 0; i < ArraySize(m_fvgList); i++) {
        if(m_fvgList[i].formationTime > cutoffTime) {
            if(i != newSize) {
                m_fvgList[newSize] = m_fvgList[i];
            }
            newSize++;
        }
    }
    ArrayResize(m_fvgList, newSize);

    // Limpiar Order Blocks antiguos
    newSize = 0;
    for(int i = 0; i < ArraySize(m_orderBlockList); i++) {
        if(m_orderBlockList[i].formationTime > cutoffTime) {
            if(i != newSize) {
                m_orderBlockList[newSize] = m_orderBlockList[i];
            }
            newSize++;
        }
    }
    ArrayResize(m_orderBlockList, newSize);

    // Limpiar Liquidity Pools antiguos
    newSize = 0;
    for(int i = 0; i < ArraySize(m_liquidityPools); i++) {
        if(m_liquidityPools[i].timestamp > cutoffTime) {
            if(i != newSize) {
                m_liquidityPools[newSize] = m_liquidityPools[i];
            }
            newSize++;
        }
    }
    ArrayResize(m_liquidityPools, newSize);
}