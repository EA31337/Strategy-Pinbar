/**
 * @file
 * Implements Pinbar strategy based on the Pinbar indicator.
 */

// User input params.
INPUT_GROUP("Pinbar strategy: strategy params");
INPUT float Pinbar_LotSize = 0;                // Lot size
INPUT int Pinbar_SignalOpenMethod = 0;         // Signal open method (0-161000)
INPUT float Pinbar_SignalOpenLevel = 2.0f;     // Signal open level
INPUT int Pinbar_SignalOpenFilterMethod = 40;  // Signal open filter method
INPUT int Pinbar_SignalOpenFilterTime = 3;     // Signal open filter time (0-31)
INPUT int Pinbar_SignalOpenBoostMethod = 0;    // Signal open boost method
INPUT int Pinbar_SignalCloseMethod = 0;        // Signal close method (0-161000)
INPUT int Pinbar_SignalCloseFilter = 10;       // Signal close filter (-127-127)
INPUT float Pinbar_SignalCloseLevel = 2.0f;    // Signal close level
INPUT int Pinbar_PriceStopMethod = 0;          // Price limit method
INPUT float Pinbar_PriceStopLevel = 2;         // Price limit level
INPUT int Pinbar_TickFilterMethod = 32;        // Tick filter method (0-255)
INPUT float Pinbar_MaxSpread = 4.0;            // Max spread to trade (in pips)
INPUT short Pinbar_Shift = 0;                  // Shift
INPUT float Pinbar_OrderCloseLoss = 80;        // Order close loss
INPUT float Pinbar_OrderCloseProfit = 80;      // Order close profit
INPUT int Pinbar_OrderCloseTime = -30;         // Order close time in mins (>0) or bars (<0)
INPUT_GROUP("Pinbar strategy: Pattern indicator params");
INPUT int Pinbar_Indi_Pattern_Shift = 1;  // Shift
INPUT_GROUP("Pinbar strategy: CCI indicator params");
INPUT int Pinbar_Indi_CCI_Period = 20;                                   // Period
INPUT ENUM_APPLIED_PRICE Pinbar_Indi_CCI_Applied_Price = PRICE_TYPICAL;  // Applied Price
INPUT int Pinbar_Indi_CCI_Shift = 0;                                     // Shift
INPUT_GROUP("Pinbar strategy: RSI indicator params");
INPUT int Pinbar_Indi_RSI_Period = 14;                                    // Period
INPUT ENUM_APPLIED_PRICE Pinbar_Indi_RSI_Applied_Price = PRICE_WEIGHTED;  // Applied Price
INPUT int Pinbar_Indi_RSI_Shift = 0;                                      // Shift

// Structs.

// Defines struct with default user indicator values.
struct Indi_CCI_Params_Defaults : CCIParams {
  Indi_CCI_Params_Defaults()
      : CCIParams(::Pinbar_Indi_CCI_Period, ::Pinbar_Indi_CCI_Applied_Price, ::Pinbar_Indi_CCI_Shift) {}
};

// Defines struct with default user indicator values.
struct Indi_Pattern_Params_Defaults : IndiPatternParams {
  Indi_Pattern_Params_Defaults() : IndiPatternParams(::Pinbar_Indi_Pattern_Shift) {}
};

// Defines struct with default user indicator values.
struct Indi_RSI_Params_Defaults : RSIParams {
  Indi_RSI_Params_Defaults()
      : RSIParams(::Pinbar_Indi_RSI_Period, ::Pinbar_Indi_RSI_Applied_Price, ::Pinbar_Indi_RSI_Shift) {}
};

// Defines struct with default user strategy values.
struct Stg_Pinbar_Params_Defaults : StgParams {
  Stg_Pinbar_Params_Defaults()
      : StgParams(::Pinbar_SignalOpenMethod, ::Pinbar_SignalOpenFilterMethod, ::Pinbar_SignalOpenLevel,
                  ::Pinbar_SignalOpenBoostMethod, ::Pinbar_SignalCloseMethod, ::Pinbar_SignalCloseFilter,
                  ::Pinbar_SignalCloseLevel, ::Pinbar_PriceStopMethod, ::Pinbar_PriceStopLevel,
                  ::Pinbar_TickFilterMethod, ::Pinbar_MaxSpread, ::Pinbar_Shift) {
    Set(STRAT_PARAM_LS, Pinbar_LotSize);
    Set(STRAT_PARAM_OCL, Pinbar_OrderCloseLoss);
    Set(STRAT_PARAM_OCP, Pinbar_OrderCloseProfit);
    Set(STRAT_PARAM_OCT, Pinbar_OrderCloseTime);
    Set(STRAT_PARAM_SOFT, Pinbar_SignalOpenFilterTime);
  }
};

class Stg_Pinbar : public Strategy {
 public:
  Stg_Pinbar(StgParams &_sparams, TradeParams &_tparams, ChartParams &_cparams, string _name = "")
      : Strategy(_sparams, _tparams, _cparams, _name) {}

  static Stg_Pinbar *Init(ENUM_TIMEFRAMES _tf = NULL) {
    // Initialize strategy initial values.
    // Initialize Strategy instance.
    ChartParams _cparams(_tf, _Symbol);
    TradeParams _tparams;
    Stg_Pinbar_Params_Defaults stg_pinbar_defaults;
    StgParams _stg_params(stg_pinbar_defaults);
    Strategy *_strat = new Stg_Pinbar(_stg_params, _tparams, _cparams, "Pinbar");
    // Initialize indicators.
    Indi_CCI_Params_Defaults indi_cci_defaults;
    CCIParams _indi_params(indi_cci_defaults, _tf);
    _strat.SetIndicator(new Indi_CCI(_indi_params), INDI_CCI);

    Indi_Pattern_Params_Defaults _indi_pattern_defaults;
    IndiPatternParams _indi_pattern_params(_indi_pattern_defaults, _tf);
    _strat.SetIndicator(new Indi_Pattern(_indi_pattern_params), INDI_PATTERN);

    Indi_RSI_Params_Defaults _indi_rsi_defaults;
    RSIParams _indi_rsi_params(_indi_rsi_defaults, _tf);
    _strat.SetIndicator(new Indi_RSI(_indi_rsi_params), INDI_RSI);
    return _strat;
  }

  /**
   * Check strategy's opening signal.
   */
  bool SignalOpen(ENUM_ORDER_TYPE _cmd, int _method, float _level = 0.0f, int _shift = 0) {
    Indi_CCI *_indi_cci = GetIndicator(INDI_CCI);
    Indi_Pattern *_indi_pattern = GetIndicator(INDI_PATTERN);
    Indi_RSI *_indi_rsi = GetIndicator(INDI_RSI);
    Chart *_chart = (Chart *)_indi_pattern;
    bool _result = _indi_cci.GetFlag(INDI_ENTRY_FLAG_IS_VALID, _shift) &&
                   _indi_pattern.GetFlag(INDI_ENTRY_FLAG_IS_VALID, _shift) &&
                   _indi_rsi.GetFlag(INDI_ENTRY_FLAG_IS_VALID, _shift);
    if (!_result) {
      // Returns false when indicator data is not valid.
      return false;
    }
    bool is_pinbar = (int(_indi_pattern[_shift][0]) & PATTERN_1CANDLE_IS_SPINNINGTOP) != 0;
    // double _change_pc = Math::ChangeInPct(_ohlc0.GetRange(), _ohlc1.GetRange());
    //_result &= fabs(_change_pc) > _level;
    switch (_cmd) {
      case ORDER_TYPE_BUY:
        // Buy signal.
        _result &= _indi_cci[_shift][0] < ::Pinbar_Indi_CCI_Period * _level;
        _result &= _indi_rsi[_shift][0] < (::Pinbar_Indi_RSI_Period * _level);
        _result &= (int(_indi_pattern[_shift][0]) & (PATTERN_1CANDLE_IS_SPINNINGTOP | PATTERN_1CANDLE_CHANGE_GT_01PC |
                                                    ~PATTERN_1CANDLE_BODY_GT_WICKS)) != 0;
        if (_method != 0) {
          //_result &= (_entry.GetValue<int>(fmin(4, _method / 32)) & (1 << (_method % 32))) != 0;
        }
        break;
      case ORDER_TYPE_SELL:
        // Sell signal.
        _result &= _indi_cci[_shift][0] > ::Pinbar_Indi_CCI_Period * _level;
        _result &= _indi_rsi[_shift][0] > (100 - ::Pinbar_Indi_RSI_Period * _level);
        _result &= (int(_indi_pattern[_shift][0]) & (PATTERN_1CANDLE_IS_SPINNINGTOP | PATTERN_1CANDLE_CHANGE_GT_01PC |
                                                    ~PATTERN_1CANDLE_BODY_GT_WICKS)) != 0;
        if (fabs(_method) >= 1000) {
          //_result &= (_entry.GetValue<int>(fmin(4, _method / 1000 / 32)) & (1 << (int(_method / 1000) % 32))) != 0;
        }
        break;
    }
    if (is_pinbar) {
      // DebugBreak();
      _result &= (int(_indi_pattern[_shift][0]) & PATTERN_1CANDLE_IS_SPINNINGTOP) != 0;
    }
    if (_result) {
      // DebugBreak();
    }
    return _result;
  }
};
