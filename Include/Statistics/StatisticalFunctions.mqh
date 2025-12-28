//+------------------------------------------------------------------+
//| StatisticalFunctions.mqh                                        |
//| Statistical Functions Library                                   |
//| Copyright 2025, Reinforcement Learning Trading Systems          |
//+------------------------------------------------------------------+
#property copyright "2025, RL Trading Systems"
#property link      "https://www.mql5.com "
#property version   "1.00"
#property strict

#include <Math/Stat/Math.mqh>

class StatisticalFunctions {
public:
    static double CalculateZScore(double &data[], int period) {
        if(ArraySize(data) < period) return 0.0;
    double mean = 0.0;
    for(int i = 0; i < period; i++) {
        mean += data[i];
    }
    mean /= period;

    double stdDev = 0.0;
    for(int i = 0; i < period; i++) {
        double diff = data[i] - mean;
        stdDev += diff * diff;
    }
    stdDev = MathSqrt(stdDev / period);

    return (stdDev == 0) ? 0 : (data[0] - mean) / stdDev;
}

static double CalculateCorrelation(double &data1[], double &data2[], int period) {
    if(ArraySize(data1) < period || ArraySize(data2) < period) return 0.0;

    double mean1 = 0.0, mean2 = 0.0;
    for(int i = 0; i < period; i++) {
        mean1 += data1[i];
        mean2 += data2[i];
    }
    mean1 /= period;
    mean2 /= period;

    double numerator = 0.0, denom1 = 0.0, denom2 = 0.0;
    for(int i = 0; i < period; i++) {
        double diff1 = data1[i] - mean1;
        double diff2 = data2[i] - mean2;
        numerator += diff1 * diff2;
        denom1 += diff1 * diff1;
        denom2 += diff2 * diff2;
    }

    if(denom1 == 0 || denom2 == 0) return 0.0;
    return numerator / (MathSqrt(denom1) * MathSqrt(denom2));
}

static double CalculateShannonEntropy(double &data[], int period, int bins=10) {
    if(ArraySize(data) < period) return 0.0;

    double minVal = data[0], maxVal = data[0];
    for(int i = 1; i < period; i++) {
        if(data[i] < minVal) minVal = data[i];
        if(data[i] > maxVal) maxVal = data[i];
    }

    double range = maxVal - minVal;
    if(range == 0) return 0.0;

    double binWidth = range / bins;
    int counts[];
    ArrayResize(counts, bins);
    ZeroMemory(counts);

    for(int i = 0; i < period; i++) {
        int bin = (int)((data[i] - minVal) / binWidth);
        if(bin >= bins) bin = bins - 1;
        counts[bin]++;
    }

    double entropy = 0.0;
    for(int i = 0; i < bins; i++) {
        double p = (double)counts[i] / period;
        if(p > 0) entropy -= p * MathLog(p);
    }

    return entropy;
}

};