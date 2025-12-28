//+------------------------------------------------------------------+
//| TelegramNotifier.mqh                                            |
//| Telegram Notification System                                    |
//| Copyright 2025, Reinforcement Learning Trading Systems          |
//+------------------------------------------------------------------+
#property copyright "2025, RL Trading Systems"
#property link      "https://www.mql5.com "
#property version   "1.00"
#property strict

class TelegramNotifier {
private:
    string botToken;
    string chatId;
    bool enabled;

public:
    TelegramNotifier(string token, string id, bool enable) {
        botToken = token;
        chatId = id;
        enabled = enable;
    }
bool SendNotification(string message) {
    if(!enabled) return false;

    string url = "https://api.telegram.org/bot" + botToken + "/sendMessage";
    string params = "chat_id=" + chatId + "&text=" + StringEncodeURL(message);

    char data[];
    string headers = "Content-Type: application/x-www-form-urlencoded";
    string result;

    int res = WebRequest("POST", url, headers, 5000, data, params, result);
    return (res == 200);
}

bool SendTradeAlert(int ticket, double price, double sl, double tp, string comment) {
    string message = "🚨 TRADE ALERT 🚨\n";
    message += "Symbol: " + _Symbol + "\n";
    message += "Ticket: " + (string)ticket + "\n";
    message += "Price: " + DoubleToString(price, _Digits) + "\n";
    message += "SL: " + DoubleToString(sl, _Digits) + "\n";
    message += "TP: " + DoubleToString(tp, _Digits) + "\n";
    message += "Comment: " + comment;

    return SendNotification(message);
}

private:
    string StringEncodeURL(string str) {
        // Función simplificada para codificar URL
        string result = "";
        for(int i = 0; i < StringLen(str); i++) {
            ushort c = StringGetCharacter(str, i);
            if((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') ||
               c == '-' || c == '_' || c == '.' || c == '~') {
                result += (string)Character(c);
            } else {
                result += "%" + IntegerToString(c, 16);
            }
        }
        return result;
    }
};