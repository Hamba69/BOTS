//+------------------------------------------------------------------+
//|                          Elite_Hybrid_Scalper_v6.1               |
//|           Optimized for $5-$100K | Aggressive Scalping           |
//+------------------------------------------------------------------+
#property copyright "MIN2 - Elite Hybrid Scalper v6.1"
#property link ""
#property version "6.10"
#property description "Multi-account scalper: H1 trend + M15 bias + M5/M1 execution + Instant profit"
#property strict
#include <Trade\Trade.mqh>

//--- ACCOUNT & RISK PARAMETERS
input group "=== ACCOUNT SIZE & RISK ==="
input bool AutoDetectAccountSize = true;           // Auto-detect account size
input double InpRiskPercent = 2.0;                 // Risk per signal (% - aggressive)
input int InpMaxExposure = 50;                     // Max total positions (aggressive)
input int InpTradesPerSignal = 5;                  // Orders per signal (aggressive)
input double MinAccountForStandard = 1000.0;       // Min $ for standard lots
input string InpSymbol = "";                       // Empty = current chart

//--- INSTANT PROFIT SCALPING
input group "=== INSTANT PROFIT SETTINGS ==="
input bool UseInstantProfit = true;               // Enable instant profit taking
input double InstantProfitPips = 3.0;             // Instant TP in pips (tiny)
input double InstantProfitPercent = 0.5;          // Or % of SL distance
input bool ClosePartialOnProfit = true;           // Close 50% at instant TP
input double PartialClosePercent = 50.0;          // % to close at instant TP
input int InstantCheckIntervalMs = 100;           // Check every 100ms (aggressive)

//--- M1 MICRO TIMEFRAME ANALYSIS (OPTIONAL)
input group "=== M1 ANALYSIS (OPTIONAL) ==="
input bool UseM1Analysis = true;                  // Enable M1 micro signals
input int M1_EMAFast = 5;                         // M1 Fast EMA (Fib)
input int M1_EMASlow = 13;                        // M1 Slow EMA (Fib)
input int M1_RSIPeriod = 14;                      // M1 RSI Period
input double M1_RSIBullMin = 45.0;                // M1 RSI Bull Min
input double M1_RSIBullMax = 75.0;                // M1 RSI Bull Max
input double M1_RSIBearMin = 25.0;                // M1 RSI Bear Min
input double M1_RSIBearMax = 55.0;                // M1 RSI Bear Max
input int MinM1Conditions = 2;                    // Min M1 conditions (of 3)

//--- DYNAMIC SL/TP
input group "=== STOP LOSS & TAKE PROFIT ==="
input bool UseDynamicSLTP = true;                 // Use ATR-based levels
input double InpATRMultiplierSL = 0.8;            // SL ATR Multiplier (tighter)
input double InpATRMultiplierTP = 2.5;            // TP ATR Multiplier (aggressive)
input int InpFixedSL_Pips = 8;                    // Backup SL (pips - tight)
input int InpFixedTP_Pips = 20;                   // Backup TP (pips)
input bool UseTrailingStop = true;                // Enable trailing stop
input double TrailActivationR = 0.8;              // Trail activation (R multiple)
input double TrailDistanceATR = 0.3;              // Trail distance (ATR - tight)

//--- ORDER TYPES
input group "=== ORDER EXECUTION ==="
input bool UseBuyStop = true;                     // Breakout long
input bool UseSellStop = true;                    // Breakout short
input bool UseBuyLimit = true;                    // Pullback long (scalping)
input bool UseSellLimit = true;                   // Pullback short (scalping)
input int InpEntryBufferPts = 2;                  // Entry buffer points (tight)
input int InpPendingExpirySec = 600;              // Pending expiry (10min - faster)
input int MaxSlippage = 15;                       // Max slippage points

//--- H1 TREND FILTER
input group "=== H1 TREND FILTER ==="
input bool UseH1TrendFilter = true;              // Enforce H1 trend
input int TrendEMAPeriod = 50;                   // H1 EMA period
input double MinTrendStrength = 0.0005;          // Min % move for trend (relaxed)
input bool AllowNeutralTrend = true;             // Trade in consolidation

//--- FIBONACCI QUALITY FILTER (M5)
input group "=== FIBONACCI FILTERS (M5) ==="
input bool UseFibFilters = true;                 // Enable Fib filters
input int MinFibConditions = 2;                  // Min conditions (relaxed for scalping)
input int FibEMAFast = 8;                        // EMA Fast (Fibonacci)
input int FibEMASlow = 21;                       // EMA Slow (Fibonacci)
input int FibRSIPeriod = 14;                     // RSI Period
input int FibATRPeriod = 14;                     // ATR Period
input double FibATRMin = 0.3;                    // Min ATR value (relaxed)
input int FibMACDFast = 12;                      // MACD Fast
input int FibMACDSlow = 26;                      // MACD Slow
input int FibMACDSignal = 9;                     // MACD Signal
input double FibRSIBullMin = 40.0;               // RSI Bull Min
input double FibRSIBullMax = 80.0;               // RSI Bull Max
input double FibRSIBearMin = 20.0;               // RSI Bear Min
input double FibRSIBearMax = 60.0;               // RSI Bear Max

//--- RISK LIMITS
input group "=== RISK MANAGEMENT ==="
input double MaxDailyLoss = 5.0;                 // Max daily loss (% - aggressive)
input int MaxConsecutiveLosses = 5;              // Max consecutive losses
input int MaxDailyTrades = 50;                   // Max trades per day (scalping)

// Constants
const long Magic = 987651;
const string LogFileName = "EliteHybrid_v61.log";

// Globals
string tradingSymbol = "";
CTrade trade;
int logHandle = INVALID_HANDLE;
long stopsLevel = 0;
long freezeLevel = 0;
datetime lastM5Bar = 0;
datetime lastM1Bar = 0;
datetime lastCleanupTime = 0;
datetime dailyResetTime = 0;
datetime lastInstantCheckTime = 0;
int openPosCount = 0;
int pendingCount = 0;
double dailyStartBalance = 0;
double dailyPL = 0;
int dailyTradeCount = 0;
int consecutiveLosses = 0;
bool isTradingAllowed = true;
double accountSizeCategory = 0; // 0=micro, 1=mini, 2=standard
double dynamicLotMultiplier = 1.0;

// Position tracking
struct PositionData {
   ulong ticket;
   double entryPrice;
   double stopLoss;
   double takeProfit;
   double riskAmount;
   double instantTP;
   bool trailingActive;
   bool instantTPHit;
   double initialVolume;
   datetime openTime;
};
PositionData posData[];

// Indicators
int hEMAFast = INVALID_HANDLE;
int hEMASlow = INVALID_HANDLE;
int hRSI = INVALID_HANDLE;
int hATR = INVALID_HANDLE;
int hMACD = INVALID_HANDLE;
int hTrendEMA = INVALID_HANDLE;
int hM1_EMAFast = INVALID_HANDLE;
int hM1_EMASlow = INVALID_HANDLE;
int hM1_RSI = INVALID_HANDLE;

//+------------------------------------------------------------------+
int OnInit()
{
   tradingSymbol = (InpSymbol == "") ? _Symbol : InpSymbol;
   
   logHandle = FileOpen(LogFileName, FILE_WRITE|FILE_TXT|FILE_COMMON);
   if(logHandle == INVALID_HANDLE)
   {
      Print("Failed to open log file.");
      return INIT_FAILED;
   }
   
   // Detect account size category
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(AutoDetectAccountSize)
   {
      if(balance < 100) accountSizeCategory = 0; // Micro ($5-$99)
      else if(balance < MinAccountForStandard) accountSizeCategory = 1; // Mini ($100-$999)
      else accountSizeCategory = 2; // Standard ($1000+)
      
      // Adjust lot multiplier for tiny accounts
      if(balance < 10) dynamicLotMultiplier = 0.5;
      else if(balance < 50) dynamicLotMultiplier = 0.8;
      else dynamicLotMultiplier = 1.0;
   }
   
   FileWriteString(logHandle, "=== ELITE HYBRID SCALPER v6.1 (AGGRESSIVE) ===\n");
   FileWriteString(logHandle, "Symbol: " + tradingSymbol + "\n");
   FileWriteString(logHandle, StringFormat("Account: $%.2f (Category: %s)\n", 
                   balance, accountSizeCategory==0?"MICRO":accountSizeCategory==1?"MINI":"STANDARD"));
   FileWriteString(logHandle, "Strategy: H1 trend + M15 bias + M5/M1 execution + Instant TP\n");
   FileWriteString(logHandle, StringFormat("Instant TP: %.1f pips | Partial Close: %.0f%%\n", 
                   InstantProfitPips, PartialClosePercent));
   FileFlush(logHandle);
   
   stopsLevel = SymbolInfoInteger(tradingSymbol, SYMBOL_TRADE_STOPS_LEVEL);
   freezeLevel = SymbolInfoInteger(tradingSymbol, SYMBOL_TRADE_FREEZE_LEVEL);
   trade.SetExpertMagicNumber(Magic);
   trade.SetDeviationInPoints(MaxSlippage);
   
   // M5 Indicators
   if(UseFibFilters)
   {
      hEMAFast = iMA(tradingSymbol, PERIOD_M5, FibEMAFast, 0, MODE_EMA, PRICE_CLOSE);
      hEMASlow = iMA(tradingSymbol, PERIOD_M5, FibEMASlow, 0, MODE_EMA, PRICE_CLOSE);
      hRSI = iRSI(tradingSymbol, PERIOD_M5, FibRSIPeriod, PRICE_CLOSE);
      hATR = iATR(tradingSymbol, PERIOD_M5, FibATRPeriod);
      hMACD = iMACD(tradingSymbol, PERIOD_M5, FibMACDFast, FibMACDSlow, FibMACDSignal, PRICE_CLOSE);
      
      if(hEMAFast == INVALID_HANDLE || hEMASlow == INVALID_HANDLE || 
         hRSI == INVALID_HANDLE || hATR == INVALID_HANDLE || hMACD == INVALID_HANDLE)
      {
         Print("ERROR: Failed to create M5 indicators");
         return INIT_FAILED;
      }
   }
   
   // M1 Indicators (Optional)
   if(UseM1Analysis)
   {
      hM1_EMAFast = iMA(tradingSymbol, PERIOD_M1, M1_EMAFast, 0, MODE_EMA, PRICE_CLOSE);
      hM1_EMASlow = iMA(tradingSymbol, PERIOD_M1, M1_EMASlow, 0, MODE_EMA, PRICE_CLOSE);
      hM1_RSI = iRSI(tradingSymbol, PERIOD_M1, M1_RSIPeriod, PRICE_CLOSE);
      
      if(hM1_EMAFast == INVALID_HANDLE || hM1_EMASlow == INVALID_HANDLE || hM1_RSI == INVALID_HANDLE)
      {
         Print("ERROR: Failed to create M1 indicators");
         return INIT_FAILED;
      }
   }
   
   // H1 Trend
   if(UseH1TrendFilter)
   {
      hTrendEMA = iMA(tradingSymbol, PERIOD_H1, TrendEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
      if(hTrendEMA == INVALID_HANDLE)
      {
         Print("ERROR: Failed to create H1 trend EMA");
         return INIT_FAILED;
      }
   }
   
   UpdateCounts();
   dailyStartBalance = balance;
   dailyResetTime = TimeCurrent();
   ArrayResize(posData, 0);
   
   Print("Elite Hybrid Scalper v6.1 initialized - AGGRESSIVE MODE!");
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(UseFibFilters)
   {
      if(hEMAFast != INVALID_HANDLE) IndicatorRelease(hEMAFast);
      if(hEMASlow != INVALID_HANDLE) IndicatorRelease(hEMASlow);
      if(hRSI != INVALID_HANDLE) IndicatorRelease(hRSI);
      if(hATR != INVALID_HANDLE) IndicatorRelease(hATR);
      if(hMACD != INVALID_HANDLE) IndicatorRelease(hMACD);
   }
   
   if(UseM1Analysis)
   {
      if(hM1_EMAFast != INVALID_HANDLE) IndicatorRelease(hM1_EMAFast);
      if(hM1_EMASlow != INVALID_HANDLE) IndicatorRelease(hM1_EMASlow);
      if(hM1_RSI != INVALID_HANDLE) IndicatorRelease(hM1_RSI);
   }
   
   if(hTrendEMA != INVALID_HANDLE) IndicatorRelease(hTrendEMA);
   
   if(logHandle != INVALID_HANDLE)
   {
      FileWriteString(logHandle, "EA Stopped at " + TimeToString(TimeCurrent()) + "\n");
      FileFlush(logHandle);
      FileClose(logHandle);
   }
}

//+------------------------------------------------------------------+
void OnTick()
{
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !AccountInfoInteger(ACCOUNT_TRADE_ALLOWED))
      return;
   
   datetime currTime = TimeCurrent();
   
   // Daily reset check
   MqlDateTime currentTime, resetTime;
   TimeToStruct(currTime, currentTime);
   TimeToStruct(dailyResetTime, resetTime);
   
   if(currentTime.day != resetTime.day)
   {
      dailyPL = 0;
      dailyTradeCount = 0;
      dailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      dailyResetTime = currTime;
      isTradingAllowed = true;
      consecutiveLosses = 0;
      
      FileWriteString(logHandle, "=== NEW DAY - Reset counters ===\n");
      FileFlush(logHandle);
   }
   
   // Update daily P/L
   dailyPL = AccountInfoDouble(ACCOUNT_BALANCE) - dailyStartBalance;
   double dailyLossPercent = (dailyPL < 0) ? (MathAbs(dailyPL) / dailyStartBalance * 100) : 0;
   
   // Risk limit checks
   if(dailyLossPercent >= MaxDailyLoss)
   {
      isTradingAllowed = false;
      if(dailyTradeCount > 0)
      {
         FileWriteString(logHandle, StringFormat("DAILY LOSS LIMIT HIT: %.2f%% - Trading stopped\n", dailyLossPercent));
         FileFlush(logHandle);
      }
   }
   
   if(consecutiveLosses >= MaxConsecutiveLosses)
   {
      isTradingAllowed = false;
   }
   
   if(dailyTradeCount >= MaxDailyTrades)
   {
      isTradingAllowed = false;
   }
   
   // INSTANT PROFIT CHECK (High frequency)
   if(UseInstantProfit)
   {
      uint tickTime = GetTickCount();
      if(tickTime - lastInstantCheckTime >= (uint)InstantCheckIntervalMs)
      {
         CheckInstantProfit();
         lastInstantCheckTime = tickTime;
      }
   }
   
   // Cleanup expired orders
   if(currTime - lastCleanupTime >= 10)
   {
      CleanupExpired();
      lastCleanupTime = currTime;
   }
   
   // Manage trailing stops
   if(UseTrailingStop)
   {
      ManageTrailingStops();
   }
   
   // M5 bar check for main entries
   datetime currM5Bar = iTime(tradingSymbol, PERIOD_M5, 0);
   bool newM5Bar = (currM5Bar != lastM5Bar);
   if(newM5Bar) lastM5Bar = currM5Bar;
   
   // M1 bar check for micro entries
   datetime currM1Bar = iTime(tradingSymbol, PERIOD_M1, 0);
   bool newM1Bar = (currM1Bar != lastM1Bar);
   if(newM1Bar) lastM1Bar = currM1Bar;
   
   // Entry logic on new bars
   if(newM5Bar || (UseM1Analysis && newM1Bar))
   {
      UpdateCounts();
      
      if(!isTradingAllowed) return;
      if(openPosCount + pendingCount + (InpTradesPerSignal * 2) > InpMaxExposure) return;
      
      ProcessSignals(newM5Bar, newM1Bar);
   }
}

//+------------------------------------------------------------------+
void ProcessSignals(bool isM5Bar, bool isM1Bar)
{
   // H1 TREND FILTER
   bool h1Bullish = false, h1Bearish = false, h1Neutral = false;
   if(UseH1TrendFilter)
   {
      if(!CheckH1Trend(h1Bullish, h1Bearish, h1Neutral))
         return;
   }
   
   // M15 DIRECTIONAL BIAS
   MqlRates m15[];
   ArraySetAsSeries(m15, true);
   if(CopyRates(tradingSymbol, PERIOD_M15, 1, 1, m15) != 1) return;
   
   bool bullish = m15[0].close > m15[0].open;
   bool bearish = m15[0].close < m15[0].open;
   
   if(!bullish && !bearish) return;
   
   // TREND ALIGNMENT CHECK
   if(UseH1TrendFilter && !AllowNeutralTrend)
   {
      if(bullish && h1Bearish) return;
      if(bearish && h1Bullish) return;
   }
   
   // FIBONACCI QUALITY FILTER (M5)
   if(UseFibFilters)
   {
      int fibScore = CheckFibonacciConditions(bullish);
      if(fibScore < MinFibConditions)
      {
         FileWriteString(logHandle, StringFormat("M5 Fib REJECTED: %d/%d\n", fibScore, 5));
         FileFlush(logHandle);
         return;
      }
   }
   
   // M1 MICRO FILTER (Optional - adds precision)
   if(UseM1Analysis && isM1Bar)
   {
      int m1Score = CheckM1Conditions(bullish);
      if(m1Score < MinM1Conditions)
      {
         FileWriteString(logHandle, StringFormat("M1 REJECTED: %d/%d\n", m1Score, 3));
         FileFlush(logHandle);
         return;
      }
      FileWriteString(logHandle, StringFormat("M1 CONFIRMED: %d/3 ✓\n", m1Score));
   }
   
   // GET M5 DATA FOR ENTRY
   MqlRates m5[];
   ArraySetAsSeries(m5, true);
   if(CopyRates(tradingSymbol, PERIOD_M5, 0, 2, m5) != 2) return;
   
   double prevHigh = m5[1].high;
   double prevLow = m5[1].low;
   double point = SymbolInfoDouble(tradingSymbol, SYMBOL_POINT);
   long spreadPts = SymbolInfoInteger(tradingSymbol, SYMBOL_SPREAD);
   double entryBufferTotal = (InpEntryBufferPts + spreadPts) * point;
   
   long minDistPts = MathMax(stopsLevel, freezeLevel);
   double minDist = minDistPts * point;
   
   double ask = SymbolInfoDouble(tradingSymbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(tradingSymbol, SYMBOL_BID);
   datetime expTime = TimeCurrent() + InpPendingExpirySec;
   
   // DYNAMIC SL/TP CALCULATION
   double fixedSL, fixedTP;
   if(UseDynamicSLTP)
   {
      double atr[];
      ArraySetAsSeries(atr, true);
      if(CopyBuffer(hATR, 0, 0, 2, atr) >= 2 && atr[0] > 0)
      {
         fixedSL = atr[0] * InpATRMultiplierSL;
         fixedTP = atr[0] * InpATRMultiplierTP;
      }
      else
      {
         fixedSL = InpFixedSL_Pips * point * 10;
         fixedTP = InpFixedTP_Pips * point * 10;
      }
   }
   else
   {
      fixedSL = InpFixedSL_Pips * point * 10;
      fixedTP = InpFixedTP_Pips * point * 10;
   }
   
   // PLACE ORDERS
   if(bullish)
   {
      FileWriteString(logHandle, "=== BULLISH SIGNAL (AGGRESSIVE) ===\n");
      
      if(UseBuyStop)
         PlaceOrders(ORDER_TYPE_BUY_STOP, prevHigh + entryBufferTotal, fixedSL, fixedTP, 
                    ask, bid, minDist, expTime);
      
      if(UseBuyLimit)
         PlaceOrders(ORDER_TYPE_BUY_LIMIT, prevLow - entryBufferTotal, fixedSL, fixedTP, 
                    ask, bid, minDist, expTime);
   }
   else
   {
      FileWriteString(logHandle, "=== BEARISH SIGNAL (AGGRESSIVE) ===\n");
      
      if(UseSellStop)
         PlaceOrders(ORDER_TYPE_SELL_STOP, prevLow - entryBufferTotal, fixedSL, fixedTP, 
                    ask, bid, minDist, expTime);
      
      if(UseSellLimit)
         PlaceOrders(ORDER_TYPE_SELL_LIMIT, prevHigh + entryBufferTotal, fixedSL, fixedTP, 
                    ask, bid, minDist, expTime);
   }
   
   FileFlush(logHandle);
}

//+------------------------------------------------------------------+
bool CheckH1Trend(bool &bullish, bool &bearish, bool &neutral)
{
   double trendEMA[];
   MqlRates h1[];
   ArraySetAsSeries(trendEMA, true);
   ArraySetAsSeries(h1, true);
   
   if(CopyBuffer(hTrendEMA, 0, 0, 3, trendEMA) < 3) return false;
   if(CopyRates(tradingSymbol, PERIOD_H1, 0, 3, h1) < 3) return false;
   
   double currentPrice = h1[0].close;
   double priceChange = MathAbs(currentPrice - h1[2].close) / h1[2].close;
   
   bool emaRising = trendEMA[0] > trendEMA[1] && trendEMA[1] > trendEMA[2];
   bool emaFalling = trendEMA[0] < trendEMA[1] && trendEMA[1] < trendEMA[2];
   bool priceAboveEMA = currentPrice > trendEMA[0];
   bool priceBelowEMA = currentPrice < trendEMA[0];
   bool strongMove = priceChange >= MinTrendStrength;
   
   if(emaRising && priceAboveEMA && strongMove)
   {
      bullish = true;
      bearish = false;
      neutral = false;
   }
   else if(emaFalling && priceBelowEMA && strongMove)
   {
      bullish = false;
      bearish = true;
      neutral = false;
   }
   else
   {
      bullish = false;
      bearish = false;
      neutral = true;
   }
   
   return true;
}

//+------------------------------------------------------------------+
int CheckFibonacciConditions(bool bullishBias)
{
   int score = 0;
   
   double emaFast[], emaSlow[], rsi[], atr[], macdMain[], macdSignal[];
   ArraySetAsSeries(emaFast, true);
   ArraySetAsSeries(emaSlow, true);
   ArraySetAsSeries(rsi, true);
   ArraySetAsSeries(atr, true);
   ArraySetAsSeries(macdMain, true);
   ArraySetAsSeries(macdSignal, true);
   
   if(CopyBuffer(hEMAFast, 0, 0, 2, emaFast) < 2) return 0;
   if(CopyBuffer(hEMASlow, 0, 0, 2, emaSlow) < 2) return 0;
   if(CopyBuffer(hRSI, 0, 0, 2, rsi) < 2) return 0;
   if(CopyBuffer(hATR, 0, 0, 2, atr) < 2) return 0;
   if(CopyBuffer(hMACD, 0, 0, 2, macdMain) < 2) return 0;
   if(CopyBuffer(hMACD, 1, 0, 2, macdSignal) < 2) return 0;
   
   double close = iClose(tradingSymbol, PERIOD_M5, 1);
   
   if(bullishBias)
   {
      if(emaFast[0] > emaSlow[0]) score++;
      if(close > emaFast[0] || close > emaSlow[0]) score++;
      if(rsi[0] >= FibRSIBullMin && rsi[0] <= FibRSIBullMax) score++;
      if(macdMain[0] > macdSignal[0]) score++;
      if(atr[0] >= FibATRMin) score++;
   }
   else
   {
      if(emaFast[0] < emaSlow[0]) score++;
      if(close < emaFast[0] || close < emaSlow[0]) score++;
      if(rsi[0] >= FibRSIBearMin && rsi[0] <= FibRSIBearMax) score++;
      if(macdMain[0] < macdSignal[0]) score++;
      if(atr[0] >= FibATRMin) score++;
   }
   
   return score;
}

//+------------------------------------------------------------------+
int CheckM1Conditions(bool bullishBias)
{
   int score = 0;
   
   double m1Fast[], m1Slow[], m1RSI[];
   ArraySetAsSeries(m1Fast, true);
   ArraySetAsSeries(m1Slow, true);
   ArraySetAsSeries(m1RSI, true);
   
   if(CopyBuffer(hM1_EMAFast, 0, 0, 2, m1Fast) < 2) return 0;
   if(CopyBuffer(hM1_EMASlow, 0, 0, 2, m1Slow) < 2) return 0;
   if(CopyBuffer(hM1_RSI, 0, 0, 2, m1RSI) < 2) return 0;
   
   double m1Close = iClose(tradingSymbol, PERIOD_M1, 1);
   
   if(bullishBias)
   {
      if(m1Fast[0] > m1Slow[0]) score++;
      if(m1Close > m1Fast[0]) score++;
      if(m1RSI[0] >= M1_RSIBullMin && m1RSI[0] <= M1_RSIBullMax) score++;
   }
   else
   {
      if(m1Fast[0] < m1Slow[0]) score++;
      if(m1Close < m1Fast[0]) score++;
      if(m1RSI[0] >= M1_RSIBearMin && m1RSI[0] <= M1_RSIBearMax) score++;
   }
   
   return score;
}

//+------------------------------------------------------------------+
void PlaceOrders(ENUM_ORDER_TYPE orderType, double basePrice, double fixedSL, double fixedTP,
                double ask, double bid, double minDist, datetime expTime)
{
   double entryPrice = NormalizeDouble(basePrice, _Digits);
   double slPrice, tpPrice;
   
   if(orderType == ORDER_TYPE_BUY_STOP || orderType == ORDER_TYPE_BUY_LIMIT)
   {
      if(orderType == ORDER_TYPE_BUY_STOP && entryPrice - ask < minDist)
         entryPrice = NormalizeDouble(ask + minDist, _Digits);
      if(orderType == ORDER_TYPE_BUY_LIMIT && ask - entryPrice < minDist)
         entryPrice = NormalizeDouble(ask - minDist, _Digits);
      
      slPrice = NormalizeDouble(entryPrice - fixedSL, _Digits);
      tpPrice = NormalizeDouble(entryPrice + fixedTP, _Digits);
   }
   else
   {
      if(orderType == ORDER_TYPE_SELL_STOP && bid - entryPrice < minDist)
         entryPrice = NormalizeDouble(bid - minDist, _Digits);
      if(orderType == ORDER_TYPE_SELL_LIMIT && entryPrice - bid < minDist)
         entryPrice = NormalizeDouble(bid + minDist, _Digits);
      
      slPrice = NormalizeDouble(entryPrice + fixedSL, _Digits);
      tpPrice = NormalizeDouble(entryPrice - fixedTP, _Digits);
   }
   
   double lotPerTrade = CalculateLotSize(orderType, entryPrice, slPrice);
   if(lotPerTrade <= 0.0) return;
   
   int tradesToPlace = InpTradesPerSignal;
   if(openPosCount + pendingCount + tradesToPlace > InpMaxExposure)
      tradesToPlace = InpMaxExposure - (openPosCount + pendingCount);
   
   if(tradesToPlace <= 0) return;
   
   // Calculate instant TP
   double instantTP = 0;
   if(UseInstantProfit)
   {
      double point = SymbolInfoDouble(tradingSymbol, SYMBOL_POINT);
      double slDist = MathAbs(entryPrice - slPrice);
      
      // Use smaller of: fixed pips or % of SL
      double instantPipsDist = InstantProfitPips * point * 10;
      double instantPercentDist = slDist * (InstantProfitPercent / 100.0);
      instantTP = MathMin(instantPipsDist, instantPercentDist);
   }
   
   int placed = 0;
   for(int i = 0; i < tradesToPlace; i++)
   {
      MqlTradeRequest req = {};
      MqlTradeResult res = {};
      
      req.action = TRADE_ACTION_PENDING;
      req.symbol = tradingSymbol;
      req.volume = lotPerTrade;
      req.price = entryPrice;
      req.sl = slPrice;
      req.tp = tpPrice;
      req.type = orderType;
      req.magic = Magic;
      req.expiration = expTime;
      req.type_time = ORDER_TIME_SPECIFIED;
      req.deviation = MaxSlippage;
      
      if(OrderSend(req, res))
      {
         placed++;
         
         // Store position data for instant TP tracking
         int idx = ArraySize(posData);
         ArrayResize(posData, idx + 1);
         posData[idx].ticket = res.order;
         posData[idx].entryPrice = entryPrice;
         posData[idx].stopLoss = slPrice;
         posData[idx].takeProfit = tpPrice;
         posData[idx].riskAmount = MathAbs(entryPrice - slPrice);
         posData[idx].instantTP = instantTP;
         posData[idx].trailingActive = false;
         posData[idx].instantTPHit = false;
         posData[idx].initialVolume = lotPerTrade;
         posData[idx].openTime = TimeCurrent();
      }
   }
   
   FileWriteString(logHandle, StringFormat("Placed %d orders | Entry=%.5f SL=%.5f TP=%.5f | InstantTP=%.5f\n", 
                                          placed, entryPrice, slPrice, tpPrice, instantTP));
   FileFlush(logHandle);
}

//+------------------------------------------------------------------+
void CheckInstantProfit()
{
   for(int i = ArraySize(posData) - 1; i >= 0; i--)
   {
      if(!PositionSelectByTicket(posData[i].ticket))
      {
         // Position closed, remove from tracking
         ArrayRemove(posData, i, 1);
         continue;
      }
      
      if(posData[i].instantTPHit) continue;
      
      long posType = PositionGetInteger(POSITION_TYPE);
      double currentPrice = (posType == POSITION_TYPE_BUY) ? 
                           SymbolInfoDouble(tradingSymbol, SYMBOL_BID) : 
                           SymbolInfoDouble(tradingSymbol, SYMBOL_ASK);
      
      double profit = 0;
      if(posType == POSITION_TYPE_BUY)
         profit = currentPrice - posData[i].entryPrice;
      else
         profit = posData[i].entryPrice - currentPrice;
      
      // Check if instant TP hit
      if(profit >= posData[i].instantTP)
      {
         if(ClosePartialOnProfit)
         {
            double currentVol = PositionGetDouble(POSITION_VOLUME);
            double closeVol = NormalizeDouble(currentVol * (PartialClosePercent / 100.0), 2);
            
            if(closeVol >= SymbolInfoDouble(tradingSymbol, SYMBOL_VOLUME_MIN))
            {
               if(trade.PositionClosePartial(posData[i].ticket, closeVol))
               {
                  posData[i].instantTPHit = true;
                  
                  FileWriteString(logHandle, StringFormat("INSTANT TP HIT! Closed %.2f%% at %.1f pips profit\n", 
                                             PartialClosePercent, profit / (SymbolInfoDouble(tradingSymbol, SYMBOL_POINT) * 10)));
                  FileFlush(logHandle);
               }
            }
         }
         else
         {
            // Close entire position
            if(trade.PositionClose(posData[i].ticket))
            {
               FileWriteString(logHandle, StringFormat("INSTANT TP - Full close at %.1f pips\n", 
                                          profit / (SymbolInfoDouble(tradingSymbol, SYMBOL_POINT) * 10)));
               FileFlush(logHandle);
               
               ArrayRemove(posData, i, 1);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
void ManageTrailingStops()
{
   for(int i = 0; i < ArraySize(posData); i++)
   {
      if(!PositionSelectByTicket(posData[i].ticket)) continue;
      
      long posType = PositionGetInteger(POSITION_TYPE);
      double currentPrice = (posType == POSITION_TYPE_BUY) ? 
                           SymbolInfoDouble(tradingSymbol, SYMBOL_BID) : 
                           SymbolInfoDouble(tradingSymbol, SYMBOL_ASK);
      double currentSL = PositionGetDouble(POSITION_SL);
      double currentTP = PositionGetDouble(POSITION_TP);
      
      // Calculate current R
      double currentR = 0;
      if(posData[i].riskAmount > 0)
      {
         if(posType == POSITION_TYPE_BUY)
            currentR = (currentPrice - posData[i].entryPrice) / posData[i].riskAmount;
         else
            currentR = (posData[i].entryPrice - currentPrice) / posData[i].riskAmount;
      }
      
      // Activate trailing at specified R
      if(currentR >= TrailActivationR)
      {
         double atr[];
         ArraySetAsSeries(atr, true);
         if(CopyBuffer(hATR, 0, 0, 1, atr) < 1) continue;
         
         double trailDist = atr[0] * TrailDistanceATR;
         double newSL = 0;
         bool needsUpdate = false;
         
         if(posType == POSITION_TYPE_BUY)
         {
            newSL = currentPrice - trailDist;
            if(newSL > currentSL) needsUpdate = true;
         }
         else
         {
            newSL = currentPrice + trailDist;
            if(newSL < currentSL || currentSL == 0) needsUpdate = true;
         }
         
         if(needsUpdate)
         {
            MqlTradeRequest req = {};
            MqlTradeResult res = {};
            
            req.action = TRADE_ACTION_SLTP;
            req.symbol = tradingSymbol;
            req.sl = NormalizeDouble(newSL, _Digits);
            req.tp = currentTP;
            req.magic = Magic;
            
            if(OrderSend(req, res))
            {
               posData[i].trailingActive = true;
               posData[i].stopLoss = newSL;
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
double CalculateLotSize(ENUM_ORDER_TYPE orderType, double entry, double sl)
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskPerTrade = balance * InpRiskPercent / 100.0 / InpTradesPerSignal;
   
   // Apply dynamic multiplier for micro accounts
   riskPerTrade *= dynamicLotMultiplier;
   
   double minLot = SymbolInfoDouble(tradingSymbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(tradingSymbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(tradingSymbol, SYMBOL_VOLUME_STEP);
   
   // Method 1: Use OrderCalcProfit
   double profit = 0.0;
   if(OrderCalcProfit(orderType, tradingSymbol, 1.0, entry, sl, profit) && MathAbs(profit) > 0.000001)
   {
      double lossPerLot = MathAbs(profit);
      double lot = riskPerTrade / lossPerLot;
      
      lot = MathFloor(lot / lotStep) * lotStep;
      
      // For micro accounts, ensure minimum lot
      if(accountSizeCategory == 0 && lot < minLot)
         lot = minLot;
      
      if(lot < minLot) lot = minLot;
      if(lot > maxLot) lot = maxLot;
      
      return NormalizeDouble(lot, 2);
   }
   
   // Method 2: Fallback calculation
   double pointDist = MathAbs(entry - sl) / SymbolInfoDouble(tradingSymbol, SYMBOL_POINT);
   double tickValue = SymbolInfoDouble(tradingSymbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(tradingSymbol, SYMBOL_TRADE_TICK_SIZE);
   double point = SymbolInfoDouble(tradingSymbol, SYMBOL_POINT);
   
   double valuePerPoint = (tickValue / tickSize) * point;
   double lossPerLot = pointDist * valuePerPoint;
   
   if(lossPerLot <= 0.0) return minLot;
   
   double lot = riskPerTrade / lossPerLot;
   lot = MathFloor(lot / lotStep) * lotStep;
   
   if(lot < minLot) lot = minLot;
   if(lot > maxLot) lot = maxLot;
   
   return NormalizeDouble(lot, 2);
}

//+------------------------------------------------------------------+
void UpdateCounts()
{
   openPosCount = 0;
   pendingCount = 0;
   
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionSelectByTicket(PositionGetTicket(i)))
      {
         if(PositionGetString(POSITION_SYMBOL) == tradingSymbol && 
            PositionGetInteger(POSITION_MAGIC) == Magic)
            openPosCount++;
      }
   }
   
   for(int i = 0; i < OrdersTotal(); i++)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket > 0 && OrderSelect(ticket))
      {
         if(OrderGetInteger(ORDER_MAGIC) == Magic && 
            OrderGetString(ORDER_SYMBOL) == tradingSymbol)
            pendingCount++;
      }
   }
}

//+------------------------------------------------------------------+
void CleanupExpired()
{
   datetime now = TimeCurrent();
   
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket > 0 && OrderSelect(ticket))
      {
         if(OrderGetInteger(ORDER_MAGIC) == Magic && 
            OrderGetString(ORDER_SYMBOL) == tradingSymbol)
         {
            datetime expiration = (datetime)OrderGetInteger(ORDER_TIME_EXPIRATION);
            
            if(expiration > 0 && now >= expiration)
            {
               trade.OrderDelete(ticket);
            }
         }
      }
   }
}
//+------------------------------------------------------------------+