# 🤖 MQL5 Trading Bot Collection

[![MQL5](https://img.shields.io/badge/MQL5-Expert%20Advisors-blue)](https://www.mql5.com/)
[![Trading](https://img.shields.io/badge/Trading-Forex%20%7C%20Gold-gold)](https://github.com)
[![License](https://img.shields.io/badge/License-Educational-green)](LICENSE)

> A curated collection of automated trading Expert Advisors (EAs) for MetaTrader 5, ranging from conservative Fibonacci-based strategies to ultra-aggressive scalping systems.

---

## 📊 Repository Overview

This repository contains **8 distinct trading bots**, each designed with unique strategies, risk profiles, and market approaches. From micro-account doublers to professional-grade Fibonacci systems, this collection covers the full spectrum of algorithmic trading.

**⚠️ Risk Warning**: These bots range from moderate to extremely high risk. Always backtest thoroughly and never risk more than you can afford to lose.

---

## 🎯 Bot Rankings & Analysis

### **Tier 1: Professional Grade** ⭐⭐⭐⭐⭐

#### **#1 - VAIS_EA (VAIS Fibonacci H4 System v5.1)**
**Best Overall | Recommended**

The crown jewel of this collection. A mathematically sophisticated system built entirely on Fibonacci principles with professional-grade risk management.

**Uniqueness:**
- **Pure Fibonacci Architecture**: Every parameter uses Fibonacci numbers (8, 13, 21, 89) or golden ratios (0.618, 1.618, 2.618)
- **H4 Timeframe Focus**: Designed for the 4-hour chart, reducing noise and improving win quality
- **Golden Ratio Risk/Reward**: TP at 2.618 ATR (φ²), partial exit at 1.618R (φ), trail at 0.618 ATR (φ⁻¹)
- **Multi-Layer Filters**: Requires 4+ conditions from EMA, RSI, MACD, BB, and volume analysis
- **Comprehensive Protection**: Daily/weekly loss limits, consecutive loss tracking, position sizing limits
- **Support/Resistance Integration**: 89-bar lookback for key levels

**Strategy**: Waits for high-probability H4 setups where price pulls back to EMAs within golden ratio zones, then enters on breakouts with strict Fibonacci-based filters.

**Target Performance**: 55-60% win rate | R:R 1:2.5+

**Risk Level**: ⭐⭐ Moderate (1% per trade)

**Ideal For**: Swing traders, patient investors, those seeking mathematical elegance

---

### **Tier 2: Enhanced Scalpers** ⭐⭐⭐⭐

#### **#2 - please.mq5 (KITES Optimized Fibonacci Scalper v4.0)**

The "goldilocks" of scalpers - aggressive enough to capitalize on opportunities, conservative enough to survive.

**Uniqueness:**
- **Dynamic ATR-Based SL/TP**: Adapts to market volatility instead of fixed pips
- **H1 Trend Confirmation**: Won't trade against the bigger picture
- **Tightened Fibonacci Filters**: 3 of 5 conditions required (RSI 45-75 bull, 25-55 bear)
- **Dual Entry System**: Both breakout (Buy/Sell Stop) and pullback (Buy/Sell Limit) orders
- **Standard Indicators**: Uses industry-standard MACD (12/26/9) and RSI (14) for reliability

**Strategy**: M5 scalping with H1 trend filter and M15 directional bias. Only trades when multiple Fibonacci conditions align.

**Risk Level**: ⭐⭐ Moderate (1% per trade, 50 max exposure)

**Ideal For**: Active traders who want scalping with safety rails

---

#### **#3 - HYBrid.mq5 (Optimized Fibonacci Scalper v3.0)**

The bridge between aggressive scalping and intelligent filtering.

**Uniqueness:**
- **Toggle-able Fibonacci Filters**: Can switch between pure scalping and filtered mode
- **Efficient Architecture**: Streamlined codebase for faster execution
- **M5 Fibonacci Indicators**: Full suite (EMA 8/21, RSI 13, ATR 13, MACD 8/21/8)
- **Breakout Focus**: M15 directional bias + M5 previous bar breakouts
- **Fixed 10-Pip SL/TP**: Simple risk/reward for tight scalping

**Strategy**: Detects M15 bullish/bearish candles, waits for M5 bar completion, then places breakout orders with optional Fibonacci quality filters.

**Risk Level**: ⭐⭐⭐ Moderate-High (1% risk, 5 trades per signal = effective 5x leverage)

**Ideal For**: Traders who want scalping flexibility with filter options

---

### **Tier 3: Aggressive Scalpers** ⭐⭐⭐

#### **#4 - Ultimate_Sniper_EA__2_.mq5 (Elite Hybrid Scalper v6.1)**

Multi-timeframe aggressive scalper with instant profit-taking features.

**Uniqueness:**
- **3-Pip Instant Profit**: Closes 50% of position at micro-movements
- **Multi-Timeframe Analysis**: H1 trend + M15 bias + M5 execution + optional M1 micro-signals
- **Account Size Adaptation**: Auto-detects micro ($5-99), mini ($100-999), or standard ($1000+) accounts
- **Trailing Stop System**: Activates at 0.8R with 0.3 ATR trailing distance
- **Position Tracking Array**: Sophisticated management of partial closes and trailing

**Strategy**: Combines big-picture trend (H1), medium bias (M15), and fast execution (M5/M1) with instant scalping exits for quick wins.

**Risk Level**: ⭐⭐⭐⭐ High (2% per trade, 50 max exposure, instant scalping)

**Ideal For**: Scalpers who want to lock in quick profits while keeping runners

---

#### **#5 - Ultimate_Sniper_EA.mq5 (Elite Hybrid Scalper v6.1 Alternative)**

*Note: Duplicate of #4 with identical functionality*

---

### **Tier 4: Ultra-Aggressive Systems** ⭐⭐

#### **#6 - neewbie.mq5 (Elite Hybrid Scalper v6.2 - FBS Edition)**

The "account multiplier" - designed to grow small accounts explosively (at extreme risk).

**Uniqueness:**
- **Micro Account Doubling Mode**: Special mode for accounts under $20 targeting 100% gains per hour
- **FBS Broker Optimization**: Compensates for FBS spread (1.8 pips) and slippage
- **Insane Risk Parameters**: 15% per trade in micro mode, up to 8 orders per signal
- **100 Position Limit**: Essentially unlimited exposure in micro mode
- **Spread Filtering**: Won't trade if spread exceeds 4 pips
- **Compounding Engine**: Automatically increases lot size as account grows

**Strategy**: M1-bar aggressive entries with minimal filters, designed to capture every micro-movement. High-frequency trading approach.

**Risk Level**: ⭐⭐⭐⭐⭐ EXTREME (15% micro mode / 2% standard)

**Ideal For**: Traders with tiny accounts willing to accept total loss for explosive growth potential

**⚠️ WARNING**: This bot can blow accounts very quickly. Only use with money you can afford to lose entirely.

---

#### **#7 - VAIS_EA_Fibonacci.mq5 (VAIS Momentum Breakout Scalper v1.02)**

The ultimate high-risk, high-reward Fibonacci momentum system.

**Uniqueness:**
- **25% Risk Per Trade**: Most aggressive risk profile in the collection
- **5-in-1 Entry System**: Breakout, momentum, EMA pullback, volatility expansion, S/R sniper
- **Fibonacci Everywhere**: Uses 8, 13, 21, 89 periods and golden ratios throughout
- **Time-Based Exits**: Dynamic max trade duration (10-30 min) based on market conditions
- **News Avoidance**: 30-minute buffer around major economic events
- **Comprehensive Metrics**: Daily/weekly/monthly loss tracking

**Strategy**: M5 XAUUSD scalping combining five different entry methodologies. Waits for volatility expansion (ATR 0.618+) then executes on momentum breakouts.

**Risk Level**: ⭐⭐⭐⭐⭐ EXTREME (25% per trade)

**Ideal For**: Experienced traders seeking maximum aggression with Fibonacci precision

**⚠️ CRITICAL**: 25% risk can lead to account loss in 4 consecutive losses.

---

### **Tier 5: Basic Scalpers** ⭐

#### **#8 - goldscalper.mq5 (GoldScalper v1.34)**

The foundation - basic scalping with minimal filters.

**Uniqueness:**
- **Pure Simplicity**: M15 candle direction + M5 breakout = entry
- **Fixed 10-Pip Everything**: 10-pip SL, 10-pip TP (1:1 R:R)
- **High Volume**: 5 trades per signal, up to 50 total positions
- **10-Minute Expiry**: Pending orders expire quickly
- **No Fibonacci Filters**: Trades purely on price action

**Strategy**: Places breakout orders above/below previous M5 high/low when M15 shows directional bias.

**Risk Level**: ⭐⭐⭐⭐ High (1% total split across 5 trades, high frequency)

**Ideal For**: Understanding basic scalping mechanics, starting point for modifications

**Note**: Lacks sophistication of newer versions. Recommended for educational purposes only.

---

## 📈 Performance Matrix

| Bot | Risk/Trade | Max Exposure | Strategy Type | Timeframes | Win Rate Target | Complexity |
|-----|-----------|--------------|---------------|------------|-----------------|-----------|
| VAIS_EA | 1% | 3/week | Fibonacci Swing | H4 | 55-60% | ⭐⭐⭐⭐⭐ |
| please.mq5 | 1% | 50 | Dynamic Scalp | M5+H1 | 45-50% | ⭐⭐⭐⭐ |
| HYBrid.mq5 | 1% | 50 | Filtered Scalp | M5+M15 | 40-45% | ⭐⭐⭐ |
| Ultimate_Sniper (v6.1) | 2% | 50 | Multi-TF Scalp | M1-H1 | 45-50% | ⭐⭐⭐⭐ |
| neewbie (v6.2) | 2-15% | 50-100 | Micro Account Scalp | M1-H1 | 40-45% | ⭐⭐⭐⭐ |
| VAIS_Fibonacci | 25% | Unlimited | Momentum Breakout | M5 | 50-55% | ⭐⭐⭐⭐⭐ |
| goldscalper | 1% | 50 | Basic Scalp | M5+M15 | 35-40% | ⭐ |

---

## 🛠️ Installation & Setup

### Prerequisites
```
✓ MetaTrader 5 platform
✓ Broker supporting XAUUSD (Gold) trading
✓ Minimum $10 account (micro bots) or $100+ (professional bots)
✓ VPS recommended for 24/7 operation (optional for H4 bot)
```

### Installation Steps

1. **Download & Place Files**
   ```
   Copy .mq5 files to: 
   MetaTrader 5/MQL5/Experts/
   ```

2. **Compile in MetaEditor**
   ```
   Open MetaEditor → File → Open → Select bot
   Press F7 to compile
   ```

3. **Attach to Chart**
   ```
   Open XAUUSD chart
   Drag bot from Navigator onto chart
   Configure input parameters
   Enable AutoTrading (Ctrl+E)
   ```

4. **Recommended Settings by Bot**

   **VAIS_EA (Conservative):**
   - Chart: XAUUSD H4
   - Risk_Per_Trade: 1.0%
   - Max_Weekly_Trades: 3
   - Enable_Trading: true

   **please.mq5 (Balanced):**
   - Chart: XAUUSD M5
   - InpRiskPercent: 1.0%
   - UseH1TrendFilter: true
   - UseFibFilters: true

   **neewbie (Aggressive - Micro Mode):**
   - Chart: XAUUSD M1
   - UseMicroAccountMode: true
   - MicroRiskPercent: 5-10% (start lower!)
   - Balance: <$20 for micro mode

---

## ⚙️ Configuration Guide

### Risk Management Settings

**Conservative Profile** (Recommended for beginners):
```
Risk Per Trade: 0.5-1%
Max Daily Loss: 2-3%
Max Consecutive Losses: 3
```

**Moderate Profile**:
```
Risk Per Trade: 1-2%
Max Daily Loss: 3-5%
Max Consecutive Losses: 4-5
```

**Aggressive Profile** (Experienced only):
```
Risk Per Trade: 2-5%
Max Daily Loss: 5-10%
Max Consecutive Losses: 5+
```

### Broker Considerations

**Spread-Sensitive Bots** (goldscalper, HYBrid, neewbie):
- Maximum spread: 2.0 pips for optimal performance
- ECN/Raw Spread brokers recommended

**Fibonacci Systems** (VAIS_EA, please.mq5):
- Can handle spreads up to 3-5 pips
- Standard broker accounts acceptable

---

## 📊 Backtesting Recommendations

```
Symbol: XAUUSD
Period: Minimum 3 months, ideally 12+ months
Model: Every tick (most accurate)
Spread: Current or Fixed 2.0 pips
Initial Deposit: $100 (scalpers), $500 (swing bots)
```

**Key Metrics to Monitor:**
- Maximum Drawdown (should be <30% for conservative, <50% for aggressive)
- Profit Factor (target >1.5)
- Win Rate (varies by bot, see matrix above)
- Risk/Reward Ratio
- Consecutive losses

---

## 🎓 Learning Path

### For Beginners:
1. Start with **goldscalper** to understand basic scalping
2. Progress to **HYBrid** with filters enabled
3. Graduate to **please.mq5** with full filters
4. Master **VAIS_EA** for professional trading

### For Experienced Traders:
1. Backtest **VAIS_EA** for swing trading
2. Live test **please.mq5** with micro lots
3. Experiment with **Ultimate_Sniper** for multi-TF approach
4. Only consider **neewbie** or **VAIS_Fibonacci** if willing to accept extreme risk

---

## 🔧 Customization Tips

### Modifying Risk Parameters
```mql5
// In any bot, locate:
input double Risk_Per_Trade = 1.0;  // Adjust this

// For Fibonacci bots, maintain golden ratios:
input double TP_ATR_Multiple = 2.618;  // φ²
input double Partial_Exit_R = 1.618;    // φ
input double Trail_Distance_ATR = 0.618; // φ⁻¹
```

### Adding Custom Indicators
```mql5
// Example: Add Stochastic filter
int hStoch = iStochastic(_Symbol, PERIOD_M5, 14, 3, 3, MODE_SMA, STO_LOWHIGH);
// Then add condition checking in entry logic
```

---

## 📖 Documentation

Each bot includes:
- **Input Parameters**: Fully commented for easy understanding
- **Strategy Logic**: Clear entry/exit conditions
- **Risk Management**: Configurable limits and protections
- **Logging**: Detailed trade logs for analysis (where applicable)

---

## ⚠️ Risk Disclaimer

```
Trading financial instruments carries substantial risk of loss.
These bots are provided for EDUCATIONAL PURPOSES ONLY.

- Past performance does NOT guarantee future results
- High-risk bots (neewbie, VAIS_Fibonacci) can cause total account loss
- Always backtest thoroughly before live trading
- Start with demo accounts
- Never risk money you cannot afford to lose
- Consider your risk tolerance and trading experience

The developers assume NO responsibility for trading losses.
```

---

## 🤝 Contributing

Contributions welcome! Areas of interest:
- Strategy improvements
- Additional filters
- Better risk management
- Multi-symbol support
- Machine learning integration

---

## 📄 License

These Expert Advisors are provided for educational and research purposes. Use at your own risk.

---

## 🌟 Final Recommendations

### **Best for Long-Term Success**: VAIS_EA
- Mathematical rigor + professional risk management
- Sustainable 1% risk with quality setups
- H4 timeframe = less stress, better decisions

### **Best for Active Scalping**: please.mq5
- Perfect balance of aggression and safety
- Dynamic ATR adaptation
- H1 trend filter prevents counter-trend disasters

### **Best for Small Account Growth** (High Risk): neewbie.mq5
- Specifically designed for micro accounts
- Can multiply accounts quickly (or lose them quickly)
- Only use with risk capital

### **Best for Learning**: goldscalper → HYBrid → please.mq5
- Progressive complexity
- Build understanding step by step
- Graduate to professional systems

---

## 📞 Support & Community

- GitHub Issues: For bug reports and feature requests
- Backtest Results: Share your findings!
- Strategy Discussions: What works in your market?

---

**Remember**: The best bot is the one that matches YOUR risk tolerance, time commitment, and trading psychology. Start conservative, test thoroughly, and scale carefully.

Happy Trading! 🚀📈
