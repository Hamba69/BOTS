//+------------------------------------------------------------------+
//|                                                      VAIS_EA.mq5 |
//|                              VAIS Momentum Breakout Scalper Bot |
//|                                     High-Risk Gold Trading EA    |
//+------------------------------------------------------------------+
#property copyright "VAIS Trading System"
#property link      ""
#property version   "1.02"
#property description "Aggressive 5-min XAUUSD scalping strategy"
#property description "Combines breakout, momentum, EMA pullback, volatility expansion, and S/R sniper entries"


input group "=== INDICATOR SETTINGS ==="
input int EMA_Fast_Period = 8;
  // EMA Fast Period
input int EMA_Slow_Period = 21;
  // EMA Slow Period
input int RSI_Period = 13;
  // RSI Period
input int ATR_Period = 13;
  // ATR Period
input double ATR_Min_Value = 0.618;
  // Minimum ATR Value (Fibonacci ratio)
input int BB_Period = 21;
  // Bollinger Bands Period
input double BB_Deviation = 1.618;
  // BB Deviation (Golden Ratio)
input int MACD_Fast = 8;
  // MACD Fast EMA
input int MACD_Slow = 21;
  // MACD Slow EMA
input int MACD_Signal = 8;
  // MACD Signal SMA
input int Volume_Period = 21;
  // Volume Average Period
input double Volume_Spike = 1.618;
  // Volume Spike Multiplier (Golden Ratio)
input int SR_Lookback = 89;
  // Support/Resistance Lookback


input group "=== ENTRY SETTINGS ==="
input int Min_Conditions = 4;                      // Minimum Conditions Met (REDUCED from 5)
input bool Use_Pullback_Entry = true;              // Use Pullback Entry Logic
input bool Require_Breakout = false;               // Require Breakout/Breakdown (RELAXED)

input group "=== EXIT SETTINGS ==="
input double TP_ATR_Multiple = 2.5;                // Take Profit ATR Multiple
input double SL_ATR_Multiple = 1.0;                // Stop Loss ATR Multiple
input bool Use_Trailing_Stop = true;               // Use Trailing Stop
input double Trail_Activation_ATR = 1.5;           // Trail Activation (ATR Multiple)
input double Trail_Distance_ATR = 0.5;             // Trail Distance (ATR Multiple)
input int Max_Trade_Duration = 30;                 // Max Trade Duration (Minutes) - INCREASED from 10
input int Min_Trade_Duration = 10;                 // Min Trade Duration Before Time Exit
input bool Use_Indicator_Exits = true;             // Use Indicator-Based Exits
input bool Use_Dynamic_Exit = true;                // Use Dynamic Time Exit Based on Market

input group "=== RISK MANAGEMENT ==="
input double Risk_Per_Trade = 25.0;                // Risk Per Trade (%)
input double Max_Daily_Loss = 20.0;                // Max Daily Loss (%)
input double Max_Weekly_Loss = 50.0;               // Max Weekly Loss (%)
input double Max_Monthly_Loss = 50.0;              // Max Monthly Loss (%)
input double Max_Lot_Size = 1.0;                   // Maximum Lot Size
input int Max_Consecutive_Losses = 10;             // Max Consecutive Losses
input double Max_Drawdown = 50.0;                  // Max Drawdown (%)

input group "=== TRADING SCHEDULE ==="
input int Trading_Start_Hour = 3;                  // Trading Start Hour (UTC)
input int Trading_End_Hour = 2;                   // Trading End Hour (UTC)
input bool Trade_Monday = true;                    // Trade on Monday
input bool Trade_Tuesday = true;                   // Trade on Tuesday
input bool Trade_Wednesday = true;                 // Trade on Wednesday
input bool Trade_Thursday = true;                  // Trade on Thursday
input bool Trade_Friday = true;                    // Trade on Friday
input bool Avoid_News = true;                      // Avoid Major News Events
input int News_Buffer_Minutes = 30;                // News Avoidance Buffer (Minutes)

input group "=== MARKET CONDITIONS ==="
input double Max_Spread = 3.0;                     // Maximum Spread (Pips)
input double Min_Volume_Percent = 70.0;            // Minimum Volume (% of Average)

input group "=== ORDER EXECUTION ==="
input int Order_Expiration = 10;                   // Order Expiration (Minutes)
input double Max_Slippage = 2.0;                   // Maximum Slippage (Pips)
input int Order_Retries = 3;                       // Order Retry Attempts

input group "=== NOTIFICATIONS ==="
input bool Alert_On_Entry = true;                  // Alert on Trade Entry
input bool Alert_On_Exit = true;                   // Alert on Trade Exit
input bool Alert_On_Error = true;                  // Alert on Error
input bool Send_Daily_Summary = true;              // Send Daily Summary

//--- Global Variables
int handleEMAFast, handleEMASlow, handleRSI, handleATR, handleBB, handleMACD;
double emaFast[], emaSlow[], rsi[], atr[], bbUpper[], bbMiddle[], bbLower[];
double macdMain[], macdSignal[], macdHistogram[];
double volume[], volumeMA[];

double accountBalance, accountEquity, startingBalance;
double dailyStartBalance, weeklyStartBalance, monthlyStartBalance;
double dailyPL = 0, weeklyPL = 0, monthlyPL = 0;
int consecutiveLosses = 0;
int totalTrades = 0, winningTrades = 0, losingTrades = 0;

datetime lastTradeTime = 0;
datetime trailActivationTime = 0;
datetime dailyResetTime = 0;
datetime weeklyResetTime = 0;
datetime monthlyResetTime = 0;

bool isTradingAllowed = true;
bool isDailyLossLimitReached = false;
bool isWeeklyLossLimitReached = false;
bool isMonthlyLossLimitReached = false;

double supportLevels[10];
double resistanceLevels[10];
int srCount = 0;

string EA_Name = "VAIS_EA";
int MagicNumber = 123456;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("=== VAIS EA Initialization ===");
   Print("Bot Name: ", EA_Name);
   Print("Symbol: ", _Symbol);
   Print("Timeframe: ", EnumToString(_Period));
   Print("Version: 1.02 - Adjusted Parameters");
   
   //--- Check if symbol is XAUUSD
   if(_Symbol != "XAUUSD")
   {
      Alert("WARNING: This EA is designed specifically for XAUUSD!");
      Print("Current symbol: ", _Symbol, " - Recommended: XAUUSD");
   }
   
   //--- Check if timeframe is M5
   if(_Period != PERIOD_M5)
   {
      Alert("WARNING: This EA is designed for 5-minute (M5) timeframe!");
      Print("Current timeframe: ", EnumToString(_Period), " - Recommended: M5");
   }
   
   //--- Initialize indicators
   handleEMAFast = iMA(_Symbol, _Period, EMA_Fast_Period, 0, MODE_EMA, PRICE_CLOSE);
   handleEMASlow = iMA(_Symbol, _Period, EMA_Slow_Period, 0, MODE_EMA, PRICE_CLOSE);
   handleRSI = iRSI(_Symbol, _Period, RSI_Period, PRICE_CLOSE);
   handleATR = iATR(_Symbol, _Period, ATR_Period);
   handleBB = iBands(_Symbol, _Period, BB_Period, 0, BB_Deviation, PRICE_CLOSE);
   handleMACD = iMACD(_Symbol, _Period, MACD_Fast, MACD_Slow, MACD_Signal, PRICE_CLOSE);
   
   if(handleEMAFast == INVALID_HANDLE || handleEMASlow == INVALID_HANDLE || 
      handleRSI == INVALID_HANDLE || handleATR == INVALID_HANDLE ||
      handleBB == INVALID_HANDLE || handleMACD == INVALID_HANDLE)
   {
      Print("ERROR: Failed to create indicator handles!");
      return(INIT_FAILED);
   }
   
   //--- Initialize arrays
   ArraySetAsSeries(emaFast, true);
   ArraySetAsSeries(emaSlow, true);
   ArraySetAsSeries(rsi, true);
   ArraySetAsSeries(atr, true);
   ArraySetAsSeries(bbUpper, true);
   ArraySetAsSeries(bbMiddle, true);
   ArraySetAsSeries(bbLower, true);
   ArraySetAsSeries(macdMain, true);
   ArraySetAsSeries(macdSignal, true);
   ArraySetAsSeries(macdHistogram, true);
   
   //--- Initialize account variables
   accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   startingBalance = accountBalance;
   dailyStartBalance = accountBalance;
   weeklyStartBalance = accountBalance;
   monthlyStartBalance = accountBalance;
   
   //--- Set reset times
   dailyResetTime = TimeCurrent();
   weeklyResetTime = TimeCurrent();
   monthlyResetTime = TimeCurrent();
   
   Print("Starting Balance: ", accountBalance);
   Print("Risk Per Trade: ", Risk_Per_Trade, "%");
   Print("Min Conditions Required: ", Min_Conditions, " (reduced from 5)");
   Print("ATR Min Value: ", ATR_Min_Value, " (reduced from 0.8)");
   Print("Volume Spike: ", Volume_Spike, "x (reduced from 1.3x)");
   Print("Max Trade Duration: ", Max_Trade_Duration, " min (increased from 10)");
   Print("Breakout Required: ", Require_Breakout ? "Yes" : "No (relaxed)");
   Print("=== Initialization Complete ===");
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //--- Release indicator handles
   if(handleEMAFast != INVALID_HANDLE) IndicatorRelease(handleEMAFast);
   if(handleEMASlow != INVALID_HANDLE) IndicatorRelease(handleEMASlow);
   if(handleRSI != INVALID_HANDLE) IndicatorRelease(handleRSI);
   if(handleATR != INVALID_HANDLE) IndicatorRelease(handleATR);
   if(handleBB != INVALID_HANDLE) IndicatorRelease(handleBB);
   if(handleMACD != INVALID_HANDLE) IndicatorRelease(handleMACD);
   
   Print("=== VAIS EA Stopped ===");
   Print("Total Trades: ", totalTrades);
   Print("Winning Trades: ", winningTrades);
   Print("Losing Trades: ", losingTrades);
   if(totalTrades > 0)
      Print("Win Rate: ", DoubleToString((double)winningTrades/totalTrades*100, 2), "%");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- Update account info
   UpdateAccountInfo();
   
   //--- Check risk management limits
   CheckRiskLimits();
   
   //--- Check if trading is allowed
   if(!isTradingAllowed)
      return;
   
   //--- Check trading schedule
   if(!IsTradingTime())
      return;
   
   //--- Check market conditions
   if(!CheckMarketConditions())
      return;
   
   //--- Update indicator values
   if(!UpdateIndicators())
      return;
   
   //--- Calculate support/resistance levels
   CalculateSupportResistance();
   
   //--- Check for open positions
   if(PositionSelect(_Symbol))
   {
      //--- Manage open position
      ManagePosition();
   }
   else
   {
      //--- Look for entry signals
      CheckEntrySignals();
   }
   
   //--- Send daily summary if enabled
   if(Send_Daily_Summary)
      SendDailySummary();
}

//+------------------------------------------------------------------+
//| Update Account Information                                        |
//+------------------------------------------------------------------+
void UpdateAccountInfo()
{
   accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   accountEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   
   //--- Check for daily reset
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
   
   //--- Check for weekly reset (Monday)
   if(currentTime.day_of_week == 1 && resetTime.day_of_week != 1)
   {
      weeklyPL = 0;
      weeklyStartBalance = accountBalance;
      weeklyResetTime = TimeCurrent();
      isWeeklyLossLimitReached = false;
   }
   
   //--- Check for monthly reset
   if(currentTime.mon != resetTime.mon)
   {
      monthlyPL = 0;
      monthlyStartBalance = accountBalance;
      monthlyResetTime = TimeCurrent();
      isMonthlyLossLimitReached = false;
   }
   
   //--- Calculate P&L
   dailyPL = accountBalance - dailyStartBalance;
   weeklyPL = accountBalance - weeklyStartBalance;
   monthlyPL = accountBalance - monthlyStartBalance;
}

//+------------------------------------------------------------------+
//| Check Risk Management Limits                                     |
//+------------------------------------------------------------------+
void CheckRiskLimits()
{
   //--- Check daily loss limit
   if(!isDailyLossLimitReached && dailyPL < 0)
   {
      double dailyLossPercent = MathAbs(dailyPL) / dailyStartBalance * 100;
      if(dailyLossPercent >= Max_Daily_Loss)
      {
         isDailyLossLimitReached = true;
         isTradingAllowed = false;
         string msg = "VAIS: Daily loss limit reached (" + DoubleToString(dailyLossPercent, 2) + "%) - Trading stopped";
         Print(msg);
         if(Alert_On_Error) Alert(msg);
         CloseAllPositions();
      }
   }
   
   //--- Check weekly loss limit
   if(!isWeeklyLossLimitReached && weeklyPL < 0)
   {
      double weeklyLossPercent = MathAbs(weeklyPL) / weeklyStartBalance * 100;
      if(weeklyLossPercent >= Max_Weekly_Loss)
      {
         isWeeklyLossLimitReached = true;
         isTradingAllowed = false;
         string msg = "VAIS: Weekly loss limit reached (" + DoubleToString(weeklyLossPercent, 2) + "%) - Trading stopped";
         Print(msg);
         if(Alert_On_Error) Alert(msg);
         CloseAllPositions();
      }
   }
   
   //--- Check monthly loss limit
   if(!isMonthlyLossLimitReached && monthlyPL < 0)
   {
      double monthlyLossPercent = MathAbs(monthlyPL) / monthlyStartBalance * 100;
      if(monthlyLossPercent >= Max_Monthly_Loss)
      {
         isMonthlyLossLimitReached = true;
         isTradingAllowed = false;
         string msg = "VAIS: Monthly loss limit reached (" + DoubleToString(monthlyLossPercent, 2) + "%) - Trading stopped";
         Print(msg);
         if(Alert_On_Error) Alert(msg);
         CloseAllPositions();
      }
   }
   
   //--- Check consecutive losses
   if(consecutiveLosses >= Max_Consecutive_Losses)
   {
      isTradingAllowed = false;
      string msg = "VAIS: " + IntegerToString(consecutiveLosses) + " consecutive losses - Trading stopped for 24 hours";
      Print(msg);
      if(Alert_On_Error) Alert(msg);
      CloseAllPositions();
   }
   
   //--- Check maximum drawdown
   double drawdown = (startingBalance - accountEquity) / startingBalance * 100;
   if(drawdown >= Max_Drawdown)
   {
      isTradingAllowed = false;
      string msg = "VAIS: Maximum drawdown reached (" + DoubleToString(drawdown, 2) + "%) - Trading stopped";
      Print(msg);
      if(Alert_On_Error) Alert(msg);
      CloseAllPositions();
   }
}

//+------------------------------------------------------------------+
//| Check Trading Schedule                                           |
//+------------------------------------------------------------------+
bool IsTradingTime()
{
   MqlDateTime timeStruct;
   TimeToStruct(TimeCurrent(), timeStruct);
   
   //--- Check day of week
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
   
   if(!isDayAllowed)
      return false;
   
   //--- Check trading hours
   if(timeStruct.hour < Trading_Start_Hour || timeStruct.hour >= Trading_End_Hour)
      return false;
   
   //--- Avoid news events (simplified - in production, integrate with news calendar)
   if(Avoid_News)
   {
      // This is a placeholder - implement actual news calendar integration
      // For now, we'll avoid first 15 min of major sessions
      if((timeStruct.hour == 8 || timeStruct.hour == 13 || timeStruct.hour == 14) && timeStruct.min < 15)
         return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Check Market Conditions                                          |
//+------------------------------------------------------------------+
bool CheckMarketConditions()
{
   //--- Check spread
   double spread = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID)) / _Point;
   if(spread > Max_Spread * 10) // Convert pips to points
   {
      Print("Spread too high: ", DoubleToString(spread/10, 1), " pips");
      return false;
   }
   
   //--- Check ATR (volatility filter) - REDUCED threshold
   if(atr[0] < ATR_Min_Value)
   {
      Print("ATR too low: ", DoubleToString(atr[0], 2), " (min: ", ATR_Min_Value, ")");
      return false;
   }
   
   //--- Check volume (simplified - use tick volume)
   long tickVol = iVolume(_Symbol, _Period, 0);
   double avgVol = 0;
   for(int i = 1; i <= Volume_Period; i++)
      avgVol += (double)iVolume(_Symbol, _Period, i);
   avgVol /= Volume_Period;
   
   if(tickVol < avgVol * (Min_Volume_Percent / 100.0))
   {
      Print("Volume too low: ", tickVol, " (avg: ", DoubleToString(avgVol, 0), ")");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Update Indicator Values                                          |
//+------------------------------------------------------------------+
bool UpdateIndicators()
{
   //--- Copy indicator buffers
   if(CopyBuffer(handleEMAFast, 0, 0, 3, emaFast) <= 0) return false;
   if(CopyBuffer(handleEMASlow, 0, 0, 3, emaSlow) <= 0) return false;
   if(CopyBuffer(handleRSI, 0, 0, 3, rsi) <= 0) return false;
   if(CopyBuffer(handleATR, 0, 0, 3, atr) <= 0) return false;
   
   //--- SAFETY CHECK: Ensure ATR has valid data before proceeding
   if(ArraySize(atr) < 1 || atr[0] <= 0 || atr[0] == EMPTY_VALUE)
   {
      Print("Waiting for valid ATR values...");
      return false;
   }
   
   if(CopyBuffer(handleBB, 0, 0, 3, bbUpper) <= 0) return false;
   if(CopyBuffer(handleBB, 1, 0, 3, bbMiddle) <= 0) return false;
   if(CopyBuffer(handleBB, 2, 0, 3, bbLower) <= 0) return false;
   if(CopyBuffer(handleMACD, 0, 0, 3, macdMain) <= 0) return false;
   if(CopyBuffer(handleMACD, 1, 0, 3, macdSignal) <= 0) return false;
   if(CopyBuffer(handleMACD, 2, 0, 3, macdHistogram) <= 0) return false;
   
   return true;
}

//+------------------------------------------------------------------+
//| Calculate Support and Resistance Levels                          |
//+------------------------------------------------------------------+
void CalculateSupportResistance()
{
   ArrayInitialize(supportLevels, 0);
   ArrayInitialize(resistanceLevels, 0);
   srCount = 0;
   
   //--- Get high/low values for lookback period
   double highs[], lows[];
   ArraySetAsSeries(highs, true);
   ArraySetAsSeries(lows, true);
   
   CopyHigh(_Symbol, _Period, 0, SR_Lookback, highs);
   CopyLow(_Symbol, _Period, 0, SR_Lookback, lows);
   
   //--- Find swing highs and lows (simplified method)
   for(int i = 2; i < SR_Lookback - 2; i++)
   {
      //--- Check for swing high (resistance)
      if(highs[i] > highs[i-1] && highs[i] > highs[i-2] && 
         highs[i] > highs[i+1] && highs[i] > highs[i+2])
      {
         bool isNew = true;
         for(int j = 0; j < srCount && j < 10; j++)
         {
            if(MathAbs(resistanceLevels[j] - highs[i]) < atr[0] * 0.5)
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
      
      //--- Check for swing low (support)
      if(lows[i] < lows[i-1] && lows[i] < lows[i-2] && 
         lows[i] < lows[i+1] && lows[i] < lows[i+2])
      {
         bool isNew = true;
         for(int j = 0; j < srCount && j < 10; j++)
         {
            if(MathAbs(supportLevels[j] - lows[i]) < atr[0] * 0.5)
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
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   //--- Check for LONG signal
   int longConditions = 0;
   
   // 1. Trend alignment
   if(emaFast[0] > emaSlow[0])
      longConditions++;
   
   // 2. Breakout confirmation (OPTIONAL now)
   bool breakoutUp = false;
   for(int i = 0; i < srCount && i < 10; i++)
   {
      if(resistanceLevels[i] > 0 && ask > resistanceLevels[i] && bid > resistanceLevels[i] - atr[0] * 0.2)
      {
         breakoutUp = true;
         break;
      }
   }
   if(breakoutUp || ask > bbUpper[0])
   {
      longConditions++;
   }
   else if(!Require_Breakout)
   {
      // If breakout not required, still give a condition if price is in upper half
      if(ask > bbMiddle[0])
         longConditions++;
   }
   
   // 3. Momentum check
   if(rsi[0] > 40 && rsi[0] < 70)
      longConditions++;
   
   // 4. MACD bullish
   if(macdHistogram[0] > 0 && macdHistogram[0] > macdHistogram[1])
      longConditions++;
   
   // 5. Volatility filter
   if(atr[0] > ATR_Min_Value)
      longConditions++;
   
   // 6. Volume confirmation (REDUCED threshold)
   long currentVol = iVolume(_Symbol, _Period, 0);
   double avgVol = 0;
   for(int i = 1; i <= Volume_Period; i++)
      avgVol += (double)iVolume(_Symbol, _Period, i);
   avgVol /= Volume_Period;
   if(currentVol > avgVol * Volume_Spike)
      longConditions++;
   
   // 7. Pullback entry (optional)
   if(Use_Pullback_Entry)
   {
      if(MathAbs(ask - emaFast[0]) < atr[0] * 0.3 || MathAbs(ask - emaSlow[0]) < atr[0] * 0.3)
         longConditions++;
   }
   
   //--- Execute LONG trade if conditions met
   if(longConditions >= Min_Conditions)
   {
      double lotSize = CalculatePositionSize();
      double sl = CalculateStopLoss(ORDER_TYPE_BUY, ask);
      double tp = CalculateTakeProfit(ORDER_TYPE_BUY, ask);
      
      if(OpenPosition(ORDER_TYPE_BUY, lotSize, ask, sl, tp))
      {
         Print("LONG Entry - Conditions met: ", longConditions, "/7 (min required: ", Min_Conditions, ")");
      }
   }
   
   //--- Check for SHORT signal
   int shortConditions = 0;
   
   // 1. Trend alignment
   if(emaFast[0] < emaSlow[0])
      shortConditions++;
   
   // 2. Breakdown confirmation (OPTIONAL now)
   bool breakdownDown = false;
   for(int i = 0; i < srCount && i < 10; i++)
   {
      if(supportLevels[i] > 0 && bid < supportLevels[i] && ask < supportLevels[i] + atr[0] * 0.2)
      {
         breakdownDown = true;
         break;
      }
   }
   if(breakdownDown || bid < bbLower[0])
   {
      shortConditions++;
   }
   else if(!Require_Breakout)
   {
      // If breakout not required, still give a condition if price is in lower half
      if(bid < bbMiddle[0])
         shortConditions++;
   }
   
   // 3. Momentum check
   if(rsi[0] < 60 && rsi[0] > 30)
      shortConditions++;
   
   // 4. MACD bearish
   if(macdHistogram[0] < 0 && macdHistogram[0] < macdHistogram[1])
      shortConditions++;
   
   // 5. Volatility filter
   if(atr[0] > ATR_Min_Value)
      shortConditions++;
   
   // 6. Volume confirmation (REDUCED threshold)
   if(currentVol > avgVol * Volume_Spike)
      shortConditions++;
   
   // 7. Pullback entry (optional)
   if(Use_Pullback_Entry)
   {
      if(MathAbs(bid - emaFast[0]) < atr[0] * 0.3 || MathAbs(bid - emaSlow[0]) < atr[0] * 0.3)
         shortConditions++;
   }
   
   //--- Execute SHORT trade if conditions met
   if(shortConditions >= Min_Conditions)
   {
      double lotSize = CalculatePositionSize();
      double sl = CalculateStopLoss(ORDER_TYPE_SELL, bid);
      double tp = CalculateTakeProfit(ORDER_TYPE_SELL, bid);
      
      if(OpenPosition(ORDER_TYPE_SELL, lotSize, bid, sl, tp))
      {
         Print("SHORT Entry - Conditions met: ", shortConditions, "/7 (min required: ", Min_Conditions, ")");
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
   
   double sl_distance = atr[0] * SL_ATR_Multiple;
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   
   double lotSize = riskAmount / (sl_distance / tickSize * tickValue);
   
   //--- Normalize lot size
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
   double sl_distance = atr[0] * SL_ATR_Multiple;
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
   double tp_distance = atr[0] * TP_ATR_Multiple;
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
   request.deviation = (ulong)(Max_Slippage * 10);
   request.magic = MagicNumber;
   request.comment = EA_Name + " v1.02";
   request.type_filling = ORDER_FILLING_IOC;
   
   //--- Send order
   for(int attempt = 0; attempt < Order_Retries; attempt++)
   {
      if(OrderSend(request, result))
      {
         if(result.retcode == TRADE_RETCODE_DONE)
         {
            Print("Position opened successfully: ", orderType == ORDER_TYPE_BUY ? "BUY" : "SELL", 
                  " | Lots: ", lotSize, " | Price: ", price, " | SL: ", sl, " | TP: ", tp);
            
            if(Alert_On_Entry)
               Alert("VAIS: ", orderType == ORDER_TYPE_BUY ? "LONG" : "SHORT", " position opened on XAUUSD at ", price);
            
            lastTradeTime = TimeCurrent();
            totalTrades++;
            return true;
         }
         else
         {
            Print("Order failed with retcode: ", result.retcode, " - ", GetTradeRetcodeDescription(result.retcode));
         }
      }
      else
      {
         Print("OrderSend error: ", GetLastError());
      }
      
      if(attempt < Order_Retries - 1)
         Sleep(1000); // Wait 1 second before retry
   }
   
   if(Alert_On_Error)
      Alert("VAIS ERROR: Failed to open position after ", Order_Retries, " attempts");
   
   return false;
}

//+------------------------------------------------------------------+
//| Manage Open Position                                             |
//+------------------------------------------------------------------+
void ManagePosition()
{
   if(!PositionSelect(_Symbol))
      return;
   
   double positionProfit = PositionGetDouble(POSITION_PROFIT);
   double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double currentSL = PositionGetDouble(POSITION_SL);
   double currentTP = PositionGetDouble(POSITION_TP);
   long positionType = PositionGetInteger(POSITION_TYPE);
   datetime positionTime = (datetime)PositionGetInteger(POSITION_TIME);
   
   double currentPrice = (positionType == POSITION_TYPE_BUY) ? 
                         SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                         SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   //--- Calculate time in trade
   int minutesInTrade = (int)((TimeCurrent() - positionTime) / 60);
   
   //--- DYNAMIC TIME-BASED EXIT with market analysis
   if(Use_Dynamic_Exit)
   {
      // Only consider time exit after minimum duration
      if(minutesInTrade >= Min_Trade_Duration)
      {
         // Check if market conditions still favor the position
         bool marketStillFavorable = false;
         
         if(positionType == POSITION_TYPE_BUY)
         {
            // For longs: check if trend still bullish and momentum strong
            if(emaFast[0] > emaSlow[0] && rsi[0] > 45 && macdHistogram[0] > 0)
               marketStillFavorable = true;
         }
         else // SELL
         {
            // For shorts: check if trend still bearish and momentum strong
            if(emaFast[0] < emaSlow[0] && rsi[0] < 55 && macdHistogram[0] < 0)
               marketStillFavorable = true;
         }
         
         // If market still favorable, allow trade to run to max duration
         // If not favorable, exit at min duration
         if(!marketStillFavorable)
         {
            Print("Dynamic exit: Market conditions no longer favorable after ", minutesInTrade, " minutes");
            ClosePosition("Market conditions changed");
            return;
         }
         else if(minutesInTrade >= Max_Trade_Duration)
         {
            Print("Dynamic exit: Max duration reached with favorable conditions at ", minutesInTrade, " minutes");
            ClosePosition("Max time limit reached");
            return;
         }
      }
   }
   else
   {
      // Standard time-based exit without market analysis
      if(minutesInTrade >= Max_Trade_Duration)
      {
         Print("Time-based exit: ", minutesInTrade, " minutes in trade");
         ClosePosition("Time limit reached");
         return;
      }
   }
   
   //--- Check indicator-based exits
   if(Use_Indicator_Exits)
   {
      //--- EMA cross against position
      if(positionType == POSITION_TYPE_BUY && emaFast[0] < emaSlow[0])
      {
         Print("Indicator exit: EMA bearish cross on LONG position");
         ClosePosition("EMA cross signal");
         return;
      }
      else if(positionType == POSITION_TYPE_SELL && emaFast[0] > emaSlow[0])
      {
         Print("Indicator exit: EMA bullish cross on SHORT position");
         ClosePosition("EMA cross signal");
         return;
      }
      
      //--- RSI extreme levels
      if(positionType == POSITION_TYPE_BUY && rsi[0] > 85)
      {
         Print("Indicator exit: RSI overbought on LONG position");
         ClosePosition("RSI extreme");
         return;
      }
      else if(positionType == POSITION_TYPE_SELL && rsi[0] < 15)
      {
         Print("Indicator exit: RSI oversold on SHORT position");
         ClosePosition("RSI extreme");
         return;
      }
   }
   
   //--- Trailing stop logic
   if(Use_Trailing_Stop)
   {
      double profitInATR = MathAbs(currentPrice - entryPrice) / atr[0];
      
      if(profitInATR >= Trail_Activation_ATR)
      {
         double newSL = 0;
         double trailDistance = atr[0] * Trail_Distance_ATR;
         
         if(positionType == POSITION_TYPE_BUY)
         {
            newSL = currentPrice - trailDistance;
            if(newSL > currentSL)
            {
               ModifyPosition(newSL, currentTP);
               Print("Trailing stop updated: ", newSL);
            }
         }
         else // SELL
         {
            newSL = currentPrice + trailDistance;
            if(newSL < currentSL || currentSL == 0)
            {
               ModifyPosition(newSL, currentTP);
               Print("Trailing stop updated: ", newSL);
            }
         }
      }
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
   
   if(OrderSend(request, result))
   {
      if(result.retcode == TRADE_RETCODE_DONE)
         return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Close Position                                                    |
//+------------------------------------------------------------------+
bool ClosePosition(string reason)
{
   if(!PositionSelect(_Symbol))
      return false;
   
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = PositionGetDouble(POSITION_VOLUME);
   request.type = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
   request.price = (request.type == ORDER_TYPE_SELL) ? 
                   SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                   SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   request.deviation = (ulong)(Max_Slippage * 10);
   request.magic = MagicNumber;
   request.comment = reason;
   
   if(OrderSend(request, result))
   {
      if(result.retcode == TRADE_RETCODE_DONE)
      {
         double profit = PositionGetDouble(POSITION_PROFIT);
         Print("Position closed: ", reason, " | P/L: ", profit);
         
         //--- Update statistics
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
            Alert("VAIS: Position closed at ", request.price, " | P/L: ", DoubleToString(profit, 2), " | Reason: ", reason);
         
         return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Close All Positions                                              |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0)
      {
         if(PositionSelectByTicket(ticket))
         {
            if(PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
            {
               ClosePosition("Emergency close");
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Send Daily Summary                                               |
//+------------------------------------------------------------------+
void SendDailySummary()
{
   MqlDateTime timeStruct;
   TimeToStruct(TimeCurrent(), timeStruct);
   
   static int lastSummaryDay = -1;
   
   if(timeStruct.hour == 23 && timeStruct.min >= 50 && timeStruct.day != lastSummaryDay)
   {
      string summary = "VAIS Daily Summary:\n";
      summary += "Trades: " + IntegerToString(totalTrades) + "\n";
      summary += "Wins: " + IntegerToString(winningTrades) + "\n";
      summary += "Losses: " + IntegerToString(losingTrades) + "\n";
      if(totalTrades > 0)
         summary += "Win Rate: " + DoubleToString((double)winningTrades/totalTrades*100, 2) + "%\n";
      summary += "Daily P/L: " + DoubleToString(dailyPL, 2) + "\n";
      summary += "Balance: " + DoubleToString(accountBalance, 2);
      
      Print(summary);
      Alert(summary);
      
      lastSummaryDay = timeStruct.day;
   }
}

//+------------------------------------------------------------------+
//| Get Trade Retcode Description                                    |
//+------------------------------------------------------------------+
string GetTradeRetcodeDescription(uint retcode)
{
   switch(retcode)
   {
      case TRADE_RETCODE_DONE: return "Request completed";
      case TRADE_RETCODE_REJECT: return "Request rejected";
      case TRADE_RETCODE_CANCEL: return "Request cancelled";
      case TRADE_RETCODE_PLACED: return "Order placed";
      case TRADE_RETCODE_INVALID: return "Invalid request";
      case TRADE_RETCODE_TIMEOUT: return "Request timeout";
      case TRADE_RETCODE_INVALID_PRICE: return "Invalid price";
      case TRADE_RETCODE_INVALID_STOPS: return "Invalid stops";
      case TRADE_RETCODE_INVALID_VOLUME: return "Invalid volume";
      case TRADE_RETCODE_MARKET_CLOSED: return "Market closed";
      case TRADE_RETCODE_NO_MONEY: return "Insufficient funds";
      default: return "Unknown retcode: " + IntegerToString(retcode);
   }
}
//+------------------------------------------------------------------+