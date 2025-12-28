//+------------------------------------------------------------------+
//|                                                  TradeManager.mqh |
//|                      Advanced Trade & Risk Management System      |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "2025, Manus AI - Enhanced Trade Manager"
#property link      "https://www.mql5.com"
#property strict

#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>
#include <Trade/AccountInfo.mqh>
#include <Trade/SymbolInfo.mqh>

//+------------------------------------------------------------------+
//| Trade Manager Class                                              |
//+------------------------------------------------------------------+
class CTradeManager
{
private:
   CTrade m_trade;
   CPositionInfo m_position;
   CAccountInfo m_account;
   CSymbolInfo m_symbol;

   // Risk Management Parameters
   double m_riskPercent;
   double m_maxDailyDrawdownPct;
   double m_maxWeeklyDrawdownPct;
   double m_maxMonthlyDrawdownPct;
   int    m_maxOpenPositions;
   double m_maxSpreadPips;

   // Drawdown Tracking
   double m_dailyStartBalance;
   double m_weekStartBalance;
   double m_monthStartBalance;
   int    m_lastDay;
   int      m_lastWeek;
   int      m_lastMonth;
   bool m_tradingDisabledToday;
   bool m_tradingDisabledThisWeek;
   bool m_tradingDisabledThisMonth;

   // Dynamic Risk Adjustment
   double m_currentRiskMultiplier;
   int m_consecutiveLosses;
   int m_consecutiveWins;

   // Partial Profit Settings
   struct SPartialTP
   {
      double rrLevel;
      double volumePercent;
      bool executed;
   };

   SPartialTP m_partialTPs[4]; // Support up to 4 partial TPs
   int m_partialTPCount;

   // Position Tracking
   struct SPositionTracker
   {
      ulong ticket;
      double entryPrice;
      double initialSL;
      double initialVolume;
      bool movedToBE;
      bool partial1Done;
      bool partial2Done;
      bool partial3Done;
   };

   SPositionTracker m_posTracker[];

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   CTradeManager()
   {
      m_currentRiskMultiplier = 1.0;
      m_consecutiveLosses = 0;
      m_consecutiveWins = 0;

      m_partialTPCount = 0;
      ArrayResize(m_posTracker, 0);

      // Setup trade object
      m_trade.SetExpertMagicNumber(202501);
      m_trade.SetDeviationInPoints(50);
      m_trade.SetTypeFilling(ORDER_FILLING_FOK);
      m_trade.SetAsyncMode(false);
   }

   //+------------------------------------------------------------------+
   //| Initialize                                                       |
   //+------------------------------------------------------------------+
   void Initialize(string symbol,
                     double riskPercent,
                     double maxDailyDD,
                     double maxWeeklyDD,
                     double maxMonthlyDD,
                     int maxPositions,
                     double maxSpread)
   {
      m_symbol.Name(symbol);
      m_symbol.RefreshRates();

      m_riskPercent = riskPercent;
      m_maxDailyDrawdownPct = maxDailyDD;
      m_maxWeeklyDrawdownPct = maxWeeklyDD;
      m_maxMonthlyDrawdownPct = maxMonthlyDD;
      m_maxOpenPositions = maxPositions;
      m_maxSpreadPips = maxSpread;

      // Initialize drawdown tracking
      m_dailyStartBalance = m_account.Balance();
      m_weekStartBalance = m_account.Balance();
      m_monthStartBalance = m_account.Balance();
      m_lastDay = 0;
      m_lastWeek = 0;
      m_lastMonth = 0;
      m_tradingDisabledToday = false;
      m_tradingDisabledThisWeek = false;
      m_tradingDisabledThisMonth = false;
   }

   //+------------------------------------------------------------------+
   //| Set Partial TP Levels                                           |
   //+------------------------------------------------------------------+
   void SetPartialTPs(double rr1, double vol1, double rr2, double vol2,
                      double rr3 = 0, double vol3 = 0, double rr4 = 0, double vol4 = 0)
   {
      m_partialTPCount = 0;

      if(rr1 > 0 && vol1 > 0)
      {
         m_partialTPs[m_partialTPCount].rrLevel = rr1;
         m_partialTPs[m_partialTPCount].volumePercent = vol1;
         m_partialTPs[m_partialTPCount].executed = false;
         m_partialTPCount++;
      }

      if(rr2 > 0 && vol2 > 0)
      {
         m_partialTPs[m_partialTPCount].rrLevel = rr2;
         m_partialTPs[m_partialTPCount].volumePercent = vol2;
         m_partialTPs[m_partialTPCount].executed = false;
         m_partialTPCount++;
      }

      if(rr3 > 0 && vol3 > 0)
      {
         m_partialTPs[m_partialTPCount].rrLevel = rr3;
         m_partialTPs[m_partialTPCount].volumePercent = vol3;
         m_partialTPs[m_partialTPCount].executed = false;
         m_partialTPCount++;
      }

      if(rr4 > 0 && vol4 > 0)
      {
         m_partialTPs[m_partialTPCount].rrLevel = rr4;
         m_partialTPs[m_partialTPCount].volumePercent = vol4;
         m_partialTPs[m_partialTPCount].executed = false;
         m_partialTPCount++;
      }
   }

   //+------------------------------------------------------------------+
   //| Comprehensive Risk Check                                         |
   //+------------------------------------------------------------------+
   bool CanTrade()
   {
      // 1. Check Drawdown Limits
      if(!CheckDrawdown())
         return false;

      // 2. Check Max Open Positions
      if(PositionsTotal() >= m_maxOpenPositions)
      {
         PrintFormat("Max open positions (%d) reached. No new trades allowed.", m_maxOpenPositions);
         return false;
      }

      // 3. Check Spread
      m_symbol.RefreshRates();
      double currentSpread = (m_symbol.Ask() - m_symbol.Bid()) / m_symbol.Point() / 10.0;
      if(currentSpread > m_maxSpreadPips)
      {
         PrintFormat("Spread (%.1f pips) exceeds max allowed (%.1f pips). No new trades allowed.", currentSpread, m_maxSpreadPips);
         return false;
      }

      return true;
   }

   //+------------------------------------------------------------------+
   //| Drawdown Risk Manager                                            |
   //+------------------------------------------------------------------+
   bool CheckDrawdown()
   {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);

      // --- Daily Check ---
      if(dt.day_of_year != m_lastDay)
      {
         m_dailyStartBalance = m_account.Balance();
         m_lastDay = dt.day_of_year;
         m_tradingDisabledToday = false;
         PrintFormat("New Trading Day. Daily Start Balance: %.2f", m_dailyStartBalance);
      }

      // --- Weekly Check ---
      // MQL5 doesn't have week_of_year in MqlDateTime struct directly without calculation
      // Simplification: assume week starts on Monday (day_of_week == 1)
      int currentWeek = (int)dt.day_of_year / 7; // Approx

      if(currentWeek != m_lastWeek)
      {
         m_weekStartBalance = m_account.Balance();
         m_lastWeek = currentWeek;
         m_tradingDisabledThisWeek = false;
         PrintFormat("New Trading Week. Weekly Start Balance: %.2f", m_weekStartBalance);
      }

      // --- Monthly Check ---
      if(dt.mon != m_lastMonth)
      {
         m_monthStartBalance = m_account.Balance();
         m_lastMonth = dt.mon;
         m_tradingDisabledThisMonth = false;
         PrintFormat("New Trading Month. Monthly Start Balance: %.2f", m_monthStartBalance);
      }

      // If trading is disabled for any period, return false
      if(m_tradingDisabledToday || m_tradingDisabledThisWeek || m_tradingDisabledThisMonth)
      {
         Print("Trading disabled due to a drawdown limit being hit.");
         return false;
      }

      // Check current drawdown levels
      double currentEquity = m_account.Equity();

      // Check Daily DD
      double dailyDD = ((m_dailyStartBalance - currentEquity) / m_dailyStartBalance) * 100.0;
      if(dailyDD >= m_maxDailyDrawdownPct)
      {
         m_tradingDisabledToday = true;
         PrintFormat("!!! MAX DAILY DRAWDOWN (%.2f%%) REACHED !!!", m_maxDailyDrawdownPct);
         CloseAllPositions("Max Daily Drawdown Hit");
         return false;
      }

      // Check Weekly DD
      double weeklyDD = ((m_weekStartBalance - currentEquity) / m_weekStartBalance) * 100.0;
      if(weeklyDD >= m_maxWeeklyDrawdownPct)
      {
         m_tradingDisabledThisWeek = true;
         PrintFormat("!!! MAX WEEKLY DRAWDOWN (%.2f%%) REACHED !!!", m_maxWeeklyDrawdownPct);
         CloseAllPositions("Max Weekly Drawdown Hit");
         return false;
      }

      // Check Monthly DD
      double monthlyDD = ((m_monthStartBalance - currentEquity) / m_monthStartBalance) * 100.0;
      if(monthlyDD >= m_maxMonthlyDrawdownPct)
      {
         m_tradingDisabledThisMonth = true;
         PrintFormat("!!! MAX MONTHLY DRAWDOWN (%.2f%%) REACHED !!!", m_maxMonthlyDrawdownPct);
         CloseAllPositions("Max Monthly Drawdown Hit");
         return false;
      }

      return true;
   }

   //+------------------------------------------------------------------+
   //| Calculate Lot Size with Dynamic Risk                            |
   //+------------------------------------------------------------------+
   double CalculateLotSize(double slPips)
   {
      if(slPips <= 0) return 0;

      double accountBalance = m_account.Balance();
      double adjustedRisk = m_riskPercent * m_currentRiskMultiplier;
      double riskAmount = accountBalance * (adjustedRisk / 100.0);

      // Calculate point value
      double tickValue = m_symbol.TickValue();
      double tickSize = m_symbol.TickSize();
      double point = m_symbol.Point();

      // For XAUUSD: 1 pip = 0.1, 1 point = 0.01
      double pipValue = (tickValue / tickSize) * point * 10;

      // Risk per lot
      double riskPerLot = slPips * pipValue;

      if(riskPerLot <= 0) return 0;

      double lotSize = riskAmount / riskPerLot;

      // Normalize to broker limits
      double minLot = m_symbol.LotsMin();
      double maxLot = m_symbol.LotsMax();
      double lotStep = m_symbol.LotsStep();

      lotSize = MathMax(minLot, lotSize);
      lotSize = MathMin(maxLot, lotSize);
      lotSize = MathRound(lotSize / lotStep) * lotStep;

      PrintFormat("Lot Calculation: Risk=%.2f%% (x%.2f), SL=%.1f pips, Lot=%.2f",
                  adjustedRisk, m_currentRiskMultiplier, slPips, lotSize);

      return lotSize;
   }

   //+------------------------------------------------------------------+
   //| Place Order with Multiple Order Types                           |
   //+------------------------------------------------------------------+
   bool PlaceOrder(ENUM_ORDER_TYPE orderType, double volume, double price,
                   double sl, double tp, string comment = "")
   {
      m_symbol.RefreshRates();

      // Normalize prices
      price = m_symbol.NormalizePrice(price);
      sl = m_symbol.NormalizePrice(sl);
      tp = m_symbol.NormalizePrice(tp);

      bool result = false;

      // Market orders
      if(orderType == ORDER_TYPE_BUY)
      {
         result = m_trade.Buy(volume, m_symbol.Name(), m_symbol.Ask(), sl, tp, comment);
      }
      else if(orderType == ORDER_TYPE_SELL)
      {
         result = m_trade.Sell(volume, m_symbol.Name(), m_symbol.Bid(), sl, tp, comment);
      }
      // Pending orders
      else if(orderType == ORDER_TYPE_BUY_LIMIT || orderType == ORDER_TYPE_SELL_LIMIT)
      {
         result = m_trade.OrderOpen(m_symbol.Name(), orderType, volume, 0, price, sl, tp,
                                     ORDER_TIME_GTC, 0, comment);
      }
      else if(orderType == ORDER_TYPE_BUY_STOP_LIMIT)
      {
         double stopPrice = price + 10 * m_symbol.Point();
         result = m_trade.OrderOpen(m_symbol.Name(), orderType, volume, stopPrice, price,
                                     sl, tp, ORDER_TIME_GTC, 0, comment);
      }
      else if(orderType == ORDER_TYPE_SELL_STOP_LIMIT)
      {
         double stopPrice = price - 10 * m_symbol.Point();
         result = m_trade.OrderOpen(m_symbol.Name(), orderType, volume, stopPrice, price,
                                     sl, tp, ORDER_TIME_GTC, 0, comment);
      }

      if(result)
      {
         ulong ticket = m_trade.ResultOrder();

         // Track position
         SPositionTracker tracker;
         tracker.ticket = ticket;
         tracker.entryPrice = price;
         tracker.initialSL = sl;
         tracker.initialVolume = volume;
         tracker.movedToBE = false;
         tracker.partial1Done = false;
         tracker.partial2Done = false;
         tracker.partial3Done = false;

         int size = ArraySize(m_posTracker);
         ArrayResize(m_posTracker, size + 1);
         m_posTracker[size] = tracker;

         PrintFormat("Order placed: %s | Ticket: %I64u | Vol: %.2f | Entry: %.5f | SL: %.5f | TP: %.5f",
                     EnumToString(orderType), ticket, volume, price, sl, tp);
      }
      else
      {
         PrintFormat("Order failed: %s | Error: %d - %s",
                     EnumToString(orderType), GetLastError(), m_trade.ResultRetcodeDescription());
      }

      return result;
   }

   //+------------------------------------------------------------------+
   //| Manage Open Positions (BE, Partial TPs, Trailing)               |
   //+------------------------------------------------------------------+
   void ManagePositions()
   {
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(!m_position.SelectByIndex(i)) continue;
         if(m_position.Symbol() != m_symbol.Name()) continue;

         ulong ticket = m_position.Ticket();
         double entryPrice = m_position.PriceOpen();
         double currentSL = m_position.StopLoss();
         double currentTP = m_position.TakeProfit();
         double volume = m_position.Volume();
         ENUM_POSITION_TYPE posType = m_position.PositionType();

         // Find tracker
         int trackerIdx = -1;
         for(int j = 0; j < ArraySize(m_posTracker); j++)
         {
            if(m_posTracker[j].ticket == ticket)
            {
               trackerIdx = j;
               break;
            }
         }

         if(trackerIdx < 0) continue; // Not tracked

         SPositionTracker tracker = m_posTracker[trackerIdx];

         // Calculate profit in pips
         m_symbol.RefreshRates();
         double currentPrice = (posType == POSITION_TYPE_BUY) ? m_symbol.Bid() : m_symbol.Ask();
         double profitPips = 0;

         if(posType == POSITION_TYPE_BUY)
            profitPips = (currentPrice - entryPrice) / m_symbol.Point() / 10.0;
         else
            profitPips = (entryPrice - currentPrice) / m_symbol.Point() / 10.0;

         // Calculate SL distance in pips
         double slPips = MathAbs(entryPrice - tracker.initialSL) / m_symbol.Point() / 10.0;

         // Process partial TPs
         for(int k = 0; k < m_partialTPCount; k++)
         {
            double rrTarget = m_partialTPs[k].rrLevel;
            double targetPips = slPips * rrTarget;

            bool alreadyExecuted = false;
            if(k == 0) alreadyExecuted = tracker.partial1Done;
            else if(k == 1) alreadyExecuted = tracker.partial2Done;
            else if(k == 2) alreadyExecuted = tracker.partial3Done;

            if(!alreadyExecuted && profitPips >= targetPips)
            {
               double closeVolume = tracker.initialVolume * (m_partialTPs[k].volumePercent / 100.0);

               // Ensure we don't close more than current volume
               if(closeVolume > volume) closeVolume = volume;

               // Normalize volume
               closeVolume = NormalizeLot(closeVolume);

               if(closeVolume >= m_symbol.LotsMin())
               {
                  if(m_trade.PositionClosePartial(ticket, closeVolume))
                  {
                     PrintFormat("Partial TP %d executed at RR 1:%.1f | Closed %.2f lots | Remaining: %.2f",
                                 k + 1, rrTarget, closeVolume, volume - closeVolume);

                     // Mark as done
                     if(k == 0) m_posTracker[trackerIdx].partial1Done = true;
                     else if(k == 1) m_posTracker[trackerIdx].partial2Done = true;
                     else if(k == 2) m_posTracker[trackerIdx].partial3Done = true;

                     // Move to BE after first partial
                     if(k == 0 && !tracker.movedToBE)
                     {
                        double newSL = entryPrice;
                        if(posType == POSITION_TYPE_BUY)
                           newSL += 1 * m_symbol.Point();
                        else
                           newSL -= 1 * m_symbol.Point();

                        if(m_trade.PositionModify(ticket, newSL, currentTP))
                        {
                           PrintFormat("SL moved to Break Even for ticket %I64u", ticket);
                           m_posTracker[trackerIdx].movedToBE = true;
                        }
                     }
                  }
               }
            }
         }
      }
   }

   //+------------------------------------------------------------------+
   //| Normalize Lot Size                                              |
   //+------------------------------------------------------------------+
   double NormalizeLot(double lot)
   {
      double lotStep = m_symbol.LotsStep();
      return MathRound(lot / lotStep) * lotStep;
   }

   //+------------------------------------------------------------------+
   //| Close All Positions                                             |
   //+------------------------------------------------------------------+
   void CloseAllPositions(string reason = "Risk limit reached")
   {
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(!m_position.SelectByIndex(i)) continue;
         if(m_position.Symbol() != m_symbol.Name()) continue;

         ulong ticket = m_position.Ticket();
         m_trade.PositionClose(ticket);

         PrintFormat("Position %I64u closed. Reason: %s", ticket, reason);
      }
   }

   //+------------------------------------------------------------------+
   //| Update Risk Multiplier Based on Performance                     |
   //+------------------------------------------------------------------+
   void UpdateDynamicRisk(bool wasWin)
   {
      if(wasWin)
      {
         m_consecutiveWins++;
         m_consecutiveLosses = 0;

         // Increase risk slightly after wins (max 1.5x)
         if(m_consecutiveWins >= 3)
            m_currentRiskMultiplier = MathMin(1.5, m_currentRiskMultiplier + 0.1);
      }
      else
      {
         m_consecutiveLosses++;
         m_consecutiveWins = 0;

         // Decrease risk after losses (min 0.5x)
         if(m_consecutiveLosses >= 2)
            m_currentRiskMultiplier = MathMax(0.5, m_currentRiskMultiplier - 0.2);
      }

      PrintFormat("Dynamic Risk Updated: Multiplier = %.2f | Wins: %d | Losses: %d",
                  m_currentRiskMultiplier, m_consecutiveWins, m_consecutiveLosses);
   }

   //+------------------------------------------------------------------+
   //| Get Current Risk Multiplier                                     |
   //+------------------------------------------------------------------+
   double GetRiskMultiplier() { return m_currentRiskMultiplier; }

   //+------------------------------------------------------------------+
   //| Check if Trading is Allowed                                     |
   //+------------------------------------------------------------------+
   bool IsTradingAllowed()
   {
      return !m_tradingDisabledToday && !m_tradingDisabledThisWeek && !m_tradingDisabledThisMonth;
   }
};
