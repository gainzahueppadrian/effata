//+------------------------------------------------------------------+
//| GoldFuturesArbitrage.mqh                                         |
//| Spot-Futures Arbitrage Strategy                                  |
//+------------------------------------------------------------------+
#property copyright "Effata Trading Systems"
#property strict

#ifndef GOLD_FUTURES_ARBITRAGE_MQH
#define GOLD_FUTURES_ARBITRAGE_MQH

#include <Trade/Trade.mqh>

class CGoldFuturesArbitrage {
private:
    string m_spotSymbol;
    string m_futuresSymbol;
    double m_thresholdPercent;
    CTrade m_trade;
    double m_lotSize;

public:
    CGoldFuturesArbitrage(string spot, string futures) {
        m_spotSymbol = spot;
        m_futuresSymbol = futures;
        m_thresholdPercent = 0.005; // 0.5% gap
        m_lotSize = 0.1;
    }

    void OnTick() {
        if(!SymbolSelect(m_spotSymbol, true) || !SymbolSelect(m_futuresSymbol, true)) return;

        double spotBid = SymbolInfoDouble(m_spotSymbol, SYMBOL_BID);
        double spotAsk = SymbolInfoDouble(m_spotSymbol, SYMBOL_ASK);
        double futBid = SymbolInfoDouble(m_futuresSymbol, SYMBOL_BID);
        double futAsk = SymbolInfoDouble(m_futuresSymbol, SYMBOL_ASK);

        if(spotBid == 0 || futBid == 0) return;

        // Calculate Gap (Basis)
        // If Futures > Spot (Contango), sell Futures, buy Spot
        double gap = (futBid - spotAsk) / spotAsk;

        if(gap > m_thresholdPercent) {
            Print("Arbitrage Opportunity: Gap ", DoubleToString(gap*100, 2), "% > Threshold");

            // Execute Legs
            // 1. Buy Spot
            m_trade.Buy(m_lotSize, m_spotSymbol, spotAsk, 0, 0, "Arb Leg 1: Spot Buy");

            // 2. Sell Futures
            m_trade.Sell(m_lotSize, m_futuresSymbol, futBid, 0, 0, "Arb Leg 2: Fut Sell");
        }

        // Reverse Logic (Backwardation)
        double reverseGap = (spotBid - futAsk) / futAsk;
        if(reverseGap > m_thresholdPercent) {
             Print("Reverse Arbitrage Opportunity");
             m_trade.Sell(m_lotSize, m_spotSymbol, spotBid, 0, 0, "Arb Leg 1: Spot Sell");
             m_trade.Buy(m_lotSize, m_futuresSymbol, futAsk, 0, 0, "Arb Leg 2: Fut Buy");
        }
    }
};

#endif
