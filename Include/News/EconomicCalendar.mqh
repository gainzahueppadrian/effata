//+------------------------------------------------------------------+
//| EconomicCalendar.mqh                                             |
//| Wrapper for Economic Calendar Data                               |
//+------------------------------------------------------------------+
#property copyright "Effata Trading Systems"
#property strict

#include <Arrays/ArrayObj.mqh>

enum ENUM_IMPACT_LEVEL {
    IMPACT_NONE = 0,
    IMPACT_LOW = 1,
    IMPACT_MEDIUM = 2,
    IMPACT_HIGH = 3
};

class CEconomicCalendar {
public:
    CEconomicCalendar() {}
    ~CEconomicCalendar() {}

    void Initialize() {}

    // MQL5 native Calendar functions wrapper
    bool IsNewsImminent(string symbol, int bufferMinutes, int &minutesToNews, ENUM_IMPACT_LEVEL &impact) {
        #ifdef __MQL5__
        MqlCalendarValue values[];
        datetime startTime = TimeCurrent();
        datetime endTime = startTime + bufferMinutes * 60;

        string currency = StringSubstr(symbol, 0, 3); // Base
        string currency2 = StringSubstr(symbol, 3, 3); // Quote

        // Check for Base Currency News
        if (CalendarValueHistoryByEvent(0, values, startTime, endTime)) {
             for(int i=0; i<ArraySize(values); i++) {
                 long eventId = values[i].event_id;
                 MqlCalendarEvent event;
                 if(CalendarEventById(eventId, event)) {
                     if(StringFind(event.currency, currency) >= 0 || StringFind(event.currency, currency2) >= 0) {
                         if(event.importance >= CALENDAR_IMPORTANCE_HIGH) {
                             impact = IMPACT_HIGH;
                             minutesToNews = (int)((values[i].time - TimeCurrent()) / 60);
                             return true;
                         }
                     }
                 }
             }
        }
        #endif
        // MQL4 fallback or no news found
        impact = IMPACT_NONE;
        return false;
    }

    string GetNextEventName(string symbol) {
        #ifdef __MQL5__
        // Simplified for brevity
        return "Upcoming News";
        #endif
        return "";
    }
};
