/*
 * @file
 * Defines default strategy parameter values for the given timeframe.
 */

// Defines strategy's parameter values for the given pair symbol and timeframe.
struct Stg_Pattern_Params_M5 : StgParams {
  // Struct constructor.
  Stg_Pattern_Params_M5() : StgParams(stg_pattern_defaults) {}
} stg_pattern_m5;
