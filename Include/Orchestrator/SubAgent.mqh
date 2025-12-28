//+------------------------------------------------------------------+
//| SubAgent.mqh                                                     |
//| Sub-agente especializado para patrones específicos              |
//| Copyright 2025, Advanced AI Trading Systems                      |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Advanced AI Trading Systems"
#property link      "https://www.example.com"
#property version   "1.00"

#ifndef SUB_AGENT_MQH
#define SUB_AGENT_MQH

#include <Math/Math.mqh>
#include <Math/Stat/Math.mqh>
#include "../Core/CompatMQL4.mqh"
// #include "../Neural/CNNPatternDetector.mqh" // Removed as faulty/unused

// Estructura para decisión de sub-agente
struct SubAgentDecision {
   string agentName;
   double signalStrength;
   double confidence;
   double patternMatch;
   datetime timestamp;
};

// Clase base para sub-agentes especializados
class CSubAgent {
private:
   // Identificación del sub-agente
   string m_name;
   string m_description;

   // Parámetros específicos del sub-agente
   double m_confidenceThreshold;
   int m_patternWindowSize;
   int m_atrPeriod;

   // Detectores de patrones especializados
   // CCNNPatternDetector *m_patternDetector; // Removed

   // Estado interno
   datetime m_lastUpdate;
   double m_performanceScore;
   int m_tradesCount;
   int m_successCount;

   // Contexto de mercado
   MarketData m_marketData[100];
   int m_dataCount;

public:
   // Constructor e inicialización
   CSubAgent(string name);
   bool Initialize();
   void Configure(double confidenceThreshold, int patternWindowSize, int atrPeriod);

   // Métodos de análisis
   SubAgentDecision GetDecision(const MarketData &currentData);
   virtual double AnalyzePattern(const MarketData &data[], int count) = 0;
   virtual string GetPatternDescription() = 0;

   // Métodos de aprendizaje
   void UpdatePerformance(bool tradeSuccessful, double profitFactor);
   void LearnFromMarket(const MarketData &data[], int count);

   // Métodos de utilidad
   double CalculateATR(const MarketData &data[], int period, int shift);
   bool IsInsideBar(double open1, double high1, double low1, double close1,
                   double open2, double high2, double low2, double close2);
   bool IsLargeRangeBar(double high, double low, double bodySize);

   // Métodos de acceso
   string GetName() { return m_name; }
   double GetConfidenceThreshold() { return m_confidenceThreshold; }
   double GetPerformanceScore() { return m_performanceScore; }
};

//+------------------------------------------------------------------+
//| Constructor - Inicialización del sub-agente                    |
//+------------------------------------------------------------------+
CSubAgent::CSubAgent(string name) {
   m_name = name;
   m_description = "Sub-agente especializado para " + name;
   m_confidenceThreshold = 0.7;
   m_patternWindowSize = 20;
   m_atrPeriod = 14;
   m_lastUpdate = 0;
   m_performanceScore = 0.5;
   m_tradesCount = 0;
   m_successCount = 0;

   // Inicializar detector de patrones
   // m_patternDetector = new CCNNPatternDetector();
   // m_patternDetector->Initialize(m_patternWindowSize);

   Print("Sub-agente '", m_name, "' creado con parámetros por defecto");
}

//+------------------------------------------------------------------+
//| Inicializar el sub-agente                                       |
//+------------------------------------------------------------------+
bool CSubAgent::Initialize() {
   /*
   if(m_patternDetector == NULL) {
      Print("Error: Detector de patrones no inicializado");
      return false;
   }
   */
   Print("Sub-agente '", m_name, "' inicializado correctamente");
   return true;
}

//+------------------------------------------------------------------+
//| Configurar parámetros del sub-agente                            |
//+------------------------------------------------------------------+
void CSubAgent::Configure(double confidenceThreshold, int patternWindowSize, int atrPeriod) {
   m_confidenceThreshold = MathMin(MathMax(confidenceThreshold, 0.5), 0.95);
   m_patternWindowSize = MathMax(patternWindowSize, 10);
   m_atrPeriod = MathMax(atrPeriod, 5);

   /*
   if(m_patternDetector) {
      m_patternDetector->Initialize(m_patternWindowSize);
   }
   */
   Print("Sub-agente '", m_name, "' configurado:");
   Print("- Umbral de confianza: ", DoubleToString(m_confidenceThreshold, 2));
   Print("- Ventana de patrón: ", m_patternWindowSize);
   Print("- Período ATR: ", m_atrPeriod);
}

//+------------------------------------------------------------------+
//| Obtener decisión del sub-agente                                 |
//+------------------------------------------------------------------+
SubAgentDecision CSubAgent::GetDecision(const MarketData &currentData) {
   SubAgentDecision decision;
   ZeroMemory(decision);

   decision.agentName = m_name;
   decision.timestamp = TimeCurrent();

   // Actualizar datos de mercado
   if(m_dataCount < 100) {
      m_dataCount++;
   }

   for(int i = m_dataCount - 1; i > 0; i--) {
      m_marketData[i] = m_marketData[i-1];
   }

   m_marketData[0] = currentData;

   // Calcular ATR
   if(m_dataCount >= m_atrPeriod) {
      m_marketData[0].atr = CalculateATR(m_marketData, m_atrPeriod, 0);
   }

   // Analizar patrón
   if(m_dataCount >= m_patternWindowSize) {
      decision.patternMatch = AnalyzePattern(m_marketData, m_patternWindowSize);

      // Calcular fortaleza de señal y confianza
      if(decision.patternMatch > m_confidenceThreshold) {
         decision.signalStrength = (decision.patternMatch - 0.5) * 2.0; // Normalizar a [-1, 1]
         decision.confidence = decision.patternMatch * m_performanceScore;
      } else {
         decision.signalStrength = 0.0;
         decision.confidence = 0.0;
      }
   }

   return decision;
}

//+------------------------------------------------------------------+
//| Calcular ATR (Average True Range)                               |
//+------------------------------------------------------------------+
double CSubAgent::CalculateATR(const MarketData &data[], int period, int shift) {
   if(shift + period >= 100) return 0.0;

   double trSum = 0.0;
   for(int i = shift; i < shift + period; i++) {
      double tr1 = data[i].high - data[i].low;
      double tr2 = MathAbs(data[i].high - data[i+1].close);
      double tr3 = MathAbs(data[i].low - data[i+1].close);
      trSum += MathMax(tr1, MathMax(tr2, tr3));
   }

   return trSum / period;
}

//+------------------------------------------------------------------+
//| Verificar si es una inside bar                                 |
//+------------------------------------------------------------------+
bool CSubAgent::IsInsideBar(double open1, double high1, double low1, double close1,
                           double open2, double high2, double low2, double close2) {
   return (high1 < high2 && low1 > low2);
}

//+------------------------------------------------------------------+
//| Verificar si es una vela de rango grande                       |
//+------------------------------------------------------------------+
bool CSubAgent::IsLargeRangeBar(double high, double low, double bodySize) {
   if(m_dataCount < m_atrPeriod) return false;

   double range = high - low;
   return (range > m_marketData[0].atr * 1.5 && bodySize > range * 0.7);
}

//+------------------------------------------------------------------+
//| Actualizar rendimiento del sub-agente                           |
//+------------------------------------------------------------------+
void CSubAgent::UpdatePerformance(bool tradeSuccessful, double profitFactor) {
   m_tradesCount++;

   if(tradeSuccessful) {
      m_successCount++;

      // Ajustar puntuación de rendimiento
      if(profitFactor > 1.5) {
         m_performanceScore = MathMin(m_performanceScore + 0.05, 0.95);
      } else if(profitFactor > 1.0) {
         m_performanceScore = MathMin(m_performanceScore + 0.02, 0.95);
      }
   } else {
      m_performanceScore = MathMax(m_performanceScore - 0.03, 0.3);
   }

   // Calcular puntuación basada en ratio de éxito
   double successRate = (double)m_successCount / MathMax(m_tradesCount, 1);
   m_performanceScore = (m_performanceScore + successRate) / 2.0;

   Print("📊 Sub-agente '", m_name, "' - Rendimiento actualizado:");
   Print("- Operaciones: ", m_tradesCount, " (Exitosas: ", m_successCount, ")");
   Print("- Ratio de éxito: ", DoubleToString(successRate * 100, 1), "%");
   Print("- Puntuación de rendimiento: ", DoubleToString(m_performanceScore, 2));
}

//+------------------------------------------------------------------+
//| Aprender de datos de mercado                                    |
//+------------------------------------------------------------------+
void CSubAgent::LearnFromMarket(const MarketData &data[], int count) {
   if(count < m_patternWindowSize) return;

   // Implementar lógica de aprendizaje específica para este sub-agente
   // (Dependerá del tipo de patrón que detecte)

   // Ejemplo: Ajustar umbral de confianza basado en rendimiento
   if(m_performanceScore < 0.6 && m_confidenceThreshold > 0.6) {
      m_confidenceThreshold -= 0.01;
      Print("📉 Sub-agente '", m_name, "' - Umbral de confianza reducido a ",
            DoubleToString(m_confidenceThreshold, 2), " por bajo rendimiento");
   } else if(m_performanceScore > 0.8 && m_confidenceThreshold < 0.85) {
      m_confidenceThreshold += 0.01;
      Print("📈 Sub-agente '", m_name, "' - Umbral de confianza aumentado a ",
            DoubleToString(m_confidenceThreshold, 2), " por alto rendimiento");
   }
}

//+------------------------------------------------------------------+
//| Implementación específica para sub-agente CRT                  |
//+------------------------------------------------------------------+
class CCRTSubAgent : public CSubAgent {
public:
   CCRTSubAgent() : CSubAgent("CRT") {
      Configure(0.75, 20, 14);
   }

   double AnalyzePattern(const MarketData &data[], int count) override {
      int insideBarCount = 0;

      // Contar inside bars consecutivos
      for(int i = 0; i < 5 && i < count - 1; i++) {
         if(IsInsideBar(data[i].open, data[i].high, data[i].low, data[i].close,
                       data[i+1].open, data[i+1].high, data[i+1].low, data[i+1].close)) {
            insideBarCount++;
         } else {
            break;
         }
      }

      // Verificar breakout
      if(insideBarCount >= 2) {
         double breakoutStrength = 0.0;

         if(data[0].close > data[1].high) {
            breakoutStrength = (data[0].close - data[1].high) / data[0].atr;
         } else if(data[0].close < data[1].low) {
            breakoutStrength = (data[1].low - data[0].close) / data[0].atr;
         }

         return MathMin(0.9, 0.6 + breakoutStrength * 0.2 + insideBarCount * 0.05);
      }

      // Verificar vela grande en dirección opuesta
      double bodySize = MathAbs(data[1].open - data[1].close);
      if(IsLargeRangeBar(data[1].high, data[1].low, bodySize) &&
         ((data[1].close < data[1].open && data[0].close > data[0].open) ||
          (data[1].close > data[1].open && data[0].close < data[0].open))) {
         return 0.7;
      }

      return 0.0;
   }

   string GetPatternDescription() override {
      return "Candle Range Theory: Inside bars + breakout o reversión con vela grande";
   }
};

//+------------------------------------------------------------------+
//| Implementación específica para sub-agente PO3                  |
//+------------------------------------------------------------------+
class CPO3SubAgent : public CSubAgent {
public:
   CPO3SubAgent() : CSubAgent("PO3") {
      Configure(0.70, 15, 14);
   }

   double AnalyzePattern(const MarketData &data[], int count) override {
      if(count < 10) return 0.0;

      // 1. Fase de Acumulación (Rango estrecho con volumen decreciente)
      double currentRange = data[0].high - data[0].low;
      double avgRange = 0.0;
      double volumeTrend = 0.0;

      for(int i = 0; i < 5; i++) {
         avgRange += (data[i].high - data[i].low);
         if(i > 0) {
            volumeTrend += (data[i].volume - data[i-1].volume);
         }
      }

      avgRange /= 5.0;
      volumeTrend /= 4.0;

      bool isAccumulation = (currentRange < avgRange * 0.5 && volumeTrend < 0);

      // 2. Fase de Manipulación (Sweep de liquidez)
      double recentHigh = data[ArrayMaximum(data, 1, 10)].high;
      double recentLow = data[ArrayMinimum(data, 1, 10)].low;

      bool sweptHigh = (data[0].high > recentHigh && data[0].close < recentHigh);
      bool sweptLow = (data[0].low < recentLow && data[0].close > recentLow);

      // 3. Fase de Distribución (Expansión de rango)
      bool isDistribution = (currentRange > avgRange * 1.5);

      // PO3 Bullish: Acumulación + Sweep de mínimos + Distribución alcista
      bool po3Bullish = (isAccumulation && sweptLow && isDistribution && data[0].close > data[1].close);

      // PO3 Bearish: Acumulación + Sweep de máximos + Distribución bajista
      bool po3Bearish = (isAccumulation && sweptHigh && isDistribution && data[0].close < data[1].close);

      if(po3Bullish || po3Bearish) {
         // Calcular fortaleza basada en volumen y rango
         double strength = 0.6;
         strength += (MathAbs(volumeTrend) / data[0].volume) * 0.2;
         strength += (currentRange / avgRange) * 0.2;
         return MathMin(0.9, strength);
      }

      return 0.0;
   }

   string GetPatternDescription() override {
      return "PO3 (Price-Orderflow-Obstacles): Acumulación, Manipulación (liquidity sweep), Distribución";
   }
};

//+------------------------------------------------------------------+
//| Implementación específica para sub-agente Turtle Soup          |
//+------------------------------------------------------------------+
class CTurtleSoupSubAgent : public CSubAgent {
public:
   CTurtleSoupSubAgent() : CSubAgent("TURTLE_SOUP") {
      Configure(0.65, 25, 21);
   }

   double AnalyzePattern(const MarketData &data[], int count) override {
      if(count < 10) return 0.0;

      // Encontrar el máximo y mínimo de las últimas 5 barras
      double recentHigh = data[0].high;
      double recentLow = data[0].low;

      for(int i = 1; i < 5 && i < count; i++) {
         if(data[i].high > recentHigh) recentHigh = data[i].high;
         if(data[i].low < recentLow) recentLow = data[i].low;
      }

      // Verificar si el precio ha roto estos niveles pero ha regresado
      bool brokeHigh = false;
      bool brokeLow = false;
      bool returnedFromHigh = false;
      bool returnedFromLow = false;

      // Buscar ruptura y retorno en las últimas 10 barras
      for(int i = 0; i < 10 && i < count; i++) {
         if(data[i].high > recentHigh && i < 5) {
            brokeHigh = true;
            // Verificar si ha retornado por debajo del nivel
            if(data[0].close < recentHigh) {
               returnedFromHigh = true;
            }
         }

         if(data[i].low < recentLow && i < 5) {
            brokeLow = true;
            // Verificar si ha retornado por encima del nivel
            if(data[0].close > recentLow) {
               returnedFromLow = true;
            }
         }
      }

      // Turtle Soup Bullish: Ruptura de mínimo + retorno
      bool turtleSoupBullish = (brokeLow && returnedFromLow);

      // Turtle Soup Bearish: Ruptura de máximo + retorno
      bool turtleSoupBearish = (brokeHigh && returnedFromHigh);

      if(turtleSoupBullish || turtleSoupBearish) {
         // Calcular fortaleza basada en distancia al nivel y volumen
         double strength = 0.6;
         if(turtleSoupBullish) {
            strength += (data[0].close - recentLow) / (recentHigh - recentLow) * 0.3;
         } else {
            strength += (recentHigh - data[0].close) / (recentHigh - recentLow) * 0.3;
         }
         return MathMin(0.9, strength);
      }

      return 0.0;
   }

   string GetPatternDescription() override {
      return "Turtle Soup: Ruptura falsa de soporte/resistencia seguida de retorno";
   }
};

//+------------------------------------------------------------------+
//| Implementación específica para sub-agente Fibonacci            |
//+------------------------------------------------------------------+
class CFibonacciSubAgent : public CSubAgent {
private:
   double m_fibLevels[6];

public:
   CFibonacciSubAgent() : CSubAgent("FIBONACCI") {
      Configure(0.60, 30, 0);
      ArrayInitialize(m_fibLevels, 0.0);
   }

   double AnalyzePattern(const MarketData &data[], int count) override {
      if(count < 15) return 0.0;

      // Encontrar swing alto y bajo para Fibonacci
      int highIndex = ArrayMaximum(data, 0, 15);
      int lowIndex = ArrayMinimum(data, 0, 15);

      double swingHigh = data[highIndex].high;
      double swingLow = data[lowIndex].low;

      if(swingHigh <= swingLow) return 0.0;

      double range = swingHigh - swingLow;
      m_fibLevels[0] = swingLow;           // 0.0
      m_fibLevels[1] = swingLow + range * 0.236; // 23.6%
      m_fibLevels[2] = swingLow + range * 0.382; // 38.2%
      m_fibLevels[3] = swingLow + range * 0.5;   // 50.0%
      m_fibLevels[4] = swingLow + range * 0.618; // 61.8%
      m_fibLevels[5] = swingHigh;          // 100.0%

      double currentPrice = data[0].close;
      double nearestLevel = 0.0;
      double minDistance = 1000000.0;

      // Encontrar nivel Fibonacci más cercano
      for(int i = 1; i < 5; i++) { // Excluir extremos 0% y 100%
         double distance = MathAbs(currentPrice - m_fibLevels[i]);
         if(distance < minDistance) {
            minDistance = distance;
            nearestLevel = m_fibLevels[i];
         }
      }

      // Verificar si está cerca de un nivel importante (38.2% o 61.8%)
      double priceRange = swingHigh - swingLow;
      double threshold = priceRange * 0.01; // 1% del rango

      if(minDistance < threshold) {
         // Verificar confirmación con volumen y direccionalidad
         bool volumeConfirmation = (data[0].volume > data[1].volume * 1.5);
         bool directionalConfirmation = false;

         if(nearestLevel == m_fibLevels[2]) { // 38.2%
            // Buscar reversión alcista
            directionalConfirmation = (data[0].close > data[0].open &&
                                      data[1].close < data[1].open);
         } else if(nearestLevel == m_fibLevels[4]) { // 61.8%
            // Buscar reversión bajista
            directionalConfirmation = (data[0].close < data[0].open &&
                                      data[1].close > data[1].open);
         }

         if(volumeConfirmation && directionalConfirmation) {
            return 0.8;
         } else if(volumeConfirmation || directionalConfirmation) {
            return 0.7;
         }
      }

      return 0.0;
   }

   string GetPatternDescription() override {
      return "Niveles Fibonacci: Reversiones en niveles 38.2%, 50%, 61.8%";
   }
};

//+------------------------------------------------------------------+
//| Implementación específica para sub-agente Liquidity            |
//+------------------------------------------------------------------+
class CLiquiditySubAgent : public CSubAgent {
private:
   double m_liquidityZones[10];
   int m_zoneCount;

public:
   CLiquiditySubAgent() : CSubAgent("LIQUIDITY") {
      Configure(0.80, 10, 5);
      m_zoneCount = 0;
      ArrayInitialize(m_liquidityZones, 0.0);
   }

   double AnalyzePattern(const MarketData &data[], int count) override {
      if(count < 20) return 0.0;

      // Identificar zonas de liquidez (máximos y mínimos recientes)
      m_zoneCount = 0;

      // Encontrar los 5 máximos más altos (Equal Highs - EQH)
      double highs[100];
      for(int i = 0; i < 20 && i < count; i++) {
         highs[i] = data[i].high;
      }

      for(int i = 0; i < 3 && m_zoneCount < 10; i++) {
         int highIndex = 0;
         double maxValue = highs[0];

         for(int j = 1; j < 20 && j < count; j++) {
            if(highs[j] > maxValue) {
               maxValue = highs[j];
               highIndex = j;
            }
         }

         if(maxValue > 0 && (m_zoneCount == 0 || MathAbs(maxValue - m_liquidityZones[m_zoneCount-1]) > data[0].atr * 0.2)) {
            m_liquidityZones[m_zoneCount++] = maxValue;
         }

         highs[highIndex] = 0.0; // Marcar para no seleccionar de nuevo
      }

      // Encontrar los 5 mínimos más bajos (Equal Lows - EQL)
      double lows[100];
      for(int i = 0; i < 20 && i < count; i++) {
         lows[i] = data[i].low;
      }

      for(int i = 0; i < 3 && m_zoneCount < 10; i++) {
         int lowIndex = 0;
         double minValue = lows[0];

         for(int j = 1; j < 20 && j < count; j++) {
            if(lows[j] < minValue) {
               minValue = lows[j];
               lowIndex = j;
            }
         }

         if(minValue > 0 && (m_zoneCount == 0 || MathAbs(minValue - m_liquidityZones[m_zoneCount-1]) > data[0].atr * 0.2)) {
            m_liquidityZones[m_zoneCount++] = minValue;
         }

         lows[lowIndex] = 1000000.0; // Marcar para no seleccionar de nuevo
      }

      // Verificar si estamos en una zona de liquidez
      double currentPrice = data[0].close;
      double nearestZone = 0.0;
      double minDistance = 1000000.0;

      for(int i = 0; i < m_zoneCount; i++) {
         double distance = MathAbs(currentPrice - m_liquidityZones[i]);
         if(distance < minDistance) {
            minDistance = distance;
            nearestZone = m_liquidityZones[i];
         }
      }

      // Verificar sweep de liquidez
      bool liquiditySweep = false;
      double sweepStrength = 0.0;

      if(minDistance < data[0].atr * 0.3) {
         // Verificar si el precio barrió la zona y regresó
         for(int i = 1; i < 5 && i < count; i++) {
            if(data[i].high > nearestZone && data[i].low < nearestZone) {
               // La vela atravesó la zona
               if((data[i].close > nearestZone && data[i-1].close < nearestZone) ||
                  (data[i].close < nearestZone && data[i-1].close > nearestZone)) {
                  liquiditySweep = true;
                  sweepStrength = (MathAbs(data[i].high - data[i].low) / data[0].atr) * 0.5;
                  break;
               }
            }
         }
      }

      if(liquiditySweep) {
         // Calcular confianza basada en volatilidad y volumen
         double confidence = 0.7 + sweepStrength;
         confidence += (data[0].volume / CalculateAverageVolume(data, 5)) * 0.1;
         return MathMin(0.95, confidence);
      }

      return 0.0;
   }

   double CalculateAverageVolume(const MarketData &data[], int period) {
      double sum = 0.0;
      int count = MathMin(period, 99);

      for(int i = 0; i < count; i++) {
         sum += data[i].volume;
      }

      return sum / MathMax(count, 1);
   }

   string GetPatternDescription() override {
      return "Zonas de Liquidez: Sweeps de Equal Highs/Lows y reversiones";
   }
};

#endif // SUB_AGENT_MQH