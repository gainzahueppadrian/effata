//+------------------------------------------------------------------+
//| PatternDetectionEnv.mqh                                          |
//| Pattern Detection Environment for EFFATA Orchestrator            |
//| Integrates CRT Theory, CNN Pattern Detection, and PO3/TurtleSoup |
//+------------------------------------------------------------------+
#property copyright "2025, EFFATA Reinforcement Trading Systems"
#property version   "3.20"

#ifndef PATTERN_DETECTION_ENV_MQH
#define PATTERN_DETECTION_ENV_MQH

#include "../Core/Structures.mqh"
#include "../Core/DeepSeekVerification.mqh"
#include "../Patterns/CRTTheory.mqh"
#include "../Neural/CNNPatternDetector.mqh"
#include "../Core/NeuralMemoryController.mqh"
#include "../Core/CompatMQL4.mqh"

class CPatternDetectionEnv {
private:
    CRTTheory *m_crtDetector;
    CCNNPatternDetector *m_cnnDetector;
    CNeuralMemoryController *m_patternMemory;

    // Pattern state
    PatternResult m_lastPattern;
    datetime m_lastUpdate;

public:
    CPatternDetectionEnv() {
        m_crtDetector = new CRTTheory();
        m_cnnDetector = new CCNNPatternDetector();
        m_patternMemory = new CNeuralMemoryController();
        m_lastUpdate = 0;
    }

    ~CPatternDetectionEnv() {
        if(CheckPointer(m_crtDetector) == POINTER_DYNAMIC) delete m_crtDetector;
        if(CheckPointer(m_cnnDetector) == POINTER_DYNAMIC) delete m_cnnDetector;
        if(CheckPointer(m_patternMemory) == POINTER_DYNAMIC) delete m_patternMemory;
    }

    bool Initialize() {
        // Initialize detectors
        if(!m_cnnDetector->Initialize(20)) return false;
        m_cnnDetector->SetNeuralMemory(m_patternMemory);
        return true;
    }

    void UpdateFromTick(const double &features[]) {
        // Only update on new candle or significant tick change
        datetime currentTime = TimeCurrent();
        if(currentTime - m_lastUpdate < 1) return; // 1 second debounce
        m_lastUpdate = currentTime;

        m_patternMemory->UpdateFromTick(); // Fixed (no args, pointer)
    }

    PatternResult DetectPatterns() {
        PatternResult result;
        ZeroMemory(result);
        result.detectionTime = TimeCurrent();

        // Use CNN Detector for advanced patterns
        // We need to pass data to DetectPatterns.
        // Assuming we gather data here or CNN gathers it internally via access to global data or symbol.
        // CCNNPatternDetector::DetectPatterns takes MarketData array.
        // We need to construct it.

        MarketData data[];
        // Populate data from market (Simplified loop)
        int bars = 50;
        ArrayResize(data, bars);
        for(int i=0; i<bars; i++) {
            data[i].open = iOpen(NULL, PERIOD_CURRENT, i);
            data[i].high = iHigh(NULL, PERIOD_CURRENT, i);
            data[i].low = iLow(NULL, PERIOD_CURRENT, i);
            data[i].close = iClose(NULL, PERIOD_CURRENT, i);
            data[i].volume = (double)iVolume(NULL, PERIOD_CURRENT, i);
            data[i].atr = iATR(NULL, PERIOD_CURRENT, 14, i);
            data[i].volatility = (data[i].open > 0) ? (data[i].high - data[i].low) / data[i].open : 0;
            // Note: isInsideBar etc logic should be here or handled inside detector
        }

        PatternDetection cnnResult = m_cnnDetector->DetectPatterns(data, bars);

        // Merge results
        result.crtSignal = cnnResult.crtSignal;
        result.po3Signal = cnnResult.po3Signal;
        result.turtleSoup = cnnResult.turtleSoup;
        result.kissOfDeath = cnnResult.kissOfDeath;
        result.wickPattern = cnnResult.wickPattern;
        result.patternStrength = cnnResult.patternStrength;
        result.confidence = cnnResult.confidence;
        result.detectionTime = cnnResult.detectionTime;

        // Fallback/Augment with CRTTheory if needed
        if(!result.crtSignal) {
             CRTSignal crtSignal = m_crtDetector->Analyze(PERIOD_CURRENT);
             if(crtSignal.signalType != "NONE") {
                 result.crtSignal = true;
                 result.patternStrength = MathMax(result.patternStrength, crtSignal.confidence);
                 result.confidence = MathMax(result.confidence, crtSignal.confidence);
             }
        }

        m_lastPattern = result;
        return result;
    }

    void SelfVerify(const double &features[]) {
        string reasoning;
        TradeDecision dummyDecision;
        dummyDecision.Initialize();

        // Map pattern to decision for verification context
        if(m_lastPattern.crtSignal) {
             // We are not making a full decision here, just verifying the pattern context
             // But VerifyDecision expects a TradeDecision.
             // We'll skip deep verification here or adapt it.
             // For now, let's just log if pattern is weak but marked present
             if(m_lastPattern.confidence < 0.5 && m_lastPattern.patternStrength > 0.8) {
                 Print("⚠️ Pattern integrity warning: High strength but low confidence");
             }
        }
    }

    void ConsolidateMemory() {
        m_patternMemory->ConsolidateMemory();
    }

    void LearnFromTrade(double reward, const MarketContext &context) {
        m_patternMemory->LearnFromTrade(); // Fixed (no args, pointer)
    }

    void OnSessionChange(const MarketContext &context) {
        // Adjust sensitivity based on session
        string session = context.sessionType;
        if(session == "ASIA") {
            // Higher threshold for patterns in Asia due to lower volume
             m_crtDetector->SetParameters(14, 2.0, 0.5, 3);
        } else {
             m_crtDetector->SetParameters(14, 1.5, 0.5, 2);
        }
    }

private:
    bool CheckTurtleSoup() {
        // Simplified Turtle Soup detection (Sweep of highs/lows)
        double high[] = {0,0,0,0,0};
        double low[] = {0,0,0,0,0};
        CopyHigh(_Symbol, PERIOD_CURRENT, 0, 5, high);
        CopyLow(_Symbol, PERIOD_CURRENT, 0, 5, low);

        // Check for sweep of previous high
        if(high[1] > high[2] && iClose(_Symbol, PERIOD_CURRENT, 1) < high[2]) {
             return true; // Bearish Turtle Soup
        }
        // Check for sweep of previous low
        if(low[1] < low[2] && iClose(_Symbol, PERIOD_CURRENT, 1) > low[2]) {
             return true; // Bullish Turtle Soup
        }
        return false;
    }

    bool CheckPO3() {
        // Power of 3 requires longer context (AMD)
        // Placeholder logic
        return false;
    }
};
#endif // PATTERN_DETECTION_ENV_MQH
