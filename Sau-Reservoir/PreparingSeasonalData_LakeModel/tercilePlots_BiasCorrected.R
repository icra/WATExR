library(transformeR);library(loadeR.ECOMS);library(loadeR);library(downscaleR);library(lubridate)
library(visualizeR); library(sp);library(rgdal);library(loadeR.2nc); library(RNetCDF); library(sp)
library(ncdf4); library(raster);library(convertR);library(drought4R);library(imputeTS)
library(lubridate);library(mgcv); library(rowr)

#···········Opening Observation
load("/home/ry4902/Documents/EWEMBI_Download/Interpolated_SAU-SQD/Interpolated_1982-2009.RData")

#Cloud cover
data.interp$cc <- rad2cc(rsds = data.interp$rsds, rlds = data.interp$rlds)

#Dew point
data.interp$tdew <- data.interp$hurs
H_dew <- log(data.interp$hurs$Data/100) + 
  (17.62*data.interp$tas$Data)/(243.12+data.interp$tas$Data)
data.interp$tdew$Data <- 243.12*H_dew/(17.62-H_dew) # // this is the dew point in Celsius;
#Hardy B., Thunder Scientific Corporation, Albuquerque, NM, USA
#The proceedings of the Third international Symposium on Humidity & Moisture, Teddington, London, England,
#April 1998. 

#···········Opening seasonal forecast data
num_season <- 0; list_seasons <- list(c(9:11), c(3:5), c(6:8), c(12,1,2))
for (season in c("autumn", "spring", "summer", "winter")){
  num_season <- num_season + 1
  load(paste("/home/ry4902/Documents/System4_Download/BiasCorrectedWithEWEMBI_SAU-SQD/", season,".RData", sep=""))
  #Cloud cover
  data.bc.cross$cc <- rad2cc(rsds = data.bc.cross$rsds, rlds = data.bc.cross$rlds)
  
  #Dew point
  data.bc.cross$tdew <- data.bc.cross$hurs
  H_dew <- log(data.bc.cross$hurs$Data/100) + 
    (17.62*data.bc.cross$tas$Data)/(243.12+data.bc.cross$tas$Data)
  data.bc.cross$tdew$Data <- 243.12*H_dew/(17.62-H_dew) # // this is the dew point in Celsius;
  #Hardy B., Thunder Scientific Corporation, Albuquerque, NM, USA
  #The proceedings of the Third international Symposium on Humidity & Moisture, Teddington, London, England,
  #April 1998. 
  
  for (var in c("ps", "uas", "vas", "tas", "pr", "rsds", "cc", "tdew")){
    hindcast <- data.bc.cross[[var]]
    hindcast <- subsetGrid(hindcast, season = list_seasons[[num_season]], years = c(1983:2009))
    hindcast$Data <- array(data = NA, dim = c(15, dim(hindcast$Data)[2],1,1))
    hindcast$Data[,,1,1] <- subsetGrid(data.bc.cross[[var]], season = list_seasons[[num_season]], years = c(1983:2009))$Data
    attr(hindcast$Data, "dimensions") <- c("member", "time", "lat", "lon")
    observation <- data.interp[[var]]
    if (season=="winter"){
      obs_dic <- subsetGrid(observation, season = 12, years = c(1982:2008))
      obs_all <- subsetGrid(observation, season = c(1:2), years = c(1983:2009))
      observation <- bindGrid(obs_all, obs_dic, dimension = c("time"))
      
      observation$Data <- array(data = NA, dim = c(dim(observation$Data)[3],1,1))
      set_dic <- subsetGrid(data.interp[[var]], season = 12, years = c(1982:2008))
      set_all <- subsetGrid(data.interp[[var]], season = c(1:2), years = c(1983:2009))
      set_set <- bindGrid(set_all, set_dic, dimension = c("time"))
      observation$Data[,1,1] <- set_set$Data[1,1,,,]
      
    }else{
      observation <- subsetGrid(observation, season = list_seasons[[num_season]], years = c(1983:2009))
      observation$Data <- array(data = NA, dim = c(dim(observation$Data),1,1))
      observation$Data[,1,1] <- subsetGrid(data.interp[[var]], season = list_seasons[[num_season]], years = c(1983:2009))$Data
    }
    attr(observation$Data, "dimensions") <- c("time", "lat", "lon")
    if (var=="ps"){
      observation <- gridArithmetics(observation, 100, operator = "/")
      attr(observation$Data, "dimensions") <- c("time", "lat", "lon")
    }
    pdf(paste("/home/ry4902/Documents/System4_Download/BiasCorrectedWithEWEMBI_SAU-SQD/TercilePlots/",var,"_",season,".pdf", sep=""))
    tercilePlot(hindcast, observation)
    dev.off()
  }
}

