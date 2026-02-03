//+------------------------------------------------------------------+
//|                          VAIS_EA_H4_Only.mq5                     |
//|                  Fibonacci-Based H4 Trading System               |
//|              Pure H4 Execution with Fibonacci Indicators         |
//+------------------------------------------------------------------+
#property copyright "VAIS Fibonacci H4 System"
#property link      ""
#property version   "5.10"
#property description "Pure H4 execution with Fibonacci indicators"
#property description "Target: 55-60% win rate | R:R 1:2.5+"

//--- Input Parameters
input group "=== SYSTEM IDENTIFICATION ==="
input string EA_Name = "VAIS_Fib_H4_v5.1";        // EA Name
input int MagicNumber = 100005;                    // Magic Number
input bool EnableTrading = true;                   // Enable Trading
input bool Force_Allow_Any_Timeframe = false;     // Allow Non-H4 Timeframes

input group "=== FIBONACCI INDICATORS - H4 ==="
input int H4_EMA_Fast = 8;                        // H4 EMA Fast (Fibonacci)
input int H4_EMA_Slow = 21;                       // H4 EMA Slow (Fibonacci)
input int H4_RSI_Period = 13;                     // H4 RSI (Fibonacci)
input int H4_ATR_Period = 13;                     // H4 ATR (Fibonacci)
input int H4_BB_Period = 21;                      // H4 BB Period (Fibonacci)
input double H4_BB_Deviation = 1.618;             // H4 BB Deviation (Golden Ratio)
input int H4_MACD_Fast = 8;                       // H4 MACD Fast (Fibonacci)
input int H4_MACD_Slow = 21;                      // H4 MACD Slow (Fibonacci)
input int H4_MACD_Signal = 8;                     // H4 MACD Signal (Fibonacci)

input group "=== H4 ENTRY FILTERS ==="
input int Min_Conditions_Met = 4;                 // Minimum Conditions Required
input double EMA_Pullback_ATR = 0.618;            // EMA Pullback (ATR) - Golden Ratio
input double H4_RSI_Long_Min = 40.0;              // H4 RSI Long Min
input double H4_RSI_Long_Max = 65.0;              // H4 RSI Long Max
input double H4_RSI_Short_Min = 35.0;             // H4 RSI Short Min
input double H4_RSI_Short_Max = 60.0;             // H4 RSI Short Max
input double ATR_Min_H4 = 0.618;                  // Min H4 ATR (Fibonacci)
input bool Use_BB_Filter = true;                  // Use Bollinger Bands Filter
input bool Use_MACD_Filter = true;                // Use MACD Filter
input double Volume_Spike = 1.382;                // Volume Spike (Fibonacci)

input group "=== STOP LOSS & TAKE PROFIT ==="
input double SL_ATR_Multiple = 1.0;               // Stop Loss (ATR Multiple)
input double TP_ATR_Multiple = 2.618;             // Take Profit (Golden Ratio)
input bool Use_Partial_Exit = true;               // Use Partial Exit
input double Partial_Exit_R = 1.618;              // Partial Exit R (Golden Ratio)
input double Partial_Exit_Percent = 50.0;         // Partial Exit %
input bool Use_Trailing_Stop = true;              // Use Trailing Stop
input double Trail_Activation_R = 1.618;          // Trail Activation (Golden Ratio)
input double Trail_Distance_ATR = 0.618;          // Trail Distance (Golden Ratio)

input group "=== RISK MANAGEMENT ==="
input double Risk_Per_Trade = 1.0;                // Risk Per Trade (%)
input double Max_Weekly_Trades = 3;               // Max Trades Per Week
input double Max_Daily_Loss = 3.0;                // Max Daily Loss (%)
input double Max_Weekly_Loss = 8.0;               // Max Weekly Loss (%)
input int Max_Consecutive_Losses = 3;             // Max Consecutive Losses
input double Max_Lot_Size = 0.5;                  // Maximum Lot Size

input group "=== TRADING SCHEDULE (UTC) ==="
input int Trading_Start_Hour = 0;                 // Trading Start Hour
input int Trading_End_Hour = 23;                  // Trading End Hour
input bool Trade_Monday = true;                   // Trade on Monday
input bool Trade_Tuesday = true;                  // Trade on Tuesday
input bool Trade_Wednesday = true;                // Trade on Wednesday
input bool Trade_Thursday = true;                 // Trade on Thursday
input bool Trade_Friday = true;                   // Trade on Friday

input group "=== MARKET CONDITIONS ==="
input double Max_Spread = 5.0;                    // Maximum Spread (Pips)

input group "=== NOTIFICATIONS ==="
input bool Alert_On_Entry = true;                 // Alert on Entry
input bool Alert_On_Exit = true;                  // Alert on Exit
input bool Log_Analysis = true;                   // Log Analysis
input bool Send_Weekly_Summary = true;            // Send Weekly Summary

//--- Global Variables - H4 Indicators
int handle_H4_EMA_Fast, handle_H4_EMA_Slow, handle_H4_RSI, handle_H4_ATR;
int handle_H4_BB, handle_H4_MACD;
double h4_ema_fast[], h4_ema_slow[], h4_rsi[], h4_atr[];
double h4_bb_upper[], h4_bb_middle[], h4_bb_lower[];
double h4_macd_main[], h4_macd_signal[], h4_macd_histogram[];

//--- Account Management
double accountBalance, accountEquity, startingBalance;
double dailyStartBalance, weeklyStartBalance;
double dailyPL = 0, weeklyPL = 0;
int consecutiveLosses = 0;
int totalTrades = 0, winningTrades = 0, losingTrades = 0;
int weeklyTradeCount = 0;

datetime lastTradeTime = 0;
datetime dailyResetTime = 0;
datetime weeklyResetTime = 0;
datetime lastBarTime = 0;

bool isTradingAllowed = true;
bool isDailyLossLimitReached = false;
bool isWeeklyLossLimitReached = false;

//--- Position Management
double positionEntryPrice = 0;
double positionRisk = 0;
bool partialExitExecuted = false;

//--- Support/Resistance Levels
double supportLevels[10];
double resistanceLevels[10];
int srCount = 0;
int SR_Lookback = 89; // Fibonacci number

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("========================================");
   Print("=== VAIS FIBONACCI H4 SYSTEM V5.1 ===");
   Print("========================================");
   Print("Strategy: Pure H4 Fibonacci Execution");
   Print("Symbol: ", _Symbol);
   Print("Timeframe: H4");
   Print("");
   
   //--- Verify symbol
   if(_Symbol != "XAUUSD" && _Symbol != "XAUUSD.raw" && StringFind(_Symbol, "GOLD") < 0)
   {
      Print("WARNING: Optimized for XAUUSD (Gold)!");
      Print("Current symbol: ", _Symbol);
   }
   
   //--- Verify timeframe
   if(_Period != PERIOD_H4 && !Force_Allow_Any_Timeframe)
   {
      Alert("CRITICAL: This EA MUST run on H4 chart!");
      Alert("Set 'Force_Allow_Any_Timeframe=true' to override");
      return(INIT_FAILED);
   }
   
   //--- Initialize H4 indicators
   Print("Initializing H4 Fibonacci indicators...");
   handle_H4_EMA_Fast = iMA(_Symbol, PERIOD_H4, H4_EMA_Fast, 0, MODE_EMA, PRICE_CLOSE);
   handle_H4_EMA_Slow = iMA(_Symbol, PERIOD_H4, H4_EMA_Slow, 0, MODE_EMA, PRICE_CLOSE);
   handle_H4_RSI = iRSI(_Symbol, PERIOD_H4, H4_RSI_Period, PRICE_CLOSE);
   handle_H4_ATR = iATR(_Symbol, PERIOD_H4, H4_ATR_Period);
   handle_H4_BB = iBands(_Symbol, PERIOD_H4, H4_BB_Period, 0, H4_BB_Deviation, PRICE_CLOSE);
   handle_H4_MACD = iMACD(_Symbol, PERIOD_H4, H4_MACD_Fast, H4_MACD_Slow, H4_MACD_Signal, PRICE_CLOSE);
   
   if(handle_H4_EMA_Fast == INVALID_HANDLE || handle_H4_EMA_Slow == INVALID_HANDLE ||
      handle_H4_RSI == INVALID_HANDLE || handle_H4_ATR == INVALID_HANDLE ||
      handle_H4_BB == INVALID_HANDLE || handle_H4_MACD == INVALID_HANDLE)
   {
      Print("ERROR: Failed to create H4 indicators!");
      return(INIT_FAILED);
   }
   
   //--- Initialize arrays
   ArraySetAsSeries(h4_ema_fast, true);
   ArraySetAsSeries(h4_ema_slow, true);
   ArraySetAsSeries(h4_rsi, true);
   ArraySetAsSeries(h4_atr, true);
   ArraySetAsSeries(h4_bb_upper, true);
   ArraySetAsSeries(h4_bb_middle, true);
   ArraySetAsSeries(h4_bb_lower, true);
   ArraySetAsSeries(h4_macd_main, true);
   ArraySetAsSeries(h4_macd_signal, true);
   ArraySetAsSeries(h4_macd_histogram, true);
   
   //--- Initialize account
   accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   startingBalance = accountBalance;
   dailyStartBalance = accountBalance;
   weeklyStartBalance = accountBalance;
   dailyResetTime = TimeCurrent();
   weeklyResetTime = TimeCurrent();
   lastBarTime = iTime(_Symbol, PERIOD_H4, 0);
   
   Print("");
   Print("=== FIBONACCI CONFIGURATION ===");
   Print("H4 EMAs: ", H4_EMA_Fast, " / ", H4_EMA_Slow, " (Fib: 8/21)");
   Print("RSI Period: ", H4_RSI_Period, " (Fib: 13)");
   Print("ATR Period: ", H4_ATR_Period, " (Fib: 13)");
   Print("BB: Period=", H4_BB_Period, " Dev=", H4_BB_Deviation, " (Fib: 21/φ)");
   Print("MACD: ", H4_MACD_Fast, "/", H4_MACD_Slow, "/", H4_MACD_Signal, " (Fib: 8/21/8)");
   Print("");
   Print("=== GOLDEN RATIOS ===");
   Print("Pullback Zone: ", EMA_Pullback_ATR, " ATR (0.618 = φ⁻¹)");
   Print("TP Multiple: ", TP_ATR_Multiple, " ATR (2.618 = φ²)");
   Print("Partial Exit: ", Partial_Exit_R, "R (1.618 = φ)");
   Print("Trail Activation: ", Trail_Activation_R, "R (1.618 = φ)");
   Print("Volume Spike: ", Volume_Spike, "x (1.382)");
   Print("");
   Print("Risk per Trade: ", Risk_Per_Trade, "%");
   Print("Target R:R: 1:", DoubleToString(TP_ATR_Multiple/SL_ATR_Multiple, 2));
   Print("Account Balance: $", DoubleToString(accountBalance, 2));
   Print("");
   Print("=== Initialization Complete ===");
   Print("========================================");
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //--- Release indicators
   if(handle_H4_EMA_Fast != INVALID_HANDLE) IndicatorRelease(handle_H4_EMA_Fast);
   if(handle_H4_EMA_Slow != INVALID_HANDLE) IndicatorRelease(handle_H4_EMA_Slow);
   if(handle_H4_RSI != INVALID_HANDLE) IndicatorRelease(handle_H4_RSI);
   if(handle_H4_ATR != INVALID_HANDLE) IndicatorRelease(handle_H4_ATR);
   if(handle_H4_BB != INVALID_HANDLE) IndicatorRelease(handle_H4_BB);
   if(handle_H4_MACD != INVALID_HANDLE) IndicatorRelease(handle_H4_MACD);
   
   Print("");
   Print("=== VAIS FIBONACCI H4 STOPPED ===");
   Print("Total Trades: ", totalTrades);
   Print("Wins: ", winningTrades, " | Losses: ", losingTrades);
   if(totalTrades > 0)
      Print("Win Rate: ", DoubleToString((double)winningTrades/totalTrades*100, 2), "%");
   Print("Final P/L: $", DoubleToString(accountBalance - startingBalance, 2));
   Print("========================================");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- Check for new H4 bar
   datetime currentBarTime = iTime(_Symbol, PERIOD_H4, 0);
   bool isNewBar = (currentBarTime != lastBarTime);
   
   if(isNewBar)
   {
      lastBarTime = currentBarTime;
      
      UpdateAccountInfo();
      CheckRiskLimits();
      
      if(!EnableTrading || !isTradingAllowed) return;
      if(!IsTradingTime()) return;
      if(weeklyTradeCount >= Max_Weekly_Trades) return;
      
      if(!UpdateIndicators()) return;
      if(!CheckMarketConditions()) return;
      
      CalculateSupportResistance();
      
      if(PositionSelect(_Symbol))
         ManagePosition();
      else
         CheckEntrySignals();
   }
   else
   {
      if(PositionSelect(_Symbol))
         ManagePosition();
   }
}

//+------------------------------------------------------------------+
//| Update Account Information                                        |
//+------------------------------------------------------------------+
void UpdateAccountInfo()
{
   accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   accountEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   
   MqlDateTime currentTime;
   TimeToStruct(TimeCurrent(), currentTime);
   MqlDateTime resetTime;
   TimeToStruct(dailyResetTime, resetTime);
   
   if(currentTime.day != resetTime.day)
   {
      dailyPL = 0;
      dailyStartBalance = accountBalance;
      dailyResetTime = TimeCurrent();
      isDailyLossLimitReached = false;
   }
   
   if(currentTime.day_of_week == 1 && resetTime.day_of_week != 1)
   {
      if(Send_Weekly_Summary && totalTrades > 0)
      {
         string summary = StringFormat("VAIS Weekly: Trades=%d, WR=%.1f%%, P/L=$%.2f", 
                                      weeklyTradeCount, 
                                      (double)winningTrades/totalTrades*100, 
                                      weeklyPL);
         Print(summary);
         if(Alert_On_Exit) Alert(summary);
      }
      
      weeklyPL = 0;
      weeklyStartBalance = accountBalance;
      weeklyResetTime = TimeCurrent();
      isWeeklyLossLimitReached = false;
      weeklyTradeCount = 0;
   }
   
   dailyPL = accountBalance - dailyStartBalance;
   weeklyPL = accountBalance - weeklyStartBalance;
}

//+------------------------------------------------------------------+
//| Check Risk Limits                                                |
//+------------------------------------------------------------------+
void CheckRiskLimits()
{
   if(!isDailyLossLimitReached && dailyPL < 0)
   {
      double lossPercent = MathAbs(dailyPL) / dailyStartBalance * 100;
      if(lossPercent >= Max_Daily_Loss)
      {
         isDailyLossLimitReached = true;
         isTradingAllowed = false;
         string msg = StringFormat("VAIS: Daily loss limit %.2f%% - Trading stopped", lossPercent);
         Print(msg);
         if(Alert_On_Entry) Alert(msg);
         CloseAllPositions("Daily limit");
      }
   }
   
   if(!isWeeklyLossLimitReached && weeklyPL < 0)
   {
      double lossPercent = MathAbs(weeklyPL) / weeklyStartBalance * 100;
      if(lossPercent >= Max_Weekly_Loss)
      {
         isWeeklyLossLimitReached = true;
         isTradingAllowed = false;
         string msg = StringFormat("VAIS: Weekly loss limit %.2f%% - Trading stopped", lossPercent);
         Print(msg);
         if(Alert_On_Entry) Alert(msg);
         CloseAllPositions("Weekly limit");
      }
   }
   
   if(consecutiveLosses >= Max_Consecutive_Losses)
   {
      isTradingAllowed = false;
      string msg = StringFormat("VAIS: %d consecutive losses - Review required", consecutiveLosses);
      Print(msg);
      if(Alert_On_Entry) Alert(msg);
   }
}

//+------------------------------------------------------------------+
//| Check Trading Time                                               |
//+------------------------------------------------------------------+
bool IsTradingTime()
{
   MqlDateTime timeStruct;
   TimeToStruct(TimeCurrent(), timeStruct);
   
   bool isDayAllowed = false;
   switch(timeStruct.day_of_week)
   {
      case 1: isDayAllowed = Trade_Monday; break;
      case 2: isDayAllowed = Trade_Tuesday; break;
      case 3: isDayAllowed = Trade_Wednesday; break;
      case 4: isDayAllowed = Trade_Thursday; break;
      case 5: isDayAllowed = Trade_Friday; break;
      default: isDayAllowed = false;
   }
   
   if(!isDayAllowed) return false;
   if(timeStruct.hour < Trading_Start_Hour || timeStruct.hour >= Trading_End_Hour) return false;
   
   return true;
}

//+------------------------------------------------------------------+
//| Update Indicators                                                |
//+------------------------------------------------------------------+
bool UpdateIndicators()
{
   if(CopyBuffer(handle_H4_EMA_Fast, 0, 0, 3, h4_ema_fast) != 3) return false;
   if(CopyBuffer(handle_H4_EMA_Slow, 0, 0, 3, h4_ema_slow) != 3) return false;
   if(CopyBuffer(handle_H4_RSI, 0, 0, 3, h4_rsi) != 3) return false;
   if(CopyBuffer(handle_H4_ATR, 0, 0, 3, h4_atr) != 3) return false;
   if(CopyBuffer(handle_H4_BB, 0, 0, 3, h4_bb_upper) != 3) return false;
   if(CopyBuffer(handle_H4_BB, 1, 0, 3, h4_bb_middle) != 3) return false;
   if(CopyBuffer(handle_H4_BB, 2, 0, 3, h4_bb_lower) != 3) return false;
   if(CopyBuffer(handle_H4_MACD, 0, 0, 3, h4_macd_main) != 3) return false;
   if(CopyBuffer(handle_H4_MACD, 1, 0, 3, h4_macd_signal) != 3) return false;
   if(CopyBuffer(handle_H4_MACD, 2, 0, 3, h4_macd_histogram) != 3) return false;
   
   if(h4_atr[0] <= 0 || h4_atr[0] == EMPTY_VALUE) return false;
   
   return true;
}

//+------------------------------------------------------------------+
//| Check Market Conditions                                          |
//+------------------------------------------------------------------+
bool CheckMarketConditions()
{
   double spread = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID)) / _Point;
   if(spread > Max_Spread * 10)
   {
      if(Log_Analysis) Print("Spread too high: ", DoubleToString(spread/10, 1));
      return false;
   }
   
   if(h4_atr[1] < ATR_Min_H4)
   {
      if(Log_Analysis) Print("H4 ATR too low: ", DoubleToString(h4_atr[1], 2));
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Calculate Support/Resistance                                     |
//+------------------------------------------------------------------+
void CalculateSupportResistance()
{
   ArrayInitialize(supportLevels, 0);
   ArrayInitialize(resistanceLevels, 0);
   srCount = 0;
   
   double highs[], lows[];
   ArraySetAsSeries(highs, true);
   ArraySetAsSeries(lows, true);
   
   if(CopyHigh(_Symbol, PERIOD_H4, 0, SR_Lookback, highs) != SR_Lookback) return;
   if(CopyLow(_Symbol, PERIOD_H4, 0, SR_Lookback, lows) != SR_Lookback) return;
   
   for(int i = 3; i < SR_Lookback - 3; i++)
   {
      if(highs[i] > highs[i-1] && highs[i] > highs[i-2] && highs[i] > highs[i-3] &&
         highs[i] > highs[i+1] && highs[i] > highs[i+2] && highs[i] > highs[i+3])
      {
         bool isNew = true;
         for(int j = 0; j < srCount && j < 10; j++)
         {
            if(MathAbs(resistanceLevels[j] - highs[i]) < h4_atr[0] * 0.618)
            {
               isNew = false;
               break;
            }
         }
         if(isNew && srCount < 10)
         {
            resistanceLevels[srCount] = highs[i];
            srCount++;
         }
      }
      
      if(lows[i] < lows[i-1] && lows[i] < lows[i-2] && lows[i] < lows[i-3] &&
         lows[i] < lows[i+1] && lows[i] < lows[i+2] && lows[i] < lows[i+3])
      {
         bool isNew = true;
         for(int j = 0; j < srCount && j < 10; j++)
         {
            if(MathAbs(supportLevels[j] - lows[i]) < h4_atr[0] * 0.618)
            {
               isNew = false;
               break;
            }
         }
         if(isNew && srCount < 10)
         {
            supportLevels[srCount] = lows[i];
            srCount++;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check Entry Signals                                              |
//+------------------------------------------------------------------+
void CheckEntrySignals()
{
   double h4Close = iClose(_Symbol, PERIOD_H4, 1);
   double h4Open = iOpen(_Symbol, PERIOD_H4, 1);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   //--- Calculate volume spike
   long currentVol = iVolume(_Symbol, PERIOD_H4, 1);
   double avgVol = 0;
   for(int i = 2; i <= 21; i++) avgVol += (double)iVolume(_Symbol, PERIOD_H4, i);
   avgVol /= 20;
   bool volumeSpike = (currentVol > avgVol * Volume_Spike);
   
   //--- LONG SETUP
   int longConditions = 0;
   
   // 1. H4 EMA alignment (bullish trend)
   if(h4_ema_fast[1] > h4_ema_slow[1]) longConditions++;
   
   // 2. Price above both EMAs
   if(h4Close > h4_ema_fast[1] && h4Close > h4_ema_slow[1]) longConditions++;
   
   // 3. Pullback to EMA
   double emaDist = MathMin(MathAbs(h4Close - h4_ema_fast[1]), MathAbs(h4Close - h4_ema_slow[1]));
   if(emaDist <= h4_atr[1] * EMA_Pullback_ATR) longConditions++;
   
   // 4. RSI filter
   if(h4_rsi[1] >= H4_RSI_Long_Min && h4_rsi[1] <= H4_RSI_Long_Max) longConditions++;
   
   // 5. BB filter
   if(Use_BB_Filter && h4Close > h4_bb_middle[1]) longConditions++;
   
   // 6. MACD filter
   if(Use_MACD_Filter && h4_macd_histogram[1] > 0) longConditions++;
   
   // 7. Volume spike
   if(volumeSpike) longConditions++;
   
   // 8. Bullish candle
   if(h4Close > h4Open) longConditions++;
   
   if(longConditions >= Min_Conditions_Met)
   {
      double lotSize = CalculatePositionSize();
      double sl = CalculateStopLoss(ORDER_TYPE_BUY, ask);
      double tp = CalculateTakeProfit(ORDER_TYPE_BUY, ask);
      
      if(OpenPosition(ORDER_TYPE_BUY, lotSize, ask, sl, tp))
      {
         positionEntryPrice = ask;
         positionRisk = MathAbs(ask - sl);
         partialExitExecuted = false;
         
         if(Log_Analysis)
         {
            Print("=== LONG ENTRY (H4 Fibonacci) ===");
            Print("Conditions: ", longConditions, "/8 | RSI: ", h4_rsi[1]);
            Print("EMA8: ", h4_ema_fast[1], " | EMA21: ", h4_ema_slow[1]);
            Print("Entry: ", ask, " | SL: ", sl, " | TP: ", tp);
         }
      }
   }
   
   //--- SHORT SETUP
   int shortConditions = 0;
   
   // 1. H4 EMA alignment (bearish trend)
   if(h4_ema_fast[1] < h4_ema_slow[1]) shortConditions++;
   
   // 2. Price below both EMAs
   if(h4Close < h4_ema_fast[1] && h4Close < h4_ema_slow[1]) shortConditions++;
   
   // 3. Pullback to EMA
   emaDist = MathMin(MathAbs(h4Close - h4_ema_fast[1]), MathAbs(h4Close - h4_ema_slow[1]));
   if(emaDist <= h4_atr[1] * EMA_Pullback_ATR) shortConditions++;
   
   // 4. RSI filter
   if(h4_rsi[1] >= H4_RSI_Short_Min && h4_rsi[1] <= H4_RSI_Short_Max) shortConditions++;
   
   // 5. BB filter
   if(Use_BB_Filter && h4Close < h4_bb_middle[1]) shortConditions++;
   
   // 6. MACD filter
   if(Use_MACD_Filter && h4_macd_histogram[1] < 0) shortConditions++;
   
   // 7. Volume spike
   if(volumeSpike) shortConditions++;
   
   // 8. Bearish candle
   if(h4Close < h4Open) shortConditions++;
   
   if(shortConditions >= Min_Conditions_Met)
   {
      double lotSize = CalculatePositionSize();
      double sl = CalculateStopLoss(ORDER_TYPE_SELL, bid);
      double tp = CalculateTakeProfit(ORDER_TYPE_SELL, bid);
      
      if(OpenPosition(ORDER_TYPE_SELL, lotSize, bid, sl, tp))
      {
         positionEntryPrice = bid;
         positionRisk = MathAbs(bid - sl);
         partialExitExecuted = false;
         
         if(Log_Analysis)
         {
            Print("=== SHORT ENTRY (H4 Fibonacci) ===");
            Print("Conditions: ", shortConditions, "/8 | RSI: ", h4_rsi[1]);
            Print("EMA8: ", h4_ema_fast[1], " | EMA21: ", h4_ema_slow[1]);
            Print("Entry: ", bid, " | SL: ", sl, " | TP: ", tp);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Calculate Position Size                                          |
//+------------------------------------------------------------------+
double CalculatePositionSize()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = balance * (Risk_Per_Trade / 100.0);
   double sl_distance = h4_atr[0] * SL_ATR_Multiple;
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   
   double lotSize = riskAmount / (sl_distance / tickSize * tickValue);
   
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   lotSize = MathFloor(lotSize / lotStep) * lotStep;
   lotSize = MathMax(lotSize, minLot);
   lotSize = MathMin(lotSize, maxLot);
   lotSize = MathMin(lotSize, Max_Lot_Size);
   
   return lotSize;
}

//+------------------------------------------------------------------+
//| Calculate Stop Loss                                              |
//+------------------------------------------------------------------+
double CalculateStopLoss(ENUM_ORDER_TYPE orderType, double entryPrice)
{
   double sl_distance = h4_atr[0] * SL_ATR_Multiple;
   double sl = 0;
   
   if(orderType == ORDER_TYPE_BUY)
      sl = entryPrice - sl_distance;
   else
      sl = entryPrice + sl_distance;
   
   return NormalizeDouble(sl, _Digits);
}

//+------------------------------------------------------------------+
//| Calculate Take Profit                                            |
//+------------------------------------------------------------------+
double CalculateTakeProfit(ENUM_ORDER_TYPE orderType, double entryPrice)
{
   double tp_distance = h4_atr[0] * TP_ATR_Multiple;
   double tp = 0;
   
   if(orderType == ORDER_TYPE_BUY)
      tp = entryPrice + tp_distance;
   else
      tp = entryPrice - tp_distance;
   
   return NormalizeDouble(tp, _Digits);
}

//+------------------------------------------------------------------+
//| Open Position                                                     |
//+------------------------------------------------------------------+
bool OpenPosition(ENUM_ORDER_TYPE orderType, double lotSize, double price, double sl, double tp)
{
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = lotSize;
   request.type = orderType;
   request.price = price;
   request.sl = sl;
   request.tp = tp;
   request.deviation = 30;
   request.magic = MagicNumber;
   request.comment = EA_Name;
   request.type_filling = ORDER_FILLING_IOC;
   
   if(OrderSend(request, result) && result.retcode == TRADE_RETCODE_DONE)
   {
      lastTradeTime = TimeCurrent();
      totalTrades++;
      weeklyTradeCount++;
      
      if(Alert_On_Entry)
      {
         Alert("VAIS H4: ", orderType == ORDER_TYPE_BUY ? "LONG" : "SHORT", 
               " @ ", price, " | R:R 1:", DoubleToString(TP_ATR_Multiple/SL_ATR_Multiple, 2));
      }
      
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Manage Position                                                   |
//+------------------------------------------------------------------+
void ManagePosition()
{
   if(!PositionSelect(_Symbol)) return;
   
   long positionType = PositionGetInteger(POSITION_TYPE);
   double currentSL = PositionGetDouble(POSITION_SL);
   double currentTP = PositionGetDouble(POSITION_TP);
   double currentVolume = PositionGetDouble(POSITION_VOLUME);
   
   double currentPrice = (positionType == POSITION_TYPE_BUY) ? 
                         SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                         SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   double currentR = 0;
   if(positionRisk > 0)
   {
      if(positionType == POSITION_TYPE_BUY)
         currentR = (currentPrice - positionEntryPrice) / positionRisk;
      else
         currentR = (positionEntryPrice - currentPrice) / positionRisk;
   }
   
   //--- Partial exit at Fibonacci R
   if(Use_Partial_Exit && !partialExitExecuted && currentR >= Partial_Exit_R)
   {
      double partialVol = NormalizeDouble(currentVolume * (Partial_Exit_Percent / 100.0), 2);
      if(partialVol >= SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
      {
         if(ClosePartialPosition(partialVol, "Partial @ φR"))
         {
            partialExitExecuted = true;
            ModifyPosition(positionEntryPrice, currentTP);
            if(Log_Analysis)
               Print("Partial exit: ", Partial_Exit_Percent, "% @ ", Partial_Exit_R, "R");
         }
      }
   }
   
   //--- Trailing stop
   if(Use_Trailing_Stop && currentR >= Trail_Activation_R)
   {
      double newSL = 0;
      bool needsUpdate = false;
      double trailDist = h4_atr[0] * Trail_Distance_ATR;
      
      if(positionType == POSITION_TYPE_BUY)
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
         ModifyPosition(newSL, currentTP);
   }
}

//+------------------------------------------------------------------+
//| Modify Position                                                   |
//+------------------------------------------------------------------+
bool ModifyPosition(double sl, double tp)
{
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   request.action = TRADE_ACTION_SLTP;
   request.symbol = _Symbol;
   request.sl = NormalizeDouble(sl, _Digits);
   request.tp = NormalizeDouble(tp, _Digits);
   request.magic = MagicNumber;
   
   return OrderSend(request, result) && result.retcode == TRADE_RETCODE_DONE;
}

//+------------------------------------------------------------------+
//| Close Partial Position                                           |
//+------------------------------------------------------------------+
bool ClosePartialPosition(double volume, string reason)
{
   if(!PositionSelect(_Symbol)) return false;
   
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = volume;
   request.type = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
   request.price = (request.type == ORDER_TYPE_SELL) ? 
                   SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                   SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   request.deviation = 30;
   request.magic = MagicNumber;
   request.comment = reason;
   
   return OrderSend(request, result) && result.retcode == TRADE_RETCODE_DONE;
}

//+------------------------------------------------------------------+
//| Close Position                                                    |
//+------------------------------------------------------------------+
bool ClosePosition(string reason)
{
   if(!PositionSelect(_Symbol)) return false;
   
   double profit = PositionGetDouble(POSITION_PROFIT);
   
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = PositionGetDouble(POSITION_VOLUME);
   request.type = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
   request.price = (request.type == ORDER_TYPE_SELL) ? 
                   SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                   SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   request.deviation = 30;
   request.magic = MagicNumber;
   request.comment = reason;
   
   if(OrderSend(request, result) && result.retcode == TRADE_RETCODE_DONE)
   {
      if(profit > 0)
      {
         winningTrades++;
         consecutiveLosses = 0;
      }
      else
      {
         losingTrades++;
         consecutiveLosses++;
      }
      
      if(Alert_On_Exit)
         Alert("VAIS H4: CLOSED | P/L: $", DoubleToString(profit, 2), " | ", reason);
      
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Close All Positions                                              |
//+------------------------------------------------------------------+
void CloseAllPositions(string reason)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         ClosePosition(reason);
   }
}
//+------------------------------------------------------------------+