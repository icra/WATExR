# Load packages.
library(transformeR);library(loadeR.ECOMS);library(loadeR);library(visualizeR)
library(convertR);library(drought4R);library(downscaleR)

####### GENERAL SETTINGS THAT NEED TO BE DEFINED: --------------------------------------------------

#Observations:
load("/home/ry4902/Documents/EWEMBI_Download/Interpolated_SAU-SQD/Interpolated_1982-2009.RData")
data.interp_obs <- data.interp

#Model data
load("/home/ry4902/Documents/System4_Download/Interpolated_SAU-SQD/Interpolated_1982-2009.RData")

#Convert pressure units to millibars and temperature units to celsius with function udConvertGrid from package convertR.
data.interp$ps <- udConvertGrid(data.interp$ps, new.units = "millibars")
data.interp$tas <- udConvertGrid(data.interp$tas, new.units = "celsius")
data.interp_obs$ps <- udConvertGrid(data.interp_obs$ps, new.units = "millibars")
data.interp_obs$tas <- udConvertGrid(data.interp_obs$tas, new.units = "celsius")

# Define the members
mem <- 1:15
# Define the lead month
lead.month <- 1
# Define period and season
years <- 1983:2009

season_name <- c("winter", "spring", "summer", "autumn")
c <- 0
for (season in list(c(12,1,2), c(3:5), c(6:8), c(9:11))){
  c <- c+1
  ########## DATA LOADING AND TRANSFORMATION ----------------------------------------------------------
  
  ##### BIAS CORRECTION -----------------------------------------------------------------------
  # Subset model data to the same season as forecast data
  data <- list(data.interp$tas, data.interp$tasmax, data.interp$tasmin, data.interp$pr,
               data.interp$uas, data.interp$vas, data.interp$hurs, data.interp$ps,
               data.interp$rsds, data.interp$rlds)
  data <- lapply(data, function(x) subsetGrid(x, season = season, years = years))
  names(data) <- c("tas", "tasmax", "tasmin", "pr", "uas", "vas", "hurs", "ps", "rsds", "rlds")
  
  # Subset observational data to the same season as forecast data
  obs.data <- list(data.interp_obs$tas, data.interp_obs$tasmax, data.interp_obs$tasmin, data.interp_obs$pr,
                   data.interp_obs$uas, data.interp_obs$vas, data.interp_obs$hurs, data.interp_obs$ps,
                   data.interp_obs$rsds, data.interp_obs$rlds)
  obs.data <- lapply(obs.data, function(x) subsetGrid(x, season = season))
  obs.data <- lapply(obs.data, function(x) subsetGrid(x, years = years))
  names(obs.data) <- c("tas", "tasmax", "tasmin", "pr", "uas", "vas", "hurs", "ps", "rsds", "rlds")
  
  # Check variable consistency
  if (!identical(names(obs.data), names(data))) stop("variables in obs.data and data (seasonal forecast) do not match.")
  
  # Bias correction with leave-one-year-out ("loo") cross-validation
  # type ?biasCorrection in R for more info about the parameter settings for bias correction.
  data.bc.cross <- lapply(1:length(data), function(x)  {
    precip <- FALSE
    if (names(data)[x] == "pr") precip <- TRUE
    biasCorrection(y = obs.data[[x]], x = data[[x]], 
                   method = "eqm", cross.val = "loo",
                   precipitation = precip,
                   window = c(30,7),
                   wet.threshold = 1)
  }) 
  
  names(data.bc.cross) <- names(data)
  save(data.bc.cross, file = paste("/home/ry4902/Documents/System4_Download/BiasCorrectedWithEWEMBI_SAU-SQD/", season_name[c],".RData", sep=""))
}
