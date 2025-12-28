//+------------------------------------------------------------------+
//| SessionAnalyzer.mqh                                           |
//| Forex Session Analysis System                                   |
//| Copyright 2025, Reinforcement Learning Trading Systems          |
//+------------------------------------------------------------------+
#property copyright "2025, RL Trading Systems"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include "../Core/CompatMQL4.mqh"

//+------------------------------------------------------------------+
//| Session Information Structure                                    |
//+------------------------------------------------------------------+
struct SessionInfo {
    string sessionType;         // "ASIA", "LONDON", "NY", "OVERLAP", "NONE"
    datetime startTime;         // Hora de inicio de la sesión
    datetime endTime;           // Hora de fin de la sesión
    double volatilityFactor;    // Factor de volatilidad (1.0 = normal)
    bool isOverlap;             // Si es período de superposición
    double volumeProfile;       // Perfil de volumen (0.0-1.0)
};

//+------------------------------------------------------------------+
//| Session Analyzer Class                                           |
//+------------------------------------------------------------------+
class SessionAnalyzer {
private:
    int brokerUTCOffset;
    bool autoDSTAdjustment;
    bool useAsiaSession;
    bool useLondonSession;
    bool useNYSession;
    datetime lastDSTCheck;
    bool isDSTActive;
    double sessionVolatility[3]; // [Asia, London, NY]

public:
    SessionAnalyzer(int utcOffset, bool autoDST) {
        brokerUTCOffset = utcOffset;
        autoDSTAdjustment = autoDST;
        useAsiaSession = true;
        useLondonSession = true;
        useNYSession = true;
        lastDSTCheck = 0;
        isDSTActive = false;

        // Valores por defecto de volatilidad
        sessionVolatility[0] = 0.7; // Asia
        sessionVolatility[1] = 1.2; // London
        sessionVolatility[2] = 1.5; // NY
    }

    void ConfigureSessions(bool asia, bool london, bool ny) {
        useAsiaSession = asia;
        useLondonSession = london;
        useNYSession = ny;
    }

    SessionInfo GetCurrentSession() {
        SessionInfo session = {"NONE", 0, 0, 1.0, false, 0.0};

        // Verificar y actualizar DST si es necesario
        if(autoDSTAdjustment && GetTickCount() - lastDSTCheck > 3600000) { // Cada hora
            UpdateDSTStatus();
            lastDSTCheck = GetTickCount();
        }

        MqlDateTime currentTime;
        TimeCurrent(currentTime);

        // Ajustar hora actual por offset del broker y DST
        int totalOffset = brokerUTCOffset + (isDSTActive ? 1 : 0);
        int currentHour = (currentTime.hour + totalOffset) % 24;

        datetime now = TimeCurrent();

        // Determinar sesión actual
        if(useAsiaSession && currentHour >= 0 && currentHour < 8) {
            session.sessionType = "ASIA";
            session.startTime = now - currentHour * 3600;
            session.endTime = session.startTime + 8 * 3600;
            session.volatilityFactor = sessionVolatility[0];
            session.volumeProfile = 0.4;
        }
        else if(useLondonSession && currentHour >= 7 && currentHour < 16) {
            session.sessionType = "LONDON";
            session.startTime = now - (currentHour - 7) * 3600;
            session.endTime = session.startTime + 9 * 3600;
            session.volatilityFactor = sessionVolatility[1];
            session.volumeProfile = 0.7;

            // Verificar superposición con NY
            if(useNYSession && currentHour >= 12 && currentHour < 16) {
                session.sessionType = "LONDON_NY_OVERLAP";
                session.isOverlap = true;
                session.volatilityFactor *= 1.3; // Mayor volatilidad en superposición
                session.volumeProfile = 0.9;
            }
            // Verificar superposición con Asia
            else if(useAsiaSession && currentHour >= 7 && currentHour < 9) {
                session.sessionType = "ASIA_LONDON_OVERLAP";
                session.isOverlap = true;
                session.volatilityFactor *= 1.2;
                session.volumeProfile = 0.6;
            }
        }
        else if(useNYSession && currentHour >= 12 && currentHour < 21) {
            session.sessionType = "NY";
            session.startTime = now - (currentHour - 12) * 3600;
            session.endTime = session.startTime + 9 * 3600;
            session.volatilityFactor = sessionVolatility[2];
            session.volumeProfile = 0.8;
        }

        // Calcular perfil de volumen basado en hora exacta
        if(session.sessionType != "NONE") {
            double sessionProgress = (double)(now - session.startTime) / (session.endTime - session.startTime);
            session.volumeProfile *= (0.8 + 0.4 * MathSin(MathPi * sessionProgress)); // Curva sinusoidal
        }

        return session;
    }

    bool IsSessionChange() {
        static string lastSession = "";
        SessionInfo currentSession = GetCurrentSession();

        bool sessionChanged = (lastSession != currentSession.sessionType);
        lastSession = currentSession.sessionType;

        return sessionChanged;
    }

    double GetSessionVolatility() {
        SessionInfo session = GetCurrentSession();
        return session.volatilityFactor;
    }

    void UpdateSessionVolatility(ENUM_TIMEFRAMES timeframe) {
        // Actualizar volatilidad de sesiones basado en datos históricos
        for(int i = 0; i < 3; i++) {
            sessionVolatility[i] = CalculateSessionVolatility(i, timeframe);
        }
    }

private:
    void UpdateDSTStatus() {
        // Lógica simplificada para determinar DST
        // En la práctica, esto dependería de la región del broker
        MqlDateTime currentTime;
        TimeCurrent(currentTime);

        // Verificar si estamos en período de DST (ejemplo para Europa/US)
        if((currentTime.mon > 3 && currentTime.mon < 10) ||
           (currentTime.mon == 3 && currentTime.day >= 25) ||
           (currentTime.mon == 10 && currentTime.day <= 25)) {
            isDSTActive = true;
        } else {
            isDSTActive = false;
        }
    }

    double CalculateSessionVolatility(int sessionIndex, ENUM_TIMEFRAMES timeframe) {
        // Calcular volatilidad histórica para cada sesión
        int bars = 20;
        double rangeSum = 0.0;
        int count = 0;

        for(int i = 0; i < bars; i++) {
            MqlDateTime barTime;
            TimeToStruct(iTime(_Symbol, timeframe, i), barTime);

            int hour = (barTime.hour + brokerUTCOffset + (isDSTActive ? 1 : 0)) % 24;

            bool isSession = false;
            if(sessionIndex == 0 && hour >= 0 && hour < 8) isSession = true; // Asia
            if(sessionIndex == 1 && hour >= 7 && hour < 16) isSession = true; // London
            if(sessionIndex == 2 && hour >= 12 && hour < 21) isSession = true; // NY

            if(isSession) {
                double high = iHigh(_Symbol, timeframe, i);
                double low = iLow(_Symbol, timeframe, i);
                rangeSum += high - low;
                count++;
            }
        }

        if(count > 0) {
            double avgRange = rangeSum / count;
            double currentATR = iATR(_Symbol, timeframe, 14, 0);
            return (currentATR > 0) ? avgRange / currentATR : 1.0;
        }

        // Valores por defecto si no hay suficientes datos
        double defaults[3] = {0.7, 1.2, 1.5};
        return defaults[sessionIndex];
    }
};
