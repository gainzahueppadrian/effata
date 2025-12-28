//+------------------------------------------------------------------+
//| EconomicCalendar.mqh                                            |
//| Economic Calendar Integration and Analysis                     |
//| Copyright 2025, Reinforcement Learning Trading Systems          |
//+------------------------------------------------------------------+
#property copyright "2025, RL Trading Systems"
#property link      "https://www.mql5.com"
#property version   "1.5"
#property strict

#ifndef ECONOMIC_CALENDAR_MQH
#define ECONOMIC_CALENDAR_MQH

#include <WebRequest.mqh>
#include "../Core/AI_JSON_FILE.mqh"

struct EconomicEvent {
   datetime time;
   string currency;
   string title;
   string description;
   string impact;        // "LOW", "MEDIUM", "HIGH", "EXTREME"
   string actual;
   string forecast;
   string previous;
   bool isAllDay;
   string country;
   string source;
   datetime lastUpdated;
};

struct CalendarSources {
   string url;
   string parserType;   // "JSON", "HTML", "CSV"
   string apiKey;
   bool isActive;
};

class CEconomicCalendar {
private:
   EconomicEvent m_events[];
   CalendarSources m_sources[5];
   int m_sourceCount;

public:
   CEconomicCalendar() {
      m_sourceCount = 0;
      // Configure sources
      AddSource("https://nfs.faireconomy.media/ff_calendar_thisweek.json", "JSON", "", true); // ForexFactory (Example)
      // AddSource("https://api.tradingeconomics.com/calendar", "JSON", "API_KEY", true);
   }

   void AddSource(string url, string type, string key, bool active) {
      if(m_sourceCount < 5) {
         m_sources[m_sourceCount].url = url;
         m_sources[m_sourceCount].parserType = type;
         m_sources[m_sourceCount].apiKey = key;
         m_sources[m_sourceCount].isActive = active;
         m_sourceCount++;
      }
   }

   bool UpdateCalendar() {
      // Loop through sources and fetch data
      for(int i=0; i<m_sourceCount; i++) {
         if(!m_sources[i].isActive) continue;

         char data[];
         string headers;
         string resultHeaders;

         // Only run if Allowed in Terminal
         if(TerminalInfoInteger(TERMINAL_DLLS_ALLOWED) && TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) {
             int res = WebRequest("GET", m_sources[i].url, headers, 10000, data, resultHeaders);
             if(res == 200) {
                 ParseData(data, m_sources[i].parserType);
                 return true;
             } else {
                 Print("WebRequest failed for ", m_sources[i].url, " Error: ", GetLastError());
             }
         } else {
             // Mock data if WebRequest not allowed/configured
             // Print("WebRequest not allowed. Using mock calendar data.");
             // CreateMockEvents();
             return false;
         }
      }
      return false;
   }

   void ParseData(char &data[], string type) {
       if(type == "JSON") {
           JsonValue json;
           int index = 0;
           int len = ArraySize(data);
           if(json.DeserializeFromArray(data, len, index)) {
               // Parse events
               // Assuming array of objects
               if(json.m_type == JsonArray) {
                   int count = ArraySize(json.m_children);
                   ArrayResize(m_events, count);
                   for(int i=0; i<count; i++) {
                       JsonValue *item = json[i];
                       if(item) {
                           m_events[i].title = (*item)["title"].ToString();
                           m_events[i].impact = (*item)["impact"].ToString();
                           string dateStr = (*item)["date"].ToString();
                           m_events[i].time = StringToTime(dateStr);
                       }
                   }
               }
           }
       }
   }

   EconomicEvent GetNextHighImpactEvent() {
       EconomicEvent evt;
       ZeroMemory(evt);
       datetime now = TimeCurrent();

       for(int i=0; i<ArraySize(m_events); i++) {
           if(m_events[i].time > now && (m_events[i].impact == "High" || m_events[i].impact == "Medium")) {
               return m_events[i];
           }
       }
       return evt;
   }
};
#endif // ECONOMIC_CALENDAR_MQH
