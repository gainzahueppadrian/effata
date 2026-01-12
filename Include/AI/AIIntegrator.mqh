//+------------------------------------------------------------------+
//| AIIntegrator.mqh                                                 |
//| Integration with LLMs (OpenAI, DeepSeek, Gemini, etc.)           |
//+------------------------------------------------------------------+
#property copyright "2025, Advanced AI Trading Systems"
#property strict

#ifndef AI_INTEGRATOR_MQH
#define AI_INTEGRATOR_MQH

#include <WebRequest.mqh>
#include "../Core/AI_JSON_FILE.mqh"
#include "../Core/SocketClient.mqh"
#include "../Core/Structures.mqh"

class CAIIntegrator {
private:
   CSocketClient *m_socket;

public:
   CAIIntegrator() {
      m_socket = new CSocketClient("127.0.0.1", 5555);
   }

   ~CAIIntegrator() {
      if(CheckPointer(m_socket) == POINTER_DYNAMIC) delete m_socket;
   }

   string GetAnalysisFromModel(string modelName, string prompt) {
      // Map model names if necessary
      string targetModel = modelName;
      if(modelName == "gpt-4") targetModel = "chatgpt-4o-latest-20250326";
      if(modelName == "deepseek-v3") targetModel = "deepseek-chat";
      if(modelName == "deepseek-v3.2") targetModel = "deepseek-v3.2";
      if(modelName == "grok-4.20") targetModel = "grok-4.20";

      return CallPythonServer(targetModel, prompt);
   }

   // New: News Analysis Support
   string GetNewsAnalysis(string symbol) {
      JsonValue root(JsonObject, "");
      root["action"]->operator=("analyze_news");
      root["symbol"]->operator=(symbol);

      string request = root.SerializeToString();
      string response = "";
      if(m_socket->SendAndReceive(request, response)) {
         return response; // Caller parses JSON
      }
      return "";
   }

   // New: Sentiment Analysis Support
   string GetSentimentAnalysis(string symbol) {
      JsonValue root(JsonObject, "");
      root["action"]->operator=("analyze_sentiment");
      root["symbol"]->operator=(symbol);

      string request = root.SerializeToString();
      string response = "";
      if(m_socket->SendAndReceive(request, response)) {
         return response; // Caller parses JSON
      }
      return "";
   }

   // New: Chart Analysis Support (Agentic Browser)
   string AnalyzeChart(string symbol, string timeframe) {
       JsonValue root(JsonObject, "");
       root["action"]->operator=("analyze_chart");
       root["model"]->operator=("deepseek-v3"); // Default to DeepSeek as requested

       string prompt = "You are a Professional Hedge Fund like Goldman Sachs, analize the chart in high timeframes for determine Directional Bias for 4 hours, daily, 2 weeks, montly and Low timeframes and recommend Trading actions for " + symbol + " and connect with RLEnvironment.mqh";
       root["prompt"]->operator=(prompt);

       string request = root.SerializeToString();
       string response = "";
       // Blocking call - use sparingly!
       if(m_socket->SendAndReceive(request, response)) {
           return response;
       }
       return "";
   }

   string CallPythonServerRaw(string model, string prompt) {
      JsonValue root(JsonObject, "");
      // operator[] returns pointer to child, assume it creates if not exists
      // However, AI_JSON_FILE implementation of operator[] might return pointer.
      // Safe way:
      root["action"]->operator=("analyze_chart");
      root["model"]->operator=(model);
      root["prompt"]->operator=(prompt);

      string request = root.SerializeToString();
      string response = "";

      if(m_socket->SendAndReceive(request, response)) {
          return response;
      }
      return "";
   }

   string CallPythonServer(string model, string prompt) {
      string response = CallPythonServerRaw(model, prompt);
      if(response == "") return "";

      char respChar[];
      StringToCharArray(response, respChar);
      JsonValue jsonResp;
      int index = 0;
      int len = ArraySize(respChar);

      if(jsonResp.DeserializeFromArray(respChar, len, index)) {
          JsonValue *statusVal = jsonResp["status"];
          string status = (CheckPointer(statusVal) != POINTER_INVALID) ? statusVal->ToString() : "";

          if(status == "success") {
              JsonValue *data = jsonResp["data"];
              if(CheckPointer(data) != POINTER_INVALID) {
                  JsonValue *raw = data->Find("raw_response"); // FindChildByKey in header? Assuming Find is wrapper or use []
                  if(CheckPointer(raw) == POINTER_INVALID) raw = data->operator[]("raw_response"); // Try operator

                  if(CheckPointer(raw) != POINTER_INVALID) return raw->ToString();
              }
              // Fallback
              JsonValue *rootRaw = jsonResp["raw_response"];
              if(CheckPointer(rootRaw) != POINTER_INVALID) return rootRaw->ToString();
          } else {
              JsonValue *msg = jsonResp["message"];
              Print("AI Server Error: ", (CheckPointer(msg) != POINTER_INVALID) ? msg->ToString() : "Unknown");
          }
      }
      return "";
   }

   TradeDecision GetDecisionFromModel(string model, string prompt) {
       TradeDecision decision;
       decision.Initialize();

       string targetModel = model;
       if(model == "gpt-4") targetModel = "chatgpt-4o-latest-20250326";

       string response = CallPythonServerRaw(targetModel, prompt);
       if(response == "") return decision;

       char respChar[];
       StringToCharArray(response, respChar);
       JsonValue jsonResp;
       int index = 0;
       int len = ArraySize(respChar);

       if(jsonResp.DeserializeFromArray(respChar, len, index)) {
           JsonValue *statusVal = jsonResp["status"];
           string status = (CheckPointer(statusVal) != POINTER_INVALID) ? statusVal->ToString() : "";

           if(status == "success") {
               JsonValue *data = jsonResp["data"];
               if(CheckPointer(data) != POINTER_INVALID) {
                   JsonValue *signal = data->Find("signal"); // Assuming Find or []
                   if(CheckPointer(signal) == POINTER_INVALID) signal = data->operator[]("signal");

                   if(CheckPointer(signal) != POINTER_INVALID) {
                       JsonValue *act = signal->Find("action");
                       if(CheckPointer(act) == POINTER_INVALID) act = signal->operator[]("action");

                       JsonValue *conf = signal->Find("confidence");
                       if(CheckPointer(conf) == POINTER_INVALID) conf = signal->operator[]("confidence");

                       JsonValue *sl = signal->Find("stop_loss");
                       if(CheckPointer(sl) == POINTER_INVALID) sl = signal->operator[]("stop_loss");

                       JsonValue *tp = signal->Find("take_profit");
                       if(CheckPointer(tp) == POINTER_INVALID) tp = signal->operator[]("take_profit");

                       string actStr = (CheckPointer(act) != POINTER_INVALID) ? act->ToString() : "";

                       if(actStr == "BUY") decision.action = BUY_SIGNAL;
                       else if(actStr == "SELL") decision.action = SELL_SIGNAL;
                       else decision.action = NO_SIGNAL;

                       decision.confidence = (CheckPointer(conf) != POINTER_INVALID) ? conf->ToDouble() : 0.0;
                       decision.stopLoss = (CheckPointer(sl) != POINTER_INVALID) ? sl->ToDouble() : 0.0;
                       decision.takeProfit = (CheckPointer(tp) != POINTER_INVALID) ? tp->ToDouble() : 0.0;
                   }
               }
           }
       }
       return decision;
   }

   string CallOpenAI(string model, string prompt) {
       return CallPythonServer(model, prompt);
   }

   string CallDeepSeek(string prompt) {
       return CallPythonServer("deepseek-chat", prompt);
   }
};
#endif // AI_INTEGRATOR_MQH
