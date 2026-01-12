//+------------------------------------------------------------------+
//| Dashboard.mqh                                                    |
//| Institutional Dashboard - "THE DAILY $300 PRODUCING MACHINE"     |
//| Updates UI with Funding Account Metrics, ROI, and PnL            |
//+------------------------------------------------------------------+
#property copyright "Effata Trading Systems"
#property strict

#include <Charts/Chart.mqh>

//+------------------------------------------------------------------+
//| CDashboard Class                                                 |
//+------------------------------------------------------------------+
class CDashboard {
private:
   long              m_chart_id;
   int               m_subwindow;

   // Object Names
   string            m_bg_panel;
   string            m_header;
   string            m_ib_info_header;

   string            m_lbl_ib_earned_today;
   string            m_lbl_ib_earned_total;
   string            m_lbl_lots_traded_today;
   string            m_lbl_lots_traded_total;
   string            m_lbl_avg_daily_earning;
   string            m_lbl_avg_daily_lots;

   string            m_lbl_total_pnl;
   string            m_lbl_total_roi;
   string            m_lbl_todays_roi;
   string            m_lbl_avg_daily_roi;

   string            m_lbl_total_trading_days;
   string            m_lbl_running_pnl;
   string            m_lbl_todays_closed_pnl;

   string            m_big_today_pnl;
   string            m_big_total_pnl;

   // Colors
   color             m_color_bg;
   color             m_color_text;
   color             m_color_green;
   color             m_color_red;
   color             m_color_header;

public:
   CDashboard();
   ~CDashboard();

   void              Create();
   void              Update(double ib_today, double ib_total,
                            double lots_today, double lots_total,
                            double total_pnl, double total_roi,
                            double today_roi, double avg_daily_roi,
                            double running_pnl, double today_closed_pnl,
                            int trading_days);
   void              Destroy();

private:
   void              CreateLabel(string name, int x, int y, string text, int fontsize, color clr, string font="Arial");
   void              CreatePanel(string name, int x, int y, int width, int height, color bg_color);
   string            FormatCurrency(double value);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CDashboard::CDashboard() {
   m_chart_id = ChartID();
   m_subwindow = 0;
   m_bg_panel = "Effata_Dashboard_BG";

   m_color_bg = C'10,10,10'; // Dark background
   m_color_text = C'0,255,255'; // Cyan text
   m_color_green = C'0,255,0';
   m_color_red = C'255,0,0';
   m_color_header = C'255,255,255';
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CDashboard::~CDashboard() {
   Destroy();
}

//+------------------------------------------------------------------+
//| Create Dashboard                                                 |
//+------------------------------------------------------------------+
void CDashboard::Create() {
   Destroy(); // Clean up old objects

   int x_base = 20;
   int y_base = 50;
   int panel_width = 300;
   int panel_height = 400;

   // Main Panel
   CreatePanel(m_bg_panel, x_base, y_base, panel_width, panel_height, m_color_bg);

   // Header
   CreateLabel("Effata_Header", x_base + 10, y_base + 10, "FT1 - IB Info", 12, m_color_header, "Arial Bold");

   // IB Metrics
   CreateLabel("Lbl_IB_Today", x_base + 10, y_base + 40, "IB Earned Today:", 9, m_color_text);
   CreateLabel("Val_IB_Today", x_base + 150, y_base + 40, "$0.00", 9, m_color_green);

   CreateLabel("Lbl_IB_Total", x_base + 10, y_base + 60, "IB Earned Total:", 9, m_color_text);
   CreateLabel("Val_IB_Total", x_base + 150, y_base + 60, "$0.00", 9, m_color_green);

   CreateLabel("Lbl_Lots_Today", x_base + 10, y_base + 80, "Lots Traded Today:", 9, m_color_text);
   CreateLabel("Val_Lots_Today", x_base + 150, y_base + 80, "0.00", 9, C'255,255,0');

   CreateLabel("Lbl_Lots_Total", x_base + 10, y_base + 100, "Lots Traded Total:", 9, m_color_text);
   CreateLabel("Val_Lots_Total", x_base + 150, y_base + 100, "0.00", 9, C'255,255,0');

   CreateLabel("Lbl_Avg_Earn", x_base + 10, y_base + 120, "Avg Daily Earning:", 9, m_color_text);
   CreateLabel("Val_Avg_Earn", x_base + 150, y_base + 120, "$0.00", 9, m_color_text);

   CreateLabel("Lbl_Avg_Lots", x_base + 10, y_base + 140, "Avg Daily Lots:", 9, m_color_text);
   CreateLabel("Val_Avg_Lots", x_base + 150, y_base + 140, "0.00", 9, m_color_text);

   // Separator
   CreateLabel("Effata_Sep1", x_base + 10, y_base + 150, "------------------------------------------------", 9, clrGray);

   // Profit Metrics
   CreateLabel("Lbl_Total_PnL", x_base + 10, y_base + 165, "Total Profit/Loss:", 9, m_color_text);
   CreateLabel("Val_Total_PnL", x_base + 150, y_base + 165, "$0.00", 9, m_color_green);

   CreateLabel("Lbl_Total_ROI", x_base + 10, y_base + 185, "Total ROI:", 9, m_color_text);
   CreateLabel("Val_Total_ROI", x_base + 150, y_base + 185, "0.00%", 9, C'255,165,0');

   CreateLabel("Lbl_Today_ROI", x_base + 10, y_base + 205, "Today's ROI:", 10, C'255,0,255', "Arial Bold");
   CreateLabel("Val_Today_ROI", x_base + 150, y_base + 205, "0.00%", 10, C'255,0,255', "Arial Bold");

   CreateLabel("Lbl_Avg_ROI", x_base + 10, y_base + 225, "Avg Daily ROI:", 9, m_color_text);
   CreateLabel("Val_Avg_ROI", x_base + 150, y_base + 225, "0.00%", 9, m_color_text);

   CreateLabel("Lbl_Days", x_base + 10, y_base + 245, "Total Trading Days:", 9, C'255,165,0');
   CreateLabel("Val_Days", x_base + 150, y_base + 245, "0", 9, C'255,165,0');

   CreateLabel("Lbl_Run_PnL", x_base + 10, y_base + 265, "Running P/L:", 9, m_color_text);
   CreateLabel("Val_Run_PnL", x_base + 150, y_base + 265, "$0.00", 9, m_color_text);

   CreateLabel("Lbl_Today_Closed", x_base + 10, y_base + 285, "Today's Closed P/L:", 9, m_color_text);
   CreateLabel("Val_Today_Closed", x_base + 150, y_base + 285, "$0.00", 9, m_color_text);

   // Big Display at Bottom
   CreateLabel("Big_Today", x_base + 20, y_base + 320, "Today: +$0.00", 16, m_color_green, "Arial Black");
   CreateLabel("Big_Total", x_base + 20, y_base + 350, "Total: -$0.00", 16, m_color_red, "Arial Black");

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Update Values                                                    |
//+------------------------------------------------------------------+
void CDashboard::Update(double ib_today, double ib_total,
                       double lots_today, double lots_total,
                       double total_pnl, double total_roi,
                       double today_roi, double avg_daily_roi,
                       double running_pnl, double today_closed_pnl,
                       int trading_days) {

   ObjectSetString(m_chart_id, "Val_IB_Today", OBJPROP_TEXT, FormatCurrency(ib_today));
   ObjectSetString(m_chart_id, "Val_IB_Total", OBJPROP_TEXT, FormatCurrency(ib_total));
   ObjectSetString(m_chart_id, "Val_Lots_Today", OBJPROP_TEXT, DoubleToString(lots_today, 2));
   ObjectSetString(m_chart_id, "Val_Lots_Total", OBJPROP_TEXT, DoubleToString(lots_total, 2));

   double avg_earn = (trading_days > 0) ? ib_total / trading_days : 0;
   double avg_lots = (trading_days > 0) ? lots_total / trading_days : 0;

   ObjectSetString(m_chart_id, "Val_Avg_Earn", OBJPROP_TEXT, FormatCurrency(avg_earn));
   ObjectSetString(m_chart_id, "Val_Avg_Lots", OBJPROP_TEXT, DoubleToString(avg_lots, 2));

   ObjectSetString(m_chart_id, "Val_Total_PnL", OBJPROP_TEXT, FormatCurrency(total_pnl));
   ObjectSetInteger(m_chart_id, "Val_Total_PnL", OBJPROP_COLOR, (total_pnl >= 0) ? m_color_green : m_color_red);

   ObjectSetString(m_chart_id, "Val_Total_ROI", OBJPROP_TEXT, DoubleToString(total_roi, 2) + "%");
   ObjectSetString(m_chart_id, "Val_Today_ROI", OBJPROP_TEXT, "+" + DoubleToString(today_roi, 2) + "%");
   ObjectSetString(m_chart_id, "Val_Avg_ROI", OBJPROP_TEXT, "+" + DoubleToString(avg_daily_roi, 2) + "%");

   ObjectSetString(m_chart_id, "Val_Days", OBJPROP_TEXT, IntegerToString(trading_days));

   ObjectSetString(m_chart_id, "Val_Run_PnL", OBJPROP_TEXT, FormatCurrency(running_pnl));
   ObjectSetInteger(m_chart_id, "Val_Run_PnL", OBJPROP_COLOR, (running_pnl >= 0) ? m_color_green : m_color_red);

   ObjectSetString(m_chart_id, "Val_Today_Closed", OBJPROP_TEXT, FormatCurrency(today_closed_pnl));

   // Big Text
   string sign = (today_closed_pnl >= 0) ? "+" : "";
   ObjectSetString(m_chart_id, "Big_Today", OBJPROP_TEXT, "Today: " + sign + FormatCurrency(today_closed_pnl));
   ObjectSetInteger(m_chart_id, "Big_Today", OBJPROP_COLOR, (today_closed_pnl >= 0) ? m_color_green : m_color_red);

   sign = (running_pnl >= 0) ? "+" : "";
   ObjectSetString(m_chart_id, "Big_Total", OBJPROP_TEXT, "Running: " + sign + FormatCurrency(running_pnl));
   ObjectSetInteger(m_chart_id, "Big_Total", OBJPROP_COLOR, (running_pnl >= 0) ? m_color_green : m_color_red);

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Helper: Format Currency                                          |
//+------------------------------------------------------------------+
string CDashboard::FormatCurrency(double value) {
   return "$" + DoubleToString(value, 2);
}

//+------------------------------------------------------------------+
//| Helper: Create Label                                             |
//+------------------------------------------------------------------+
void CDashboard::CreateLabel(string name, int x, int y, string text, int fontsize, color clr, string font="Arial") {
   if(ObjectFind(m_chart_id, name) < 0) {
      ObjectCreate(m_chart_id, name, OBJ_LABEL, m_subwindow, 0, 0);
   }
   ObjectSetInteger(m_chart_id, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(m_chart_id, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(m_chart_id, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetString(m_chart_id, name, OBJPROP_TEXT, text);
   ObjectSetString(m_chart_id, name, OBJPROP_FONT, font);
   ObjectSetInteger(m_chart_id, name, OBJPROP_FONTSIZE, fontsize);
   ObjectSetInteger(m_chart_id, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(m_chart_id, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(m_chart_id, name, OBJPROP_HIDDEN, true);
}

//+------------------------------------------------------------------+
//| Helper: Create Panel                                             |
//+------------------------------------------------------------------+
void CDashboard::CreatePanel(string name, int x, int y, int width, int height, color bg_color) {
   if(ObjectFind(m_chart_id, name) < 0) {
      ObjectCreate(m_chart_id, name, OBJ_RECTANGLE_LABEL, m_subwindow, 0, 0);
   }
   ObjectSetInteger(m_chart_id, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(m_chart_id, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(m_chart_id, name, OBJPROP_XSIZE, width);
   ObjectSetInteger(m_chart_id, name, OBJPROP_YSIZE, height);
   ObjectSetInteger(m_chart_id, name, OBJPROP_BGCOLOR, bg_color);
   ObjectSetInteger(m_chart_id, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(m_chart_id, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(m_chart_id, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(m_chart_id, name, OBJPROP_HIDDEN, true);
}

//+------------------------------------------------------------------+
//| Destroy                                                          |
//+------------------------------------------------------------------+
void CDashboard::Destroy() {
   // Delete all objects with prefix
   // Note: MQL5 doesn't have ObjectsDeleteAll by prefix easily without looping
   // For safety, we delete specific known objects
   ObjectDelete(m_chart_id, m_bg_panel);
   ObjectDelete(m_chart_id, "Effata_Header");
   ObjectDelete(m_chart_id, "Lbl_IB_Today"); ObjectDelete(m_chart_id, "Val_IB_Today");
   ObjectDelete(m_chart_id, "Lbl_IB_Total"); ObjectDelete(m_chart_id, "Val_IB_Total");
   ObjectDelete(m_chart_id, "Lbl_Lots_Today"); ObjectDelete(m_chart_id, "Val_Lots_Today");
   ObjectDelete(m_chart_id, "Lbl_Lots_Total"); ObjectDelete(m_chart_id, "Val_Lots_Total");
   ObjectDelete(m_chart_id, "Lbl_Avg_Earn"); ObjectDelete(m_chart_id, "Val_Avg_Earn");
   ObjectDelete(m_chart_id, "Lbl_Avg_Lots"); ObjectDelete(m_chart_id, "Val_Avg_Lots");
   ObjectDelete(m_chart_id, "Effata_Sep1");
   ObjectDelete(m_chart_id, "Lbl_Total_PnL"); ObjectDelete(m_chart_id, "Val_Total_PnL");
   ObjectDelete(m_chart_id, "Lbl_Total_ROI"); ObjectDelete(m_chart_id, "Val_Total_ROI");
   ObjectDelete(m_chart_id, "Lbl_Today_ROI"); ObjectDelete(m_chart_id, "Val_Today_ROI");
   ObjectDelete(m_chart_id, "Lbl_Avg_ROI"); ObjectDelete(m_chart_id, "Val_Avg_ROI");
   ObjectDelete(m_chart_id, "Lbl_Days"); ObjectDelete(m_chart_id, "Val_Days");
   ObjectDelete(m_chart_id, "Lbl_Run_PnL"); ObjectDelete(m_chart_id, "Val_Run_PnL");
   ObjectDelete(m_chart_id, "Lbl_Today_Closed"); ObjectDelete(m_chart_id, "Val_Today_Closed");
   ObjectDelete(m_chart_id, "Big_Today");
   ObjectDelete(m_chart_id, "Big_Total");

   ChartRedraw();
}
