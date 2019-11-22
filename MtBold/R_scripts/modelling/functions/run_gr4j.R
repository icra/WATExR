#' Run GR4J and format for GOTM
#'
#' Run GR4J and format the output as inputs for GOTM
#'
#' @param time POSIXt; vector of dates required to create the GR model and CemaNeige module inputs
#' @param pet numeric;  time series of potential evapotranspiration (catchment average) [mm/time step], required to create the GR model inputs
#' @param pre  time series of total precipitation (catchment average) [mm/time step], required to create the GR model inputs
#' @param airt numeric; time series of mean air temperature [°C], required to calculate temperature. Only require if calc_T = TRUE
#' @param warmup_ratio numeric; Double of the ratio between warmup and run period, default is 1 which refers to warm up:run 1:1, 2 would mean that warm up:run would be 2:1. If NULL no warm up is used. Defaults to NULL
#' @param param numeric; vector of 4 parameters
#' GR4J X1	production store capacity [mm]
#' GR4J X2	intercatchment exchange coefficient [mm/d]
#' GR4J X3	routing store capacity [mm]
#' GR4J X4	unit hydrograph time constant [d]
#' @param catch_size numeric; catchment size [km.2]
#' @param out_file filepath; File to save GR4J output as GOTM input file
#' @param calc_T boolean; calculate and include stream temperature using formula:
#' water_temp = 5.0 + 0.75 * air_temp
#' from Stefan, H.G. and E.B. Preudíhomme. 1993. Stream temperature estimation from air temperature. Water Resources Bulletin 29(1): 27-45
#' @param vector boolean; return a vector of discharge [m.3.s-1]. Default = TRUE
#' @examples time = as.POSIXct(met[,1], tz = 'UTC)
#' airt = met$tas_degC
#' pre = met$pr_mm
#' pet = met$petH_mm.day.1
#' ## Parameters from previous calibration
#' param = c(3154.353493,-1117.839156,141.213475,2.024065
#' catch_size <- 214.7
#' @import airGR
#' @export

run_gr4j <- function(time, pet, pre, airt = NULL, warmup_ratio = NULL, param, catch_size, out_file, calc_T = FALSE, vector = TRUE){
  
  inputs <- CreateInputsModel(RunModel_GR4J, DatesR = time, Precip = pre, PotEvap = pet)
  if(is.null(warmup_ratio)){
    opts <- CreateRunOptions(RunModel_GR4J, InputsModel = inputs,IndPeriod_Run = 1:length(time),IndPeriod_WarmUp = NULL)
  }else{
    start = time[1]
    stop = time[length(time)]
    dur <-  stop - start
    interval <- dur/(warmup_ratio + 1)
    start1 <- start
    stop1 <- start1 + interval
    warmup_ind = 1:length(time[time < stop1])
    
    run_ind = (length(time[time < stop1])+1):length(time)
    opts <- CreateRunOptions(RunModel_GR4J, InputsModel = inputs,IndPeriod_Run = run_ind, IndPeriod_WarmUp = warmup_ind)
  }
  
  mod1 = RunModel_GR4J(InputsModel = inputs, RunOptions = opts, Param = param)
  message('GR4J simulation compete!')
  
  #Convert model output to dataframe
  qdf <- data.frame(Date = mod1$DatesR, qsim = mod1$Qsim)
  ## NEEDS CHECK
  # qdf$flow <- (qdf[,2] * catch_size *200000)/(60*60*24)
  # From: https://www.researchgate.net/post/How_to_convert_discharge_m3_s_to_mm_of_discharge
  # Q (mm/day) = Q(m^3/s) *1000*24*3600/ Area (m^2)
  # Q (mm/day) * Area (m^2) = Q(m^3/s) *1000*24*3600
  # Q (mm/day) * Area (m^2) /(1000*24*3600) = Q(m^3/s) 
  qdf$flow <- (qdf[,2] * catch_size *1000000)/(1000*60*60*24)
  
  flow <- qdf[,c(1,3)]
  colnames(flow) <- c('!DateTime', 'Q_m.3.s.1')
  if(calc_T){
    
    flow$T_degC = 5.0 + 0.75 * airt #Stefan, H.G. and E.B. Preudíhomme. 1993. Stream temperature estimation from air temperature. Water Resources Bulletin 29(1): 27-45
    
  }
  
  flow[,1] <- format(flow[,1], '%Y-%m-%d %H:%M:%S')
  write.table(flow, out_file, row.names = F, col.names = T, quote = F, sep = '\t')
  message('Create discharge file: ', out_file)
  if(vector){
    flow[,1] <- as.POSIXct(flow[,1])
    return(flow[,1:2])
  }
}