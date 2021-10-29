/**
 * @file
 * Implements Pinbar strategy based on the Pinbar indicator.
 */

// User input params.
INPUT_GROUP("Pinbar strategy: strategy params");
INPUT float Pinbar_LotSize = 0;                // Lot size
INPUT int Pinbar_SignalOpenMethod = 24064;     // Signal open method (0-161000)
INPUT float Pinbar_SignalOpenLevel = 0.6f;     // Signal open level
INPUT int Pinbar_SignalOpenFilterMethod = 40;  // Signal open filter method
INPUT int Pinbar_SignalOpenFilterTime = 3;     // Signal open filter time (0-31)
INPUT int Pinbar_SignalOpenBoostMethod = 0;    // Signal open boost method
INPUT int Pinbar_SignalCloseMethod = 132012;   // Signal close method (0-161000)
INPUT int Pinbar_SignalCloseFilter = 10;       // Signal close filter (-127-127)
INPUT float Pinbar_SignalCloseLevel = 0.7f;    // Signal close level
INPUT int Pinbar_PriceStopMethod = 0;          // Price limit method
INPUT float Pinbar_PriceStopLevel = 2;         // Price limit level
INPUT int Pinbar_TickFilterMethod = 32;        // Tick filter method (0-255)
INPUT float Pinbar_MaxSpread = 4.0;            // Max spread to trade (in pips)
INPUT short Pinbar_Shift = 0;                  // Shift
INPUT float Pinbar_OrderCloseLoss = 80;        // Order close loss
INPUT float Pinbar_OrderCloseProfit = 80;      // Order close profit
INPUT int Pinbar_OrderCloseTime = -6;          // Order close time in mins (>0) or bars (<0)
INPUT_GROUP("Pinbar strategy: Pattern indicator params");
INPUT int Pattern_Indi_Pattern_Shift = 1;  // Shift

// Structs.

// Defines struct with default user indicator values.
struct Indi_Pattern_Params_Defaults : IndiPatternParams {
  Indi_Pattern_Params_Defaults() : IndiPatternParams(::Pattern_Indi_Pattern_Shift) {}
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
    Indi_Pattern_Params_Defaults indi_pattern_defaults;
    IndiPatternParams _indi_params(indi_pattern_defaults, _tf);
    Stg_Pinbar_Params_Defaults stg_pinbar_defaults;
    StgParams _stg_params(stg_pinbar_defaults);
#ifdef __config__
    SetParamsByTf<StgParams>(_stg_params, _tf, stg_pinbar_m1, stg_pinbar_m5, stg_pinbar_m15, stg_pinbar_m30,
                             stg_pinbar_h1, stg_pinbar_h4, stg_pinbar_h8);
#endif
    // Initialize indicator.
    // Initialize Strategy instance.
    ChartParams _cparams(_tf, _Symbol);
    TradeParams _tparams;
    Strategy *_strat = new Stg_Pinbar(_stg_params, _tparams, _cparams, "Pinbar");
    _strat.SetIndicator(new Indi_Pattern(_indi_params));
    return _strat;
  }

  /**
   * Check strategy's opening signal.
   */
  bool SignalOpen(ENUM_ORDER_TYPE _cmd, int _method, float _level = 0.0f, int _shift = 0) {
    Indi_Pattern *_indi = GetIndicator();
    BarOHLC _ohlc0 = _indi.GetOHLC(_shift);
    BarOHLC _ohlc1 = _indi.GetOHLC(_shift + 1);
    bool _result =
        _indi.GetFlag(INDI_ENTRY_FLAG_IS_VALID, _shift) && _indi.GetFlag(INDI_ENTRY_FLAG_IS_VALID, _shift + 2);
    _result &= _ohlc0.IsValid();
    _result &= _ohlc1.IsValid();
    if (!_result) {
      // Returns false when indicator data is not valid.
      return false;
    }
    IndicatorDataEntry _entry = _indi[_shift];
    double _change_pc = Math::ChangeInPct(_ohlc0.GetRange(), _ohlc1.GetRange());
    _result &= fabs(_change_pc) > _level;
    switch (_cmd) {
      case ORDER_TYPE_BUY:
        // Buy signal.
        if (_method != 0) {
          _result &= (_entry.GetValue<int>(fmin(4, _method / 32)) & (1 << (_method % 32))) != 0;
        }
        break;
      case ORDER_TYPE_SELL:
        // Sell signal.
        if (fabs(_method) >= 1000) {
          _result &= (_entry.GetValue<int>(fmin(4, _method / 1000 / 32)) & (1 << (int(_method / 1000) % 32))) != 0;
        }
        break;
    }
    return _result;
  }
};
