/**
 * @file
 * Implements Pinbar strategy based on the Pinbar indicator.
 */

// User input params.
INPUT_GROUP("Pinbar strategy: strategy params");
INPUT float Pinbar_LotSize = 0;                // Lot size
INPUT int Pinbar_SignalOpenMethod = 2;         // Signal open method (0-16)
INPUT float Pinbar_SignalOpenLevel = 1.6f;     // Signal open level
INPUT int Pinbar_SignalOpenFilterMethod = 40;  // Signal open filter method
INPUT int Pinbar_SignalOpenFilterTime = 3;     // Signal open filter time (0-31)
INPUT int Pinbar_SignalOpenBoostMethod = 0;    // Signal open boost method
INPUT int Pinbar_SignalCloseMethod = 2;        // Signal close method (0-16)
INPUT int Pinbar_SignalCloseFilter = 0;        // Signal close filter (-127-127)
INPUT float Pinbar_SignalCloseLevel = 2.4f;    // Signal close level
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
INPUT_GROUP("Pinbar strategy: ATR indicator params");
INPUT int Pinbar_Indi_ATR_Period = 14;  // Period
INPUT int Pinbar_Indi_ATR_Shift = 0;    // Shift
INPUT_GROUP("Pinbar strategy: CCI indicator params");
INPUT int Pinbar_Indi_CCI_Period = 18;                                   // Period
INPUT ENUM_APPLIED_PRICE Pinbar_Indi_CCI_Applied_Price = PRICE_TYPICAL;  // Applied Price
INPUT int Pinbar_Indi_CCI_Shift = 0;                                     // Shift
INPUT_GROUP("Pinbar strategy: RSI indicator params");
INPUT int Pinbar_Indi_RSI_Period = 20;                                 // Period
INPUT ENUM_APPLIED_PRICE Pinbar_Indi_RSI_Applied_Price = PRICE_CLOSE;  // Applied Price
INPUT int Pinbar_Indi_RSI_Shift = 0;                                   // Shift

// Structs.

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
    ChartParams _cparams(_tf, _Symbol);
    TradeParams _tparams;
    Stg_Pinbar_Params_Defaults stg_pinbar_defaults;
    Strategy *_strat = new Stg_Pinbar(stg_pinbar_defaults, _tparams, _cparams, "Pinbar");
    return _strat;
  }

  /**
   * Event on strategy's init.
   */
  void OnInit() {
    // Initialize indicators.
    IndiATRParams _indi_atr_params(::Pinbar_Indi_ATR_Period, ::Pinbar_Indi_ATR_Shift);
    _indi_atr_params.SetTf(Get<ENUM_TIMEFRAMES>(STRAT_PARAM_TF));
    SetIndicator(new Indi_ATR(_indi_atr_params), INDI_ATR);

    IndiCCIParams _indi_cci_params(::Pinbar_Indi_CCI_Period, ::Pinbar_Indi_CCI_Applied_Price, ::Pinbar_Indi_CCI_Shift);
    _indi_cci_params.SetTf(Get<ENUM_TIMEFRAMES>(STRAT_PARAM_TF));
    SetIndicator(new Indi_CCI(_indi_cci_params), INDI_CCI);

    IndiPatternParams _indi_pattern_params(::Pinbar_Indi_Pattern_Shift);
    _indi_pattern_params.SetTf(Get<ENUM_TIMEFRAMES>(STRAT_PARAM_TF));
    SetIndicator(new Indi_Pattern(_indi_pattern_params), INDI_PATTERN);

    IndiRSIParams _indi_rsi_params(::Pinbar_Indi_RSI_Period, ::Pinbar_Indi_RSI_Applied_Price, ::Pinbar_Indi_RSI_Shift);
    _indi_rsi_params.SetTf(Get<ENUM_TIMEFRAMES>(STRAT_PARAM_TF));
    SetIndicator(new Indi_RSI(_indi_rsi_params), INDI_RSI);
  }

  /**
   * Check strategy's opening signal.
   */
  bool SignalOpen(ENUM_ORDER_TYPE _cmd, int _method, float _level = 0.0f, int _shift = 0) {
    Indi_ATR *_indi_atr = GetIndicator(INDI_ATR);
    Indi_CCI *_indi_cci = GetIndicator(INDI_CCI);
    Indi_Pattern *_indi_pattern = GetIndicator(INDI_PATTERN);
    Indi_RSI *_indi_rsi = GetIndicator(INDI_RSI);
    Chart *_chart = (Chart *)_indi_pattern;
    bool _result = _indi_cci.GetFlag(INDI_ENTRY_FLAG_IS_VALID, 1) &&
                   _indi_pattern.GetFlag(INDI_ENTRY_FLAG_IS_VALID, 1) && _indi_rsi.GetFlag(INDI_ENTRY_FLAG_IS_VALID, 1);
    if (!_result) {
      // Returns false when indicator data is not valid.
      return false;
    }
    int _indi_cci_shift = ::Pinbar_Indi_CCI_Shift;          // @todo: Read value from _indi_cci iparams.
    int _indi_pattern_shift = ::Pinbar_Indi_Pattern_Shift;  // @todo: Read value from _indi_pattern iparams.
    int _indi_rsi_shift = ::Pinbar_Indi_RSI_Shift;          // @todo: Read value from _indi_rsi iparams.
    // bool is_pinbar = (int(_indi_pattern[_indi_pattern_shift][0]) & PATTERN_1CANDLE_IS_SPINNINGTOP) != 0;
    // double _change_pc = Math::ChangeInPct(_ohlc0.GetRange(), _ohlc1.GetRange());
    //_result &= fabs(_change_pc) > _level;
    PatternCandle1 _pattern((uint)_indi_pattern[_indi_pattern_shift][0]);
    switch (_cmd) {
      case ORDER_TYPE_BUY:
        // Buy signal.
        _result &= _pattern.CheckPattern(PATTERN_1CANDLE_IS_SPINNINGTOP);
        _result &= _indi_rsi[_indi_rsi_shift][0] < (::Pinbar_Indi_RSI_Period * _level);
        if (METHOD(_method, 0)) _result &= _method > 0 ? _indi_atr.IsIncreasing(1) : _indi_atr.IsDecreasing(1);
        if (METHOD(_method, 1)) _result &= _indi_cci[_indi_cci_shift][0] < ::Pinbar_Indi_CCI_Period * _level;
        // if (METHOD(_method, 2)) _result &= _pattern.CheckPattern(PATTERN_1CANDLE_CHANGE_GT_01PC);
        // if (METHOD(_method, 3)) _result &= !_pattern.CheckPattern(PATTERN_1CANDLE_BODY_GT_WICKS);
        break;
      case ORDER_TYPE_SELL:
        // Sell signal.
        _result &= _pattern.CheckPattern(PATTERN_1CANDLE_IS_SPINNINGTOP);
        _result &= _indi_rsi[_indi_rsi_shift][0] > (100 - ::Pinbar_Indi_RSI_Period * _level);
        if (METHOD(_method, 0)) _result &= _method > 0 ? _indi_atr.IsIncreasing(1) : _indi_atr.IsDecreasing(1);
        if (METHOD(_method, 1)) _result &= _indi_cci[_indi_cci_shift][0] > ::Pinbar_Indi_CCI_Period * _level;
        // if (METHOD(_method, 2)) _result &= _pattern.CheckPattern(PATTERN_1CANDLE_CHANGE_GT_01PC);
        // if (METHOD(_method, 3)) _result &= !_pattern.CheckPattern(PATTERN_1CANDLE_BODY_GT_WICKS);
        break;
    }
    if (_result) {
      // DebugBreak();
    }
    return _result;
  }
};
