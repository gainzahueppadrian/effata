//+------------------------------------------------------------------+
//|                                                  Dashboard.mqh |
//|                      Simple On-Chart Informational Dashboard      |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "2025, Manus AI"
#property link      "https://www.mql5.com"
#property strict

//+------------------------------------------------------------------+
//| Dashboard Class                                                  |
//+------------------------------------------------------------------+
class CDashboard
{
private:
   string m_chartSymbol;
   long   m_chartId;
   string m_eaName;

   // Dashboard object names
   string m_panelName;
   string m_textName;

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   CDashboard(string eaName)
   {
      m_chartId = ChartID();
      m_chartSymbol = Symbol();
      m_eaName = eaName;

      m_panelName = "Dashboard_Panel_" + string(m_chartId);
      m_textName = "Dashboard_Text_" + string(m_chartId);
   }

   //+------------------------------------------------------------------+
   //| Create the Dashboard                                             |
   //+------------------------------------------------------------------+
   void Create()
   {
      // Create a background panel
      if(ObjectFind(m_chartId, m_panelName) < 0) {
         ObjectCreate(m_chartId, m_panelName, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(m_chartId, m_panelName, OBJPROP_XDISTANCE, 10);
         ObjectSetInteger(m_chartId, m_panelName, OBJPROP_YDISTANCE, 20);
         ObjectSetInteger(m_chartId, m_panelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(m_chartId, m_panelName, OBJPROP_BGCOLOR, clrBlack);
         ObjectSetInteger(m_chartId, m_panelName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      }

      // Create the text label
      if(ObjectFind(m_chartId, m_textName) < 0) {
         ObjectCreate(m_chartId, m_textName, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(m_chartId, m_textName, OBJPROP_XDISTANCE, 15);
         ObjectSetInteger(m_chartId, m_textName, OBJPROP_YDISTANCE, 25);
         ObjectSetInteger(m_chartId, m_textName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetString(m_chartId, m_textName, OBJPROP_FONT, "Arial");
         ObjectSetInteger(m_chartId, m_textName, OBJPROP_FONTSIZE, 10);
         ObjectSetInteger(m_chartId, m_textName, OBJPROP_COLOR, clrWhite);
      }
   }

   //+------------------------------------------------------------------+
   //| Update the Dashboard Text                                        |
   //+------------------------------------------------------------------+
   void Update(string dailyBias, string h4Bias, string po3Phase, bool tradingAllowed, int bullishScore, int bearishScore)
   {
      string text = m_eaName + "\n" +
                    "---------------------\n" +
                    "Symbol: " + m_chartSymbol + "\n" +
                    "Daily Bias: " + dailyBias + "\n" +
                    "H4 Bias: " + h4Bias + "\n" +
                    "PO3 Phase: " + po3Phase + "\n" +
                    "Trading Allowed: " + (tradingAllowed ? "Yes" : "No") + "\n" +
                    "---------------------\n" +
                    "AI Bullish Score: " + IntegerToString(bullishScore) + "\n" +
                    "AI Bearish Score: " + IntegerToString(bearishScore);

      ObjectSetString(m_chartId, m_textName, OBJPROP_TEXT, text);
   }

   //+------------------------------------------------------------------+
   //| Delete the Dashboard                                             |
   //+------------------------------------------------------------------+
   void Delete()
   {
      ObjectDelete(m_chartId, m_panelName);
      ObjectDelete(m_chartId, m_textName);
   }
};
