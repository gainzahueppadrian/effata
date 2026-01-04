//+------------------------------------------------------------------+
//| AIIntegration.mqh - AI Integration for News & Sentiment          |
//| Connect to ForexFactory, Fed, COT, CPI, NFP, PCE                 |
//| Compatible with MQL5/MQL4                                        |
//+------------------------------------------------------------------+
#property copyright "Effata Trading Systems"
#property strict

#ifndef AIINTEGRATION_MQH
#define AIINTEGRATION_MQH

#include <Arrays/ArrayObj.mqh>
#include <Arrays/ArrayString.mqh>
#include <Arrays/ArrayDouble.mqh>
#include <Files/FileTxt.mqh>
#include "../News/EconomicCalendar.mqh"
#include "../Core/SocketClient.mqh"
#include "../Core/AI_JSON_FILE.mqh"

// Sentiment Sources
enum ENUM_SENTIMENT_SOURCE {
    SENTIMENT_UNKNOWN,
    SENTIMENT_FOREXFACTORY,
    SENTIMENT_INVESTING,
    SENTIMENT_MYFXBOOK,
    SENTIMENT_FACEBOOK,
    SENTIMENT_TWITTER,
    SENTIMENT_REDDIT,
    SENTIMENT_COT,
    SENTIMENT_FED,
    SENTIMENT_CUSTOM
};

// News Impact Level
enum ENUM_NEWS_IMPACT {
    IMPACT_LOW_NI,
    IMPACT_MEDIUM_NI,
    IMPACT_HIGH_NI,
    IMPACT_CRITICAL_NI
};

// Market Sentiment
enum ENUM_MARKET_SENTIMENT {
    SENTIMENT_BULLISH,
    SENTIMENT_BEARISH,
    SENTIMENT_NEUTRAL,
    SENTIMENT_VOLATILE
};

//+------------------------------------------------------------------+
//| SNewsEvent - News Event Data                                     |
//+------------------------------------------------------------------+
class SNewsEvent : public CObject {
public:
    string                   event_id;
    string                   title;
    string                   description;
    string                   country;
    string                   currency;
    ENUM_NEWS_IMPACT         impact;
    datetime                 event_time;
    datetime                 created_time;
    double                   previous_value;
    double                   forecast_value;
    double                   actual_value;
    bool                     is_actual_released;
    double                   surprise_pct;
    bool                     is_positive_surprise;
    string                   source;
    string                   url;

    SNewsEvent() {}
};

//+------------------------------------------------------------------+
//| SSentimentData - Sentiment Analysis Data                         |
//+------------------------------------------------------------------+
class SSentimentData : public CObject {
public:
    ENUM_SENTIMENT_SOURCE    source;
    string                   symbol;
    ENUM_MARKET_SENTIMENT    sentiment;
    double                   sentiment_score;
    int                      bullish_count;
    int                      bearish_count;
    int                      neutral_count;
    int                      total_count;
    double                   long_ratio;
    double                   short_ratio;
    double                   long_short_ratio;
    datetime                 timestamp;
    double                   confidence;
    string                   headline;
    string                   analysis_summary;

    SSentimentData() {}
};

//+------------------------------------------------------------------+
//| SCOTData - COT Report Data                                       |
//+------------------------------------------------------------------+
class SCOTData : public CObject {
public:
    string                   symbol;
    datetime                 report_date;
    string                   market_type;
    double                   commercial_long;
    double                   commercial_short;
    double                   noncommercial_long;
    double                   noncommercial_short;
    double                   retail_long;
    double                   retail_short;
    double                   commercial_net;
    double                   noncommercial_net;
    double                   retail_net;
    double                   total_long;
    double                   total_short;
    double                   net_position_pct;
    double                   sentiment_score;
    bool                     is_extreme;
    ENUM_MARKET_SENTIMENT    interpreted_sentiment;

    SCOTData() {}
};

//+------------------------------------------------------------------+
//| SFedData - Federal Reserve Data                                  |
//+------------------------------------------------------------------+
class SFedData : public CObject {
public:
    string                   indicator_name;
    datetime                 release_date;
    double                   current_value;
    double                   previous_value;
    double                   change_pct;
    bool                     is_positive;
    string                   fed_speaker;
    string                   statement_summary;
    ENUM_NEWS_IMPACT         market_impact;
    double                   historical_volatility;
    double                   implied_movement_pct;

    SFedData() {}
};

//+------------------------------------------------------------------+
//| SAIAnalysisResult - AI Analysis Result                           |
//+------------------------------------------------------------------+
class SAIAnalysisResult : public CObject {
public:
    string                   symbol;
    string                   analysis_type;
    ENUM_MARKET_SENTIMENT    directional_bias;
    double                   confidence;
    double                   entry_price;
    double                   stop_loss;
    double                   take_profit;
    double                   risk_reward_ratio;
    int                      recommended_timeframe;
    string                   reasoning;
    CArrayString             supporting_factors;
    CArrayString             warning_factors;
    double                   sentiment_score;
    double                   volatility_forecast;
    double                   expected_move_pct;
    datetime                 valid_until;

    SAIAnalysisResult() {}
};

//+------------------------------------------------------------------+
//| CAIIntegration - Main AI Integration Class                       |
//+------------------------------------------------------------------+
class CAIIntegration {
private:
    // API Configuration
    string                   m_api_endpoint;
    string                   m_api_key;
    string                   m_secret_key;
    string                   m_model_name;
    bool                     m_use_local_model;

    // Data Storage
    CArrayObj                m_news_cache;
    CArrayObj                m_sentiment_cache;
    CArrayObj                m_cot_cache;
    CArrayObj                m_fed_cache;
    CArrayObj                m_analysis_cache;

    // Current State
    SSentimentData           *m_current_sentiment;
    SNewsEvent               *m_next_high_impact_news;
    SCOTData                 *m_current_cot;
    SFedData                 *m_current_fed;

    // Settings
    int                      m_cache_expiry_minutes;
    int                      m_max_cache_size;
    int                      m_request_timeout_ms;
    bool                     m_auto_refresh;
    int                      m_refresh_interval_minutes;

    // Performance
    datetime                 m_last_update;
    datetime                 m_last_sentiment_update;
    datetime                 m_last_news_update;
    int                      m_request_count;
    int                      m_failed_requests;
    double                   m_avg_response_time_ms;

    // Connection
    bool                     m_connected;
    CSocketClient            *m_socket_client;

    // Economic Calendar Integration
    CEconomicCalendar*       m_economic_calendar;

    // News Sources
    bool                     m_forexfactory_enabled;
    bool                     m_investing_enabled;
    bool                     m_cot_enabled;
    bool                     m_fed_enabled;
    bool                     m_notifications_enabled;

    // Pair Recommendations
    CArrayObj                m_recommended_pairs;

    // AI Model Integration
    bool                     m_deepseek_enabled;
    bool                     m_qwen_enabled;
    bool                     m_claude_enabled;
    string                   m_deepseek_endpoint;
    string                   m_qwen_endpoint;
    string                   m_claude_endpoint;

    // Helper to extract JSON string safely
    string ParseJSONValue(string json, string key) {
        // Simple manual parsing or use existing library if available
        // Assuming user has a robust parser, here we just do basic find
        int pos = StringFind(json, "\"" + key + "\"");
        if(pos < 0) return "";
        int start = StringFind(json, ":", pos) + 1;
        if(start <= 0) return "";

        // Skip whitespace
        while(start < StringLen(json) && (StringSubstr(json, start, 1) == " " || StringSubstr(json, start, 1) == "\"")) start++;

        int end = StringFind(json, "\"", start); // Looking for end quote
        if(end < 0) end = StringFind(json, ",", start);
        if(end < 0) end = StringFind(json, "}", start);
        if(end < 0) return "";

        return StringSubstr(json, start, end - start);
    }

public:
    CAIIntegration();
    ~CAIIntegration();

    // Initialization
    bool                    Initialize();
    bool                    Configure(string config_file);
    bool                    Connect();
    void                    Disconnect();

    // News Methods
    bool                    FetchNewsEvents(string currency, int hours_ahead, CArrayObj &events);
    bool                    ParseNewsEvent(string raw_data, SNewsEvent &event);
    bool                    IsHighImpactNewsImminent(string symbol, int buffer_minutes,
                                                     SNewsEvent &next_event);
    double                  GetNewsImpactModifier(string symbol);
    void                    UpdateNewsCache();
    void                    ClearNewsCache();

    // Sentiment Methods
    bool                    FetchSentimentData(string symbol, SSentimentData &data);
    double                  GetSentimentScore(string symbol);
    ENUM_MARKET_SENTIMENT   GetMarketSentiment(string symbol);
    string                  GetSentimentSource();
    void                    UpdateSentimentCache();
    void                    ClearSentimentCache();

    // COT Methods
    bool                    FetchCOTData(string symbol, SCOTData &data);
    ENUM_MARKET_SENTIMENT   InterpretCOTSentiment(SCOTData &cot);
    bool                    IsCOTExtreme(string symbol);
    double                  GetCOTSentimentScore(string symbol);
    void                    UpdateCOTCache();

    // Fed Methods
    bool                    FetchFedData(string indicator, SFedData &data);
    double                  EstimateFedImpact(string currency);
    void                    UpdateFedCache();

    // AI Analysis Methods
    bool                    AnalyzeMarket(string symbol, SAIAnalysisResult &result);
    bool                    GetTradingRecommendation(string symbol, SAIAnalysisResult &recommendation);
    string                  GenerateAnalysisPrompt(string symbol);
    bool                    ParseAIResponse(string response, SAIAnalysisResult &result);

    // Pair Recommendation Methods
    bool                    GetRecommendedPairs(CArrayObj &pairs);
    double                  CalculatePairScore(string pair, SSentimentData &sentiment,
                                               SNewsEvent &news, SCOTData &cot);
    void                    UpdatePairRecommendations();

    // Browser Integration for AI Analysis
    bool                    RequestAIAnalysis(string symbol, string &response);

    // Socket Communication
    string                  GetAnalysisFromModel(string modelName, string prompt);

    // Getters
    bool                    IsConnected() { return m_connected; }

    // Event Handlers
    void                    OnTick();
    void                    OnTimer();
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CAIIntegration::CAIIntegration() {
    m_api_endpoint = "";
    m_api_key = "";
    m_secret_key = "";
    m_model_name = "deepseek-v3";
    m_use_local_model = false;

    m_cache_expiry_minutes = 60;
    m_max_cache_size = 1000;
    m_request_timeout_ms = 5000;
    m_auto_refresh = true;
    m_refresh_interval_minutes = 15;

    m_last_update = 0;
    m_last_sentiment_update = 0;
    m_last_news_update = 0;
    m_request_count = 0;
    m_failed_requests = 0;
    m_avg_response_time_ms = 0;

    m_connected = false;
    m_socket_client = new CSocketClient("127.0.0.1", 5555);

    m_economic_calendar = NULL;

    m_forexfactory_enabled = true;
    m_investing_enabled = true;
    m_cot_enabled = true;
    m_fed_enabled = true;
    m_notifications_enabled = true;

    m_deepseek_enabled = false;
    m_qwen_enabled = false;
    m_claude_enabled = false;
    m_deepseek_endpoint = "https://api.deepseek.com";
    m_qwen_endpoint = "https://api.qwen.com";
    m_claude_endpoint = "https://api.anthropic.com";

    m_current_sentiment = new SSentimentData();
    m_next_high_impact_news = new SNewsEvent();
    m_current_cot = new SCOTData();
    m_current_fed = new SFedData();
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CAIIntegration::~CAIIntegration() {
    Disconnect();
    if(CheckPointer(m_socket_client) == POINTER_DYNAMIC) delete m_socket_client;
    if(CheckPointer(m_economic_calendar) == POINTER_DYNAMIC) delete m_economic_calendar;
    if(CheckPointer(m_current_sentiment) == POINTER_DYNAMIC) delete m_current_sentiment;
    if(CheckPointer(m_next_high_impact_news) == POINTER_DYNAMIC) delete m_next_high_impact_news;
    if(CheckPointer(m_current_cot) == POINTER_DYNAMIC) delete m_current_cot;
    if(CheckPointer(m_current_fed) == POINTER_DYNAMIC) delete m_current_fed;
}

//+------------------------------------------------------------------+
//| Initialize                                                       |
//+------------------------------------------------------------------+
bool CAIIntegration::Initialize() {
    m_economic_calendar = new CEconomicCalendar();
    m_economic_calendar->Initialize();
    return true;
}

//+------------------------------------------------------------------+
//| Connect                                                          |
//+------------------------------------------------------------------+
bool CAIIntegration::Connect() {
    m_connected = true;
    return true;
}

//+------------------------------------------------------------------+
//| Disconnect                                                       |
//+------------------------------------------------------------------+
void CAIIntegration::Disconnect() {
    m_connected = false;
}

//+------------------------------------------------------------------+
//| Fetch Sentiment Data                                             |
//+------------------------------------------------------------------+
bool CAIIntegration::FetchSentimentData(string symbol, SSentimentData &data) {
    // Send request to Python server
    JsonValue root(JsonObject, "");
    root["action"]->operator=("analyze_sentiment");
    root["symbol"]->operator=(symbol);
    string request = root.SerializeToString();
    string response = "";

    if(m_socket_client->SendAndReceive(request, response)) {
        // Parse response
        data.symbol = symbol;
        data.sentiment_score = StringToDouble(ParseJSONValue(response, "sentiment_score"));
        // ... parse other fields
        // Mock for robustness if server sends partial data
        if(data.sentiment_score > 0.2) data.sentiment = SENTIMENT_BULLISH;
        else if(data.sentiment_score < -0.2) data.sentiment = SENTIMENT_BEARISH;
        else data.sentiment = SENTIMENT_NEUTRAL;

        *m_current_sentiment = data;
        return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//| Get Sentiment Score                                              |
//+------------------------------------------------------------------+
double CAIIntegration::GetSentimentScore(string symbol) {
    SSentimentData data;
    FetchSentimentData(symbol, data);
    return data.sentiment_score;
}

//+------------------------------------------------------------------+
//| Get Market Sentiment                                             |
//+------------------------------------------------------------------+
ENUM_MARKET_SENTIMENT CAIIntegration::GetMarketSentiment(string symbol) {
    SSentimentData data;
    FetchSentimentData(symbol, data);
    return data.sentiment;
}

//+------------------------------------------------------------------+
//| Get Sentiment Source                                             |
//+------------------------------------------------------------------+
string CAIIntegration::GetSentimentSource() {
    return "AI_Consensus";
}

//+------------------------------------------------------------------+
//| Fetch COT Data                                                   |
//+------------------------------------------------------------------+
bool CAIIntegration::FetchCOTData(string symbol, SCOTData &data) {
    // Simulate COT fetch or socket call
    data.symbol = symbol;
    data.net_position_pct = 10.0; // Mock positive COT
    data.is_extreme = false;
    *m_current_cot = data;
    return true;
}

//+------------------------------------------------------------------+
//| Interpret COT Sentiment                                          |
//+------------------------------------------------------------------+
ENUM_MARKET_SENTIMENT CAIIntegration::InterpretCOTSentiment(SCOTData &cot) {
    if(cot.net_position_pct > 15) return SENTIMENT_BULLISH;
    if(cot.net_position_pct < -15) return SENTIMENT_BEARISH;
    return SENTIMENT_NEUTRAL;
}

//+------------------------------------------------------------------+
//| Is High Impact News Imminent                                     |
//+------------------------------------------------------------------+
bool CAIIntegration::IsHighImpactNewsImminent(string symbol, int buffer_minutes,
                                              SNewsEvent &next_event) {
    ENUM_IMPACT_LEVEL impact;
    int minutes;
    if(m_economic_calendar->IsNewsImminent(symbol, buffer_minutes, minutes, impact)) {
        if(impact >= IMPACT_HIGH) {
            next_event.impact = IMPACT_HIGH_NI;
            next_event.title = m_economic_calendar->GetNextEventName(symbol);
            *m_next_high_impact_news = next_event;
            return true;
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| Analyze Market                                                   |
//+------------------------------------------------------------------+
bool CAIIntegration::AnalyzeMarket(string symbol, SAIAnalysisResult &result) {
    string prompt = GenerateAnalysisPrompt(symbol);
    string response = GetAnalysisFromModel("deepseek-v3", prompt);

    // Parse response
    if(StringFind(response, "Bullish") >= 0) result.directional_bias = SENTIMENT_BULLISH;
    else if(StringFind(response, "Bearish") >= 0) result.directional_bias = SENTIMENT_BEARISH;
    else result.directional_bias = SENTIMENT_NEUTRAL;

    result.symbol = symbol;
    result.reasoning = response;
    return true;
}

//+------------------------------------------------------------------+
//| Generate Analysis Prompt                                         |
//+------------------------------------------------------------------+
string CAIIntegration::GenerateAnalysisPrompt(string symbol) {
    return "Analyze " + symbol + " chart H4/D1, Sentiment, and COT. Give Bias (Bullish/Bearish).";
}

//+------------------------------------------------------------------+
//| Get Analysis From Model                                          |
//+------------------------------------------------------------------+
string CAIIntegration::GetAnalysisFromModel(string modelName, string prompt) {
    JsonValue root(JsonObject, "");
    root["action"]->operator=("analyze_chart");
    root["model"]->operator=(modelName);
    root["prompt"]->operator=(prompt);
    string request = root.SerializeToString();
    string response = "";
    if(m_socket_client->SendAndReceive(request, response)) {
        // Extract raw_response
        // We need robust JSON parsing here, simplified for now:
        int start = StringFind(response, "raw_response");
        if(start > 0) {
             start += 15; // "raw_response":" length
             return StringSubstr(response, start, StringLen(response)-start-2);
        }
        return response;
    }
    return "";
}

//+------------------------------------------------------------------+
//| OnTick                                                           |
//+------------------------------------------------------------------+
void CAIIntegration::OnTick() {
    if(!m_connected) return;
    // Auto refresh logic
    if(m_auto_refresh && TimeCurrent() - m_last_update >= m_refresh_interval_minutes * 60) {
        UpdateSentimentCache();
        UpdateNewsCache();
        UpdateCOTCache();
        m_last_update = TimeCurrent();
    }
}

//+------------------------------------------------------------------+
//| Update Methods (Placeholders for real implementation)              |
//+------------------------------------------------------------------+
void CAIIntegration::UpdateNewsCache() {
    SNewsEvent next_event;
    IsHighImpactNewsImminent(_Symbol, 240, next_event); // Check next 4 hours
}

void CAIIntegration::UpdateSentimentCache() {
    SSentimentData data;
    FetchSentimentData(_Symbol, data);
}

void CAIIntegration::UpdateCOTCache() {
    SCOTData data;
    FetchCOTData(_Symbol, data);
}

#endif // AIINTEGRATION_MQH
