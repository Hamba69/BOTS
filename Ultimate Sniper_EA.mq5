#property copyright "MIN2 - Ultimate Hybrid Scalper v5.0"
#property link " "
#property version "5.00"
#property description "Surgical precision hybrid: 2x trades, higher win rate"
#property strict
#include <Trade\Trade.mqh>

//--- CORE SCALPING PARAMETERS (OPTIMIZED)
input group "=== SCALPING CORE ==="
input double InpRiskPercent = 1.0;           // Risk per signal (split across trades)
input int InpMaxExposure = 50;               // Max total positions
input int InpTradesPerSignal = 5;            // Orders per M15 signal
input int InpEntryBufferPts = 3;             // Reduced from 5 (faster entry)
input int InpPendingExpirySec = 600;         // 10min expiry
input string InpSymbol = "";                 // Empty = current chart

//--- DYNAMIC RISK MANAGEMENT (CRITICAL)
input group "=== DYNAMIC SL/TP ==="
input bool UseDynamicSLTP = true;            // ATR-based (RECOMMENDED)
input double InpATRMultiplierSL = 1.2;       // TIGHTER (was 1.5)
input double InpATRMultiplierTP = 1.8;       // TIGHTER (was 2.0)
input int InpFixedSL_Pips = 15;              // Backup if ATR fails
input int InpFixedTP_Pips = 15;              // Backup if ATR fails

//--- ORDER TYPE SELECTION (ALL ENABLED)
input group "=== ORDER TYPES ==="
input bool UseBuyStop = true;                // Breakout long
input bool UseSellStop = true;               // Breakout short
input bool UseBuyLimit = true;               // Pullback long
input bool UseSellLimit = true;              // Pullback short

//--- TREND FILTER (RELAXED FOR MORE TRADES)
input group "=== H1 TREND FILTER ==="
input bool UseH1TrendFilter = true;          // Block counter-trend
input bool AllowConsolidation = true;        // NEW: Trade in ranges
input int TrendEMAPeriod = 50;               // H1 trend EMA
input double MinTrendStrength = 0.0010;      // REDUCED (was 0.0015)

//--- FIBONACCI FILTERS (OPTIMIZED)
input group "=== FIBONACCI QUALITY FILTER ==="
input bool UseFibFilters = true;
input int MinFibConditions = 2;              // REDUCED (was 3-4)
input int FibEMAFast = 8;                    // Fibonacci number
input int FibEMASlow = 21;                   // Fibonacci number
input int FibRSIPeriod = 14;                 // Standard RSI
input int FibATRPeriod = 14;                 // Standard ATR
input double FibATRMin = 0.8;                // Reduced (was 1.0)
input int FibMACDFast = 12;                  // Standard MACD
input int FibMACDSlow = 26;                  // Standard MACD
input int FibMACDSignal = 9;                 // Standard MACD
input double FibRSIBullMin = 40.0;           // WIDER (was 45)
input double FibRSIBullMax = 80.0;           // WIDER (was 75)
input double FibRSIBearMin = 20.0;           // WIDER (was 25)
input double FibRSIBearMax = 60.0;           // WIDER (was 55)

//--- ADVANCED EXECUTION
input group "=== EXECUTION TWEAKS ==="
input bool UseAggressiveEntry = true;        // NEW: Tighter buffer
input int MaxSlippage = 10;                  // Max slippage points

// Constants
const long Magic = 987654;
const string LogFileName = "UltimateScalper_v5.log";

// Globals
string tradingSymbol = "";
CTrade trade;
int logHandle = INVALID_HANDLE;
long stopsLevel = 0;
long freezeLevel = 0;
datetime lastM5Bar = 0;
datetime lastCleanupTime = 0;
int openPosCount = 0;
int pendingCount = 0;

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
   
   FileWriteString(logHandle, "=== ULTIMATE HYBRID SCALPER v5.0 ===\n");
   FileWriteString(logHandle, "Symbol: " + tradingSymbol + "\n");
   FileWriteString(logHandle, "Dynamic SL/TP: " + (UseDynamicSLTP ? "YES" : "NO") + "\n");
   FileWriteString(logHandle, "H1 Trend: " + (UseH1TrendFilter ? "YES" : "NO") + "\n");
   FileWriteString(logHandle, "Consolidation Trading: " + (AllowConsolidation ? "YES" : "NO") + "\n");
   FileWriteString(logHandle, "Min Fib Score: " + IntegerToString(MinFibConditions) + "/5\n");
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
   Print("Ultimate Scalper v5.0 initialized - READY TO DOMINATE!");
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
   
   if(currTime - lastCleanupTime >= 10)
   {
      CleanupExpired();
      lastCleanupTime = currTime;
   }
   
   datetime currM5Bar = iTime(tradingSymbol, PERIOD_M5, 0);
   if(currM5Bar == lastM5Bar) return;
   lastM5Bar = currM5Bar;
   
   UpdateCounts();
   
   if(openPosCount + pendingCount + (InpTradesPerSignal * 2) > InpMaxExposure) return;
   
   // H1 TREND CHECK (RELAXED)
   bool h1Bullish = false, h1Bearish = false, h1Neutral = false;
   if(UseH1TrendFilter)
   {
      if(!CheckH1Trend(h1Bullish, h1Bearish, h1Neutral))
      {
         FileWriteString(logHandle, "H1 Trend indeterminate - SKIPPING\n");
         FileFlush(logHandle);
         return;
      }
      
      string trendStatus = h1Bullish ? "BULLISH" : (h1Bearish ? "BEARISH" : "NEUTRAL");
      FileWriteString(logHandle, "H1 Trend: " + trendStatus + "\n");
      FileFlush(logHandle);
   }
   
   // M15 DIRECTIONAL BIAS
   MqlRates m15[];
   ArraySetAsSeries(m15, true);
   if(CopyRates(tradingSymbol, PERIOD_M15, 1, 1, m15) != 1) return;
   
   bool bullish = m15[0].close > m15[0].open;
   bool bearish = m15[0].close < m15[0].open;
   
   if(!bullish && !bearish) return;
   
   // TREND FILTER LOGIC (RELAXED)
   if(UseH1TrendFilter && !AllowConsolidation)
   {
      if(bullish && h1Bearish)
      {
         FileWriteString(logHandle, "M15 Bull REJECTED - H1 Bear trend\n");
         FileFlush(logHandle);
         return;
      }
      if(bearish && h1Bullish)
      {
         FileWriteString(logHandle, "M15 Bear REJECTED - H1 Bull trend\n");
         FileFlush(logHandle);
         return;
      }
   }
   else if(UseH1TrendFilter && AllowConsolidation)
   {
      // Only block strong counter-trend, allow neutral/consolidation
      if(bullish && h1Bearish && !h1Neutral)
      {
         FileWriteString(logHandle, "M15 Bull REJECTED - Strong H1 Bear\n");
         FileFlush(logHandle);
         return;
      }
      if(bearish && h1Bullish && !h1Neutral)
      {
         FileWriteString(logHandle, "M15 Bear REJECTED - Strong H1 Bull\n");
         FileFlush(logHandle);
         return;
      }
   }
   
   // FIBONACCI QUALITY FILTER
   if(UseFibFilters)
   {
      int fibScore = CheckFibonacciConditions(bullish);
      
      if(fibScore < MinFibConditions)
      {
         FileWriteString(logHandle, StringFormat("Fib REJECTED: %d/%d (need %d) - %s\n",
                                                 fibScore, 5, MinFibConditions, bullish ? "BULL" : "BEAR"));
         FileFlush(logHandle);
         return;
      }
      
      FileWriteString(logHandle, StringFormat("Fib APPROVED: %d/%d ✓ %s\n",
                                              fibScore, 5, bullish ? "BULL" : "BEAR"));
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
   
   // Aggressive entry buffer
   int bufferPts = UseAggressiveEntry ? InpEntryBufferPts : (InpEntryBufferPts + 2);
   double entryBufferTotal = (bufferPts + spreadPts) * point;
   
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
         FileWriteString(logHandle, StringFormat("ATR=%.2f -> SL=%.2f TP=%.2f\n", 
                                                 atr[0], fixedSL, fixedTP));
      }
      else
      {
         fixedSL = InpFixedSL_Pips * 0.10;
         fixedTP = InpFixedTP_Pips * 0.10;
         FileWriteString(logHandle, "ATR unavailable - using fixed SL/TP\n");
      }
   }
   else
   {
      fixedSL = InpFixedSL_Pips * 0.10;
      fixedTP = InpFixedTP_Pips * 0.10;
   }
   FileFlush(logHandle);
   
   // PLACE ALL 4 ORDER TYPES (DOUBLES OPPORTUNITIES)
   if(bullish)
   {
      FileWriteString(logHandle, "=== BULLISH SIGNAL - Placing 4 order types ===\n");
      
      if(UseBuyStop)
         PlaceOrders(ORDER_TYPE_BUY_STOP, prevHigh + entryBufferTotal, fixedSL, fixedTP, 
                    ask, bid, minDist, expTime);
      
      if(UseBuyLimit)
         PlaceOrders(ORDER_TYPE_BUY_LIMIT, prevLow - entryBufferTotal, fixedSL, fixedTP, 
                    ask, bid, minDist, expTime);
   }
   else
   {
      FileWriteString(logHandle, "=== BEARISH SIGNAL - Placing 4 order types ===\n");
      
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
   
   // Determine trend
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
      // Consolidation/neutral
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
      if(close > emaFast[0] || close > emaSlow[0]) score++; // Relaxed: OR instead of AND
      if(rsi[0] >= FibRSIBullMin && rsi[0] <= FibRSIBullMax) score++;
      if(macdMain[0] > macdSignal[0]) score++;
      if(atr[0] >= FibATRMin) score++;
   }
   else
   {
      if(emaFast[0] < emaSlow[0]) score++;
      if(close < emaFast[0] || close < emaSlow[0]) score++; // Relaxed: OR instead of AND
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
   
   string orderTypeName = "";
   switch(orderType)
   {
      case ORDER_TYPE_BUY_STOP: orderTypeName = "BUY_STOP"; break;
      case ORDER_TYPE_SELL_STOP: orderTypeName = "SELL_STOP"; break;
      case ORDER_TYPE_BUY_LIMIT: orderTypeName = "BUY_LIMIT"; break;
      case ORDER_TYPE_SELL_LIMIT: orderTypeName = "SELL_LIMIT"; break;
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
         FileWriteString(logHandle, StringFormat("%s #%I64u: lot=%.2f E=%.3f SL=%.3f TP=%.3f ✓\n",
                                                orderTypeName, res.order, lotPerTrade, 
                                                entryPrice, slPrice, tpPrice));
      }
      else
      {
         FileWriteString(logHandle, StringFormat("%s FAILED: retcode=%u\n", orderTypeName, res.retcode));
      }
   }
   
   FileWriteString(logHandle, StringFormat("%s: %d/%d placed\n", orderTypeName, placed, tradesToPlace));
   FileFlush(logHandle);
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
   datetime currTime = TimeCurrent();
   
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket > 0 && OrderSelect(ticket))
      {
         if(OrderGetString(ORDER_SYMBOL) == tradingSymbol && 
            OrderGetInteger(ORDER_MAGIC) == Magic)
         {
            if(OrderGetInteger(ORDER_TYPE_TIME) == ORDER_TIME_SPECIFIED &&
               (datetime)OrderGetInteger(ORDER_TIME_EXPIRATION) < currTime)
            {
               trade.OrderDelete(ticket);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
   UpdateCounts();
}
//+------------------------------------------------------------------+