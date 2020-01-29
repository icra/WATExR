def bayes_net_predict(year, chla_prev_summer, colour_prev_summer,
                      tp_prev_summer, wind_speed, rain):
    """ Make predictions given the evidence provided based on the pre-fitted Bayesian network (saved as 
        'Vansjo_fitted_seasonal_GaussianBN_1981-2018.rds'). This function is just a thin "wrapper" 
        around the R function named 'bayes_net_predict' in 'bayes_net_utils.R'.
        
        NOTE: 'bayes_net_utils.R' must be in the same folder as this file.
        
    Args:
        year:              Int. Year for prediction
        chla_prevSummer:   Float. Chl-a measured from the previous summer 
        colour_prevSummer: Float. Colour measured from the previous summer
        TP_prevSummer:     Float. Total P measured from the previous summer
        wind_speed:        Float. Predicted wind speed for season of interest
        rain:              Float. Predicted precipitation for season of interest
    
    Returns:
        Dataframe
    """
    import pandas as pd
    import rpy2.robjects as ro
    from rpy2.robjects.packages import importr
    from rpy2.robjects import pandas2ri
    from rpy2.robjects.conversion import localconverter
    
    # Load R script
    ro.r.source('bayes_net_utils.R')

    # Call R function with user-specified evidence
    res = ro.r['bayes_net_predict'](year, chla_prev_summer, colour_prev_summer,
                                    tp_prev_summer, wind_speed, rain)

    # Convert back to Pandas df
    with localconverter(ro.default_converter + pandas2ri.converter):
        df = ro.conversion.rpy2py(res)

    return df