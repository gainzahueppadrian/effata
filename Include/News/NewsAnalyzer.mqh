//+------------------------------------------------------------------+
//| NewsAnalyzer.mqh                                                |
//| News Analysis System                                            |
//| Copyright 2025, Reinforcement Learning Trading Systems          |
//+------------------------------------------------------------------+
#property copyright "2025, RL Trading Systems"
#property link      "https://www.mql5.com "
#property version   "1.00"
#property strict

#include "EconomicEvent.mqh"

class NewsAnalyzer {
private:
    EconomicEvent events[];
    datetime lastUpdate;
    string apiKey;

public:
    NewsAnalyzer(string apiKey) {
        this.apiKey = apiKey;
        ArrayResize(events, 0);
        lastUpdate = 0;
    }
void UpdateCalendar() {
    if(GetTickCount() - lastUpdate > 3600000) { // Actualizar cada hora
        FetchEconomicCalendar();
        lastUpdate = GetTickCount();
    }
}

EconomicEvent[] GetUpcomingEvents(int hoursAhead=24) {
    UpdateCalendar();
    datetime now = TimeCurrent();
    datetime endTime = now + hoursAhead * 3600;

    EconomicEvent filtered[];
    int count = 0;

    for(int i = 0; i < ArraySize(events); i++) {
        if(events[i].eventTime >= now && events[i].eventTime <= endTime) {
            int size = ArraySize(filtered);
            ArrayResize(filtered, size + 1);
            filtered[size] = events[i];
            count++;
        }
    }

    return filtered;
}

double GetMarketImpactScore() {
    EconomicEvent todayEvents[] = GetUpcomingEvents(24);
    double impactScore = 0.0;

    for(int i = 0; i < ArraySize(todayEvents); i++) {
        if(todayEvents[i].impactLevel >= 2) {
            double timeFactor = 1.0 - (double)(todayEvents[i].eventTime - TimeCurrent()) / 86400;
            impactScore += todayEvents[i].impactLevel * timeFactor;
        }
    }

    return MathMin(10.0, impactScore); // Normalizar a escala 0-10
}

private:
    void FetchEconomicCalendar() {
        // Implementación simplificada - en producción usar API real
        // Aquí simulamos eventos económicos importantes
        ArrayResize(events, 0);
    // Simular eventos para las próximas 24 horas
    datetime now = TimeCurrent();
    for(int i = 0; i < 5; i++) {
        EconomicEvent event;
        event.eventName = "Simulated Event " + (string)i;
        event.currency = (i % 2 == 0) ? "USD" : "EUR";
        event.eventTime = now + (i * 4 + 1) * 3600;
        event.actualValue = 0.0;
        event.forecastValue = 0.0;
        event.previousValue = 0.0;
        event.impactLevel = (i < 2) ? 3 : (i < 4 ? 2 : 1);
        event.isReleased = false;

        int size = ArraySize(events);
        ArrayResize(events, size + 1);
        events[size] = event;
    }
}

};