//+------------------------------------------------------------------+
//|                          Elite_Hybrid_Scalper_v6.mq5             |
//|                     Optimized Multi-Strategy Fusion              |
//+------------------------------------------------------------------+
#property copyright "MIN2 - Elite Hybrid Scalper v6.0"
#property link ""
#property version "6.00"
#property description "Fusion: H4 trend + M15 signals + M5 execution + Fibonacci filters"
#property strict
#include <Trade\Trade.mqh>

//--- CORE PARAMETERS
input group "=== RISK & EXPOSURE ==="
input double InpRiskPercent = 1.0;                // Risk per signal (%)
input int InpMaxExposure = 30;                    // Max total positions
input int InpTradesPerSignal = 3;                 // Orders per signal
input string InpSymbol = "";                      // Empty = current chart

//--- DYNAMIC SL/TP
input group "=== STOP LOSS & TAKE PROFIT ==="
input bool UseDynamicSLTP = true;                 // Use ATR-based levels
input double InpATRMultiplierSL = 1.2;            // SL ATR Multiplier
input double InpATRMultiplierTP = 2.0;            // TP ATR Multiplier (1:1.67 R:R)
input int InpFixedSL_Pips = 12;                   // Backup SL (pips)
input int InpFixedTP_Pips = 20;                   // Backup TP (pips)
input bool UseTrailingStop = true;                // Enable trailing stop
input double TrailActivationR = 1.2;              // Trail activation (R multiple)
input double TrailDistanceATR = 0.5;              // Trail distance (ATR)

//--- ORDER TYPES
input group "=== ORDER EXECUTION ==="
input bool UseBuyStop = true;                     // Breakout long
input bool UseSellStop = true;                    // Breakout short
input bool UseBuyLimit = false;                   // Pullback long (optional)
input bool UseSellLimit = false;                  // Pullback short (optional)
input int InpEntryBufferPts = 3;                  // Entry buffer points
input int InpPendingExpirySec = 900;              // Pending expiry (15min)
input int MaxSlippage = 10;                       // Max slippage points

//--- H4 TREND FILTER (CRITICAL)
input group "=== H4 TREND FILTER ==="
input bool UseH4TrendFilter = true;              // Enforce H4 trend
input int TrendEMAPeriod = 50;                   // H4 EMA period
input double MinTrendStrength = 0.0008;          // Min % move for trend
input bool AllowNeutralTrend = true;             // Trade in consolidation

//--- FIBONACCI QUALITY FILTER
input group "=== FIBONACCI FILTERS (M5) ==="
input bool UseFibFilters = true;                 // Enable Fib filters
input int MinFibConditions = 3;                  // Min conditions (of 5)
input int FibEMAFast = 8;                        // EMA Fast (Fibonacci)
input int FibEMASlow = 21;                       // EMA Slow (Fibonacci)
input int FibRSIPeriod = 14;                     // RSI Period
input int FibATRPeriod = 14;                     // ATR Period
input double FibATRMin = 0.5;                    // Min ATR value
input int FibMACDFast = 12;                      // MACD Fast
input int FibMACDSlow = 26;                      // MACD Slow
input int FibMACDSignal = 9;                     // MACD Signal
input double FibRSIBullMin = 40.0;               // RSI Bull Min
input double FibRSIBullMax = 80.0;               // RSI Bull Max
input double FibRSIBearMin = 20.0;               // RSI Bear Min
input double FibRSIBearMax = 60.0;               // RSI Bear Max

//--- RISK LIMITS
input group "=== RISK MANAGEMENT ==="
input double MaxDailyLoss = 3.0;                 // Max daily loss (%)
input int MaxConsecutiveLosses = 3;              // Max consecutive losses
input int MaxDailyTrades = 10;                   // Max trades per day

// Constants
const long Magic = 987650;
const string LogFileName = "EliteHybrid_v6.log";

// Globals
string tradingSymbol = "";
CTrade trade;
int logHandle = INVALID_HANDLE;
long stopsLevel = 0;
long freezeLevel = 0;
datetime lastM5Bar = 0;
datetime lastCleanupTime = 0;
datetime dailyResetTime = 0;
int openPosCount = 0;
int pendingCount = 0;
double dailyStartBalance = 0;
double dailyPL = 0;
int dailyTradeCount = 0;
int consecutiveLosses = 0;
bool isTradingAllowed = true;

// Position tracking for trailing
struct PositionData {
   double entryPrice;
   double stopLoss;
   double riskAmount;
   bool trailingActive;
};
PositionData posData;

// Indicators
int hEMAFast = INVALID_HANDLE;
int hEMASlow = INVALID_HANDLE;
int hRSI = INVALID_HANDLE;
int hATR = INVALID_HANDLE;
int hMACD = INVALID_HANDLE;
int hTrendEMA = INVALID_HANDLE;

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
   
   FileWriteString(logHandle, "=== ELITE HYBRID SCALPER v6.0 ===\n");
   FileWriteString(logHandle, "Symbol: " + tradingSymbol + "\n");
   FileWriteString(logHandle, "Strategy: H4 trend + M15 bias + M5 execution\n");
   FileWriteString(logHandle, "Dynamic SL/TP: " + (UseDynamicSLTP ? "YES" : "NO") + "\n");
   FileWriteString(logHandle, "Target R:R: 1:" + DoubleToString(InpATRMultiplierTP/InpATRMultiplierSL, 2) + "\n");
   FileFlush(logHandle);
   
   stopsLevel = SymbolInfoInteger(tradingSymbol, SYMBOL_TRADE_STOPS_LEVEL);
   freezeLevel = SymbolInfoInteger(tradingSymbol, SYMBOL_TRADE_FREEZE_LEVEL);
   trade.SetExpertMagicNumber(Magic);
   trade.SetDeviationInPoints(MaxSlippage);
   
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
   
   if(UseH4TrendFilter)
   {
      hTrendEMA = iMA(tradingSymbol, PERIOD_H1, TrendEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
      if(hTrendEMA == INVALID_HANDLE)
      {
         Print("ERROR: Failed to create H1 trend EMA");
         return INIT_FAILED;
      }
   }
   
   UpdateCounts();
   dailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   dailyResetTime = TimeCurrent();
   
   Print("Elite Hybrid Scalper v6.0 initialized - READY!");
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
      FileWriteString(logHandle, StringFormat("Max consecutive losses (%d) - Manual review required\n", consecutiveLosses));
      FileFlush(logHandle);
   }
   
   if(dailyTradeCount >= MaxDailyTrades)
   {
      isTradingAllowed = false;
   }
   
   // Cleanup expired orders
   if(currTime - lastCleanupTime >= 10)
   {
      CleanupExpired();
      lastCleanupTime = currTime;
   }
   
   // Manage existing positions
   if(PositionSelect(tradingSymbol))
   {
      ManagePosition();
   }
   
   // New bar check for entries
   datetime currM5Bar = iTime(tradingSymbol, PERIOD_M5, 0);
   if(currM5Bar == lastM5Bar) return;
   lastM5Bar = currM5Bar;
   
   UpdateCounts();
   
   if(!isTradingAllowed) return;
   if(openPosCount + pendingCount + (InpTradesPerSignal * 2) > InpMaxExposure) return;
   
   // H1 TREND FILTER
   bool h1Bullish = false, h1Bearish = false, h1Neutral = false;
   if(UseH4TrendFilter)
   {
      if(!CheckH1Trend(h1Bullish, h1Bearish, h1Neutral))
      {
         return;
      }
   }
   
   // M15 DIRECTIONAL BIAS
   MqlRates m15[];
   ArraySetAsSeries(m15, true);
   if(CopyRates(tradingSymbol, PERIOD_M15, 1, 1, m15) != 1) return;
   
   bool bullish = m15[0].close > m15[0].open;
   bool bearish = m15[0].close < m15[0].open;
   
   if(!bullish && !bearish) return;
   
   // TREND ALIGNMENT CHECK
   if(UseH4TrendFilter && !AllowNeutralTrend)
   {
      if(bullish && h1Bearish) return;
      if(bearish && h1Bullish) return;
   }
   
   // FIBONACCI QUALITY FILTER
   if(UseFibFilters)
   {
      int fibScore = CheckFibonacciConditions(bullish);
      
      if(fibScore < MinFibConditions)
      {
         FileWriteString(logHandle, StringFormat("Fib REJECTED: %d/%d (need %d)\n", fibScore, 5, MinFibConditions));
         FileFlush(logHandle);
         return;
      }
      
      FileWriteString(logHandle, StringFormat("Fib APPROVED: %d/%d ✓\n", fibScore, 5));
      FileFlush(logHandle);
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
   datetime expTime = currTime + InpPendingExpirySec;
   
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
         fixedSL = InpFixedSL_Pips * 0.10;
         fixedTP = InpFixedTP_Pips * 0.10;
      }
   }
   else
   {
      fixedSL = InpFixedSL_Pips * 0.10;
      fixedTP = InpFixedTP_Pips * 0.10;
   }
   
   // PLACE ORDERS
   if(bullish)
   {
      FileWriteString(logHandle, "=== BULLISH SIGNAL ===\n");
      
      if(UseBuyStop)
         PlaceOrders(ORDER_TYPE_BUY_STOP, prevHigh + entryBufferTotal, fixedSL, fixedTP, 
                    ask, bid, minDist, expTime);
      
      if(UseBuyLimit)
         PlaceOrders(ORDER_TYPE_BUY_LIMIT, prevLow - entryBufferTotal, fixedSL, fixedTP, 
                    ask, bid, minDist, expTime);
   }
   else
   {
      FileWriteString(logHandle, "=== BEARISH SIGNAL ===\n");
      
      if(UseSellStop)
         PlaceOrders(ORDER_TYPE_SELL_STOP, prevLow - entryBufferTotal, fixedSL, fixedTP, 
                    ask, bid, minDist, expTime);
      
      if(UseSellLimit)
         PlaceOrders(ORDER_TYPE_SELL_LIMIT, prevHigh + entryBufferTotal, fixedSL, fixedTP, 
                    ask, bid, minDist, expTime);
   }
   
   FileWriteString(logHandle, "========================================\n\n");
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
         
         // Initialize position tracking when first order fills
         if(i == 0)
         {
            posData.entryPrice = entryPrice;
            posData.stopLoss = slPrice;
            posData.riskAmount = MathAbs(entryPrice - slPrice);
            posData.trailingActive = false;
         }
      }
   }
   
   FileWriteString(logHandle, StringFormat("Placed %d/%d orders | Entry=%.3f SL=%.3f TP=%.3f\n", 
                                          placed, tradesToPlace, entryPrice, slPrice, tpPrice));
   FileFlush(logHandle);
}

//+------------------------------------------------------------------+
void ManagePosition()
{
   if(!UseTrailingStop) return;
   
   long posType = PositionGetInteger(POSITION_TYPE);
   double currentPrice = (posType == POSITION_TYPE_BUY) ? 
                        SymbolInfoDouble(tradingSymbol, SYMBOL_BID) : 
                        SymbolInfoDouble(tradingSymbol, SYMBOL_ASK);
   double currentSL = PositionGetDouble(POSITION_SL);
   double currentTP = PositionGetDouble(POSITION_TP);
   
   // Calculate current R
   double currentR = 0;
   if(posData.riskAmount > 0)
   {
      if(posType == POSITION_TYPE_BUY)
         currentR = (currentPrice - posData.entryPrice) / posData.riskAmount;
      else
         currentR = (posData.entryPrice - currentPrice) / posData.riskAmount;
   }
   
   // Activate trailing at specified R
   if(currentR >= TrailActivationR)
   {
      double atr[];
      ArraySetAsSeries(atr, true);
      if(CopyBuffer(hATR, 0, 0, 1, atr) < 1) return;
      
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
            posData.trailingActive = true;
         }
      }
   }
}

//+------------------------------------------------------------------+
double CalculateLotSize(ENUM_ORDER_TYPE orderType, double entry, double sl)
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskPerTrade = balance * InpRiskPercent / 100.0 / InpTradesPerSignal;
   
   double profit = 0.0;
   if(OrderCalcProfit(orderType, tradingSymbol, 1.0, entry, sl, profit) && MathAbs(profit) > 0.000001)
   {
      double lossPerLot = MathAbs(profit);
      double lot = riskPerTrade / lossPerLot;
      
      double minLot = SymbolInfoDouble(tradingSymbol, SYMBOL_VOLUME_MIN);
      double maxLot = SymbolInfoDouble(tradingSymbol, SYMBOL_VOLUME_MAX);
      double lotStep = SymbolInfoDouble(tradingSymbol, SYMBOL_VOLUME_STEP);
      
      lot = MathFloor(lot / lotStep) * lotStep;
      if(lot < minLot) lot = minLot;
      if(lot > maxLot) lot = maxLot;
      
      return NormalizeDouble(lot, 2);
   }
   
   double pointDist = MathAbs(entry - sl) / SymbolInfoDouble(tradingSymbol, SYMBOL_POINT);
   double valuePerPoint = 0.1;
   double lossPerLot = pointDist * valuePerPoint;
   if(lossPerLot <= 0.0) return 0.0;
   
   double lot = riskPerTrade / lossPerLot;
   double minLot = SymbolInfoDouble(tradingSymbol, SYMBOL_VOLUME_MIN);
   double lotStep = SymbolInfoDouble(tradingSymbol, SYMBOL_VOLUME_STEP);
   
   lot = MathFloor(lot / lotStep) * lotStep;
   if(lot < minLot) lot = minLot;
   
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