//+------------------------------------------------------------------+
//| MultiAccountManagerEnv.mqh                                       |
//| Multi-Account Manager & Trade Copier Environment                 |
//| Copyright 2025, EFFATA Reinforcement Trading Systems             |
//+------------------------------------------------------------------+
#property copyright "2025, EFFATA Reinforcement Trading Systems"
#property version   "1.00"
#property strict

#include "../Core/Structures.mqh"
#include "../Core/SocketClient.mqh"
#include "../Core/AI_JSON_FILE.mqh"
#include "../Trade/TradeManager.mqh"
#include "../Reports/PerformanceReporter.mqh"
#include "../Environments/RiskManagementEnv.mqh"

enum ENUM_COPY_MODE {
   MODE_STANDALONE = 0,
   MODE_LEADER = 1,
   MODE_FOLLOWER = 2
};

struct RemoteTrade {
   string symbol;
   int type; // ORDER_TYPE_BUY/SELL
   double volume;
   double price;
   double sl;
   double tp;
   string comment;
   string trade_id;
   datetime timestamp;
};

class CMultiAccountManagerEnv {
private:
   ENUM_COPY_MODE m_mode;
   CSocketClient *m_socket;
   CTradeManager *m_tradeManager;
   CRiskManagementEnv *m_riskEnv;
   CPerformanceReporter *m_reporter;

   string m_leaderName;
   double m_followerMultiplier;
   datetime m_lastPollTime;
   double m_lastSyncTimestamp;

   // Cache for duplicate check
   string m_processedTrades[];

public:
   CMultiAccountManagerEnv() {
      m_mode = MODE_STANDALONE;
      m_socket = new CSocketClient("127.0.0.1", 5555);
      m_lastPollTime = 0;
      m_lastSyncTimestamp = 0;
      m_followerMultiplier = 1.0;
   }

   ~CMultiAccountManagerEnv() {
      if(CheckPointer(m_socket) == POINTER_DYNAMIC) delete m_socket;
   }

   void Initialize(CTradeManager *tm, CRiskManagementEnv *risk, CPerformanceReporter *reporter) {
      m_tradeManager = tm;
      m_riskEnv = risk;
      m_reporter = reporter;
   }

   void SetMode(ENUM_COPY_MODE mode, double multiplier = 1.0) {
      m_mode = mode;
      m_followerMultiplier = multiplier;
      PrintFormat("MultiAccountManager Mode Set: %s", EnumToString(mode));
   }

   //+------------------------------------------------------------------+
   //| LEADER: Broadcast Trade to Cloud                                 |
   //+------------------------------------------------------------------+
   void BroadcastTrade(const TradeRecord &trade) {
      if(m_mode != MODE_LEADER) return;

      JsonValue root(JsonObject, "");
      root["action"]->operator=("broadcast_trade");

      JsonValue *data = root["trade_data"]; // Auto-create object
      data->operator[]("symbol")->operator=(trade.symbol);
      data->operator[]("type")->operator=(trade.direction == 1 ? (long)ORDER_TYPE_BUY : (long)ORDER_TYPE_SELL);
      data->operator[]("volume")->operator=(trade.volume);
      data->operator[]("price")->operator=(trade.entryPrice);
      data->operator[]("sl")->operator=(trade.stopLoss);
      data->operator[]("tp")->operator=(trade.takeProfit);
      data->operator[]("comment")->operator=("CopyTrade_" + IntegerToString((long)TimeCurrent()));
      data->operator[]("timestamp")->operator=((double)TimeCurrent()); // Python expects double/float for time often

      string request = root.SerializeToString();
      string response = "";

      if(m_socket->SendAndReceive(request, response)) {
         Print("Trade Broadcasted Successfully.");
      } else {
         Print("Failed to broadcast trade.");
      }
   }

   //+------------------------------------------------------------------+
   //| FOLLOWER: Update Loop (Call in OnTick or Timer)                 |
   //+------------------------------------------------------------------+
   void Update() {
      if(m_mode != MODE_FOLLOWER) return;

      // Poll every 1 second
      if(TimeCurrent() - m_lastPollTime < 1) return;
      m_lastPollTime = TimeCurrent();

      PollTrades();
   }

   //+------------------------------------------------------------------+
   //| FOLLOWER: Poll for new trades                                    |
   //+------------------------------------------------------------------+
   void PollTrades() {
      JsonValue root(JsonObject, "");
      root["action"]->operator=("get_latest_trades");
      root["last_timestamp"]->operator=(m_lastSyncTimestamp);

      string request = root.SerializeToString();
      string response = "";

      if(m_socket->SendAndReceive(request, response)) {
         ProcessResponse(response);
      }
   }

   //+------------------------------------------------------------------+
   //| FOLLOWER: Process Server Response                                |
   //+------------------------------------------------------------------+
   void ProcessResponse(string jsonResponse) {
      char respChar[];
      StringToCharArray(jsonResponse, respChar);
      JsonValue jsonResp;
      int index = 0;
      int len = ArraySize(respChar);

      if(!jsonResp.DeserializeFromArray(respChar, len, index)) return;

      JsonValue *status = jsonResp["status"];
      if(CheckPointer(status) == POINTER_INVALID || status->ToString() != "success") return;

      JsonValue *serverTime = jsonResp["server_time"];
      if(CheckPointer(serverTime) != POINTER_INVALID) {
         // Update sync time but keep a small buffer to avoid missing simultaneous trades?
         // Actually better to track by trade IDs, but timestamp is okay for now.
         double sTime = serverTime->ToDouble();
         if(sTime > m_lastSyncTimestamp) m_lastSyncTimestamp = sTime;
      }

      JsonValue *trades = jsonResp["trades"];
      if(CheckPointer(trades) != POINTER_INVALID && trades->IsArray()) {
         int total = trades->Count();
         for(int i = 0; i < total; i++) {
            JsonValue *t = trades->operator[](i);
            ExecuteRemoteTrade(t);
         }
      }
   }

   //+------------------------------------------------------------------+
   //| FOLLOWER: Execute Trade                                          |
   //+------------------------------------------------------------------+
   void ExecuteRemoteTrade(JsonValue *tradeJson) {
      if(CheckPointer(tradeJson) == POINTER_INVALID) return;

      // Extract details
      string tradeId = tradeJson->operator[]("trade_id")->ToString();

      // Check duplicate
      if(IsTradeProcessed(tradeId)) return;

      string symbol = tradeJson->operator[]("symbol")->ToString();
      long type = tradeJson->operator[]("type")->ToInt();
      double vol = tradeJson->operator[]("volume")->ToDouble();
      double sl = tradeJson->operator[]("sl")->ToDouble();
      double tp = tradeJson->operator[]("tp")->ToDouble();
      double price = tradeJson->operator[]("price")->ToDouble(); // Entry price of leader

      // Calculate Follower Volume
      double myVol = vol * m_followerMultiplier;

      // Risk Check
      if(m_riskEnv != NULL) {
         RiskAssessment risk = m_riskEnv->AssessCurrentRisk();
         if(!risk.allowTrading) {
            PrintFormat("Copy Trade Ignored due to Risk Management: %s", symbol);
            MarkTradeProcessed(tradeId); // Skip it so we don't retry forever
            return;
         }

         // Optional: Scale volume based on riskEnv recommendation if implemented
      }

      // Trade Manager Check
      if(m_tradeManager != NULL) {
         if(!m_tradeManager->CanTrade()) {
             Print("Copy Trade Ignored: TradeManager CanTrade() == false");
             MarkTradeProcessed(tradeId);
             return;
         }

         // Execute
         // Note: We use market orders usually for copying to ensure fill,
         // unless it's a pending order.
         // Leader price is reference. Slippage check could be added.

         bool result = m_tradeManager->PlaceOrder(
            (ENUM_ORDER_TYPE)type,
            myVol,
            0.0, // 0.0 for market execution usually, or use Ask/Bid inside TradeManager
            sl,
            tp,
            "Copy:" + tradeId
         );

         if(result) {
            PrintFormat("Copied Trade: %s %s Vol: %.2f", symbol, EnumToString((ENUM_ORDER_TYPE)type), myVol);

            // Journaling (TradeManager handles execution, but we might want to log specifically copy event)
            if(m_reporter != NULL) {
               // TradeManager usually tracks open positions.
               // Reporter adds record on CLOSE.
               // So we rely on standard reporting flow.
            }
         }
      }

      MarkTradeProcessed(tradeId);
   }

   bool IsTradeProcessed(string id) {
      for(int i=0; i<ArraySize(m_processedTrades); i++) {
         if(m_processedTrades[i] == id) return true;
      }
      return false;
   }

   void MarkTradeProcessed(string id) {
      int s = ArraySize(m_processedTrades);
      ArrayResize(m_processedTrades, s+1);
      m_processedTrades[s] = id;

      // Cleanup old history if needed
      if(s > 1000) {
          ArrayRemove(m_processedTrades, 0, 100);
      }
   }
};
