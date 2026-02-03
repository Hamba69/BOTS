#property copyright "MIN2 - Optimized Fibonacci Scalper"
#property link " "
#property version "3.00"
#property description "Streamlined GoldScalper with efficient Fibonacci filters"
#property strict
#include <Trade\Trade.mqh>

//--- Scalping Parameters
input group "=== SCALPING PARAMETERS ==="
input double InpRiskPercent = 1.0;
input int InpMaxExposure = 50;
input int InpTradesPerSignal = 5;
input int InpFixedSL_Pips = 10;
input int InpFixedTP_Pips = 10;
input int InpEntryBufferPts = 5;
input int InpPendingExpirySec = 600;
input string InpSymbol = "";

//--- Fibonacci Filters
input group "=== FIBONACCI FILTERS ==="
input bool UseFibFilters = true;
input int MinFibConditions = 4;
input int FibEMAFast = 8;
input int FibEMASlow = 21;
input int FibRSIPeriod = 13;
input int FibATRPeriod = 13;
input double FibATRMin = 0.618;
input int FibMACDFast = 8;
input int FibMACDSlow = 21;
input int FibMACDSignal = 8;
input double FibRSIBullMin = 40.0;
input double FibRSIBullMax = 70.0;
input double FibRSIBearMin = 30.0;
input double FibRSIBearMax = 60.0;

// Constants
const long Magic = 987654;
const string LogFileName = "GoldScalperFib.log";

// Globals
CTrade trade;
int logHandle = INVALID_HANDLE;
long stopsLevel = 0;
long freezeLevel = 0;
datetime lastM5Bar = 0;
datetime lastCleanupTime = 0;
int openPosCount = 0;
int pendingCount = 0;

// Indicator handles
int hEMAFast = INVALID_HANDLE;
int hEMASlow = INVALID_HANDLE;
int hRSI = INVALID_HANDLE;
int hATR = INVALID_HANDLE;
int hMACD = INVALID_HANDLE;

//+------------------------------------------------------------------+
int OnInit()
{
   if(_Symbol != InpSymbol)
   {
      Print("EA must be attached to ", InpSymbol, " chart.");
      return INIT_FAILED;
   }
   
   logHandle = FileOpen(LogFileName, FILE_WRITE|FILE_TXT|FILE_COMMON);
   if(logHandle == INVALID_HANDLE)
   {
      Print("Failed to open log file.");
      return INIT_FAILED;
   }
   
   FileWriteString(logHandle, "=== GoldScalper Fib v3.0 Started ===\n");
   FileWriteString(logHandle, "Time: " + TimeToString(TimeCurrent()) + "\n");
   FileFlush(logHandle);
   
   stopsLevel = SymbolInfoInteger(InpSymbol, SYMBOL_TRADE_STOPS_LEVEL);
   freezeLevel = SymbolInfoInteger(InpSymbol, SYMBOL_TRADE_FREEZE_LEVEL);
   trade.SetExpertMagicNumber(Magic);
   
   if(UseFibFilters)
   {
      hEMAFast = iMA(InpSymbol, PERIOD_M5, FibEMAFast, 0, MODE_EMA, PRICE_CLOSE);
      hEMASlow = iMA(InpSymbol, PERIOD_M5, FibEMASlow, 0, MODE_EMA, PRICE_CLOSE);
      hRSI = iRSI(InpSymbol, PERIOD_M5, FibRSIPeriod, PRICE_CLOSE);
      hATR = iATR(InpSymbol, PERIOD_M5, FibATRPeriod);
      hMACD = iMACD(InpSymbol, PERIOD_M5, FibMACDFast, FibMACDSlow, FibMACDSignal, PRICE_CLOSE);
      
      if(hEMAFast == INVALID_HANDLE || hEMASlow == INVALID_HANDLE ||
         hRSI == INVALID_HANDLE || hATR == INVALID_HANDLE || hMACD == INVALID_HANDLE)
      {
         Print("ERROR: Failed to initialize Fibonacci indicators!");
         return INIT_FAILED;
      }
      
      FileWriteString(logHandle, "Fibonacci filters ENABLED\n");
      FileFlush(logHandle);
   }
   
   UpdateCounts();
   Print("GoldScalper Fibonacci v3.0 initialized successfully!");
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
   
   datetime currM5Bar = iTime(InpSymbol, PERIOD_M5, 0);
   if(currM5Bar == lastM5Bar) return;
   lastM5Bar = currM5Bar;
   
   UpdateCounts();
   
   if(openPosCount + pendingCount + InpTradesPerSignal > InpMaxExposure) return;
   
   // Get M15 directional bias
   MqlRates m15[];
   ArraySetAsSeries(m15, true);
   if(CopyRates(InpSymbol, PERIOD_M15, 1, 1, m15) != 1) return;
   
   bool bullish = m15[0].close > m15[0].open;
   bool bearish = m15[0].close < m15[0].open;
   
   if(!bullish && !bearish) return;
   
   // Fibonacci filter check
   if(UseFibFilters)
   {
      int fibScore = CheckFibonacciConditions(bullish);
      
      if(fibScore < MinFibConditions)
      {
         FileWriteString(logHandle, StringFormat("Fib REJECTED: %d/%d (min %d) - %s\n",
                                                 fibScore, 5, MinFibConditions, bullish ? "BULL" : "BEAR"));
         FileFlush(logHandle);
         return;
      }
      
      FileWriteString(logHandle, StringFormat("Fib PASSED: %d/%d - %s\n",
                                              fibScore, 5, bullish ? "BULL" : "BEAR"));
      FileFlush(logHandle);
   }
   
   // Get M5 previous bar for breakout
   MqlRates m5[];
   ArraySetAsSeries(m5, true);
   if(CopyRates(InpSymbol, PERIOD_M5, 0, 2, m5) != 2) return;
   
   double prevHigh = m5[1].high;
   double prevLow = m5[1].low;
   double point = SymbolInfoDouble(InpSymbol, SYMBOL_POINT);
   long spreadPts = SymbolInfoInteger(InpSymbol, SYMBOL_SPREAD);
   double entryBufferTotal = (InpEntryBufferPts + spreadPts) * point;
   
   long minDistPts = MathMax(stopsLevel, freezeLevel);
   double minDist = minDistPts * point;
   
   double ask = SymbolInfoDouble(InpSymbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(InpSymbol, SYMBOL_BID);
   datetime expTime = currTime + InpPendingExpirySec;
   
   double entryPrice, slPrice, tpPrice;
   ENUM_ORDER_TYPE orderType;
   
   double fixedSL = InpFixedSL_Pips * 0.10;
   double fixedTP = InpFixedTP_Pips * 0.10;
   
   if(bullish)
   {
      entryPrice = NormalizeDouble(prevHigh + entryBufferTotal, _Digits);
      if(entryPrice - ask < minDist) entryPrice = NormalizeDouble(ask + minDist, _Digits);
      slPrice = NormalizeDouble(entryPrice - fixedSL, _Digits);
      tpPrice = NormalizeDouble(entryPrice + fixedTP, _Digits);
      orderType = ORDER_TYPE_BUY_STOP;
   }
   else
   {
      entryPrice = NormalizeDouble(prevLow - entryBufferTotal, _Digits);
      if(bid - entryPrice < minDist) entryPrice = NormalizeDouble(bid - minDist, _Digits);
      slPrice = NormalizeDouble(entryPrice + fixedSL, _Digits);
      tpPrice = NormalizeDouble(entryPrice - fixedTP, _Digits);
      orderType = ORDER_TYPE_SELL_STOP;
   }
   
   double lotPerTrade = CalculateLotSize(orderType, entryPrice, slPrice);
   if(lotPerTrade <= 0.0) return;
   
   int tradesToPlace = InpTradesPerSignal;
   if(openPosCount + pendingCount + tradesToPlace > InpMaxExposure)
      tradesToPlace = InpMaxExposure - (openPosCount + pendingCount);
   
   if(tradesToPlace <= 0) return;
   
   // Place orders
   int placed = 0;
   for(int i = 0; i < tradesToPlace; i++)
   {
      MqlTradeRequest req = {};
      MqlTradeResult res = {};
      
      req.action = TRADE_ACTION_PENDING;
      req.symbol = InpSymbol;
      req.volume = lotPerTrade;
      req.price = entryPrice;
      req.sl = slPrice;
      req.tp = tpPrice;
      req.type = orderType;
      req.magic = Magic;
      req.expiration = expTime;
      req.type_time = ORDER_TIME_SPECIFIED;
      req.deviation = 10;
      
      if(OrderSend(req, res))
      {
         placed++;
         FileWriteString(logHandle, StringFormat("%s: #%I64u lot=%.2f E=%.3f SL=%.3f TP=%.3f\n",
                                                bullish ? "BUY" : "SELL", res.order, lotPerTrade, 
                                                entryPrice, slPrice, tpPrice));
      }
      else
      {
         FileWriteString(logHandle, StringFormat("FAIL: retcode=%u\n", res.retcode));
      }
      FileFlush(logHandle);
   }
   
   FileWriteString(logHandle, StringFormat("Placed %d/%d orders\n", placed, tradesToPlace));
   FileFlush(logHandle);
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
   
   double close = iClose(InpSymbol, PERIOD_M5, 1);
   
   if(bullishBias)
   {
      // 1. EMA alignment
      if(emaFast[0] > emaSlow[0]) score++;
      
      // 2. Price above EMAs
      if(close > emaFast[0] && close > emaSlow[0]) score++;
      
      // 3. RSI in bullish zone
      if(rsi[0] >= FibRSIBullMin && rsi[0] <= FibRSIBullMax) score++;
      
      // 4. MACD bullish
      if(macdMain[0] > macdSignal[0]) score++;
      
      // 5. ATR sufficient
      if(atr[0] >= FibATRMin) score++;
   }
   else
   {
      // 1. EMA alignment
      if(emaFast[0] < emaSlow[0]) score++;
      
      // 2. Price below EMAs
      if(close < emaFast[0] && close < emaSlow[0]) score++;
      
      // 3. RSI in bearish zone
      if(rsi[0] >= FibRSIBearMin && rsi[0] <= FibRSIBearMax) score++;
      
      // 4. MACD bearish
      if(macdMain[0] < macdSignal[0]) score++;
      
      // 5. ATR sufficient
      if(atr[0] >= FibATRMin) score++;
   }
   
   return score;
}

//+------------------------------------------------------------------+
double CalculateLotSize(ENUM_ORDER_TYPE orderType, double entry, double sl)
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskPerTrade = balance * InpRiskPercent / 100.0 / InpTradesPerSignal;
   
   double profit = 0.0;
   if(OrderCalcProfit(orderType, InpSymbol, 1.0, entry, sl, profit) && MathAbs(profit) > 0.000001)
   {
      double lossPerLot = MathAbs(profit);
      double lot = riskPerTrade / lossPerLot;
      
      double minLot = SymbolInfoDouble(InpSymbol, SYMBOL_VOLUME_MIN);
      double maxLot = SymbolInfoDouble(InpSymbol, SYMBOL_VOLUME_MAX);
      double lotStep = SymbolInfoDouble(InpSymbol, SYMBOL_VOLUME_STEP);
      
      lot = MathFloor(lot / lotStep) * lotStep;
      if(lot < minLot) lot = minLot;
      if(lot > maxLot) lot = maxLot;
      
      return NormalizeDouble(lot, 2);
   }
   
   // Fallback
   double pointDist = MathAbs(entry - sl) / SymbolInfoDouble(InpSymbol, SYMBOL_POINT);
   double valuePerPoint = 0.1;
   double lossPerLot = pointDist * valuePerPoint;
   if(lossPerLot <= 0.0) return 0.0;
   
   double lot = riskPerTrade / lossPerLot;
   double minLot = SymbolInfoDouble(InpSymbol, SYMBOL_VOLUME_MIN);
   double lotStep = SymbolInfoDouble(InpSymbol, SYMBOL_VOLUME_STEP);
   
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
         if(PositionGetString(POSITION_SYMBOL) == InpSymbol && 
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
            OrderGetString(ORDER_SYMBOL) == InpSymbol)
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
         if(OrderGetString(ORDER_SYMBOL) == InpSymbol && 
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