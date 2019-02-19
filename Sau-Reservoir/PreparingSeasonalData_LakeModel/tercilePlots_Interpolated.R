library(transformeR);library(loadeR.ECOMS);library(loadeR);library(downscaleR);library(lubridate)
library(visualizeR); library(sp);library(rgdal);library(loadeR.2nc); library(RNetCDF); library(sp)
library(ncdf4); library(raster);library(convertR);library(drought4R);library(imputeTS)
library(lubridate);library(mgcv); library(rowr)

#···········Opening Observation
load("/home/ry4902/Documents/EWEMBI_Download/Interpolated_SAU-SQD/Interpolated_1982-2009.RData")
ewembi <- data.interp
data.interp <-NULL
#Cloud cover
ewembi$cc <- rad2cc(rsds = ewembi$rsds, rlds = ewembi$rlds)

#Dew point
ewembi$tdew <- ewembi$hurs
H_dew <- log(ewembi$hurs$Data/100) + 
  (17.62*ewembi$tas$Data)/(243.12+ewembi$tas$Data)
ewembi$tdew$Data <- 243.12*H_dew/(17.62-H_dew) # // this is the dew point in Celsius;

#Hardy B., Thunder Scientific Corporation, Albuquerque, NM, USA
#The proceedings of the Third international Symposium on Humidity & Moisture, Teddington, London, England,
#April 1998. 

#···········Opening seasonal forecast data
load("/home/ry4902/Documents/System4_Download/Interpolated_SAU-SQD/Interpolated_1982-2009.RData")
seasonal <- data.interp
data.interp <-NULL
#Cloud cover
seasonal$cc <- rad2cc(rsds = seasonal$rsds, rlds = seasonal$rlds)

#Dew point
seasonal$tdew <- seasonal$hurs
H_dew <- log(seasonal$hurs$Data/100) + 
  (17.62*seasonal$tas$Data)/(243.12+seasonal$tas$Data)
seasonal$tdew$Data <- 243.12*H_dew/(17.62-H_dew) # // this is the dew point in Celsius;
#Hardy B., Thunder Scientific Corporation, Albuquerque, NM, USA
#The proceedings of the Third international Symposium on Humidity & Moisture, Teddington, London, England,
#April 1998. 

num_season <- 0; list_seasons <- list(c(9:11), c(3:5), c(6:8), c(12,1,2))
for (season in c("autumn", "spring", "summer", "winter")){
  num_season <- num_season + 1

  for (var in c("ps", "uas", "vas", "tas", "pr", "rsds", "cc", "tdew")){
    #pressure
    hindcast <- seasonal[[var]]
    hindcast <- subsetGrid(hindcast, season = list_seasons[[num_season]], years = c(1983:2009))
    hindcast$Data <- array(data = NA, dim = c(15, dim(hindcast$Data)[2],1,1))
    hindcast$Data[,,1,1] <- subsetGrid(seasonal[[var]], season = list_seasons[[num_season]], years = c(1983:2009))$Data
    attr(hindcast$Data, "dimensions") <- c("member", "time", "lat", "lon")
    observation <- ewembi[[var]]
    if (season=="winter"){
      obs_dic <- subsetGrid(observation, season = 12, years = c(1982:2008))
      obs_all <- subsetGrid(observation, season = c(1:2), years = c(1983:2009))
      observation <- bindGrid(obs_all, obs_dic, dimension = c("time"))
      
      observation$Data <- array(data = NA, dim = c(dim(observation$Data)[3],1,1))
      set_dic <- subsetGrid(ewembi[[var]], season = 12, years = c(1982:2008))
      set_all <- subsetGrid(ewembi[[var]], season = c(1:2), years = c(1983:2009))
      set_set <- bindGrid(set_all, set_dic, dimension = c("time"))
      observation$Data[,1,1] <- set_set$Data[1,1,,,]
      
    }else{
      observation <- subsetGrid(observation, season = list_seasons[[num_season]], years = c(1983:2009))
      observation$Data <- array(data = NA, dim = c(dim(observation$Data),1,1))
      observation$Data[,1,1] <- subsetGrid(ewembi[[var]], season = list_seasons[[num_season]], years = c(1983:2009))$Data
    }
    attr(observation$Data, "dimensions") <- c("time", "lat", "lon")
    if (var=="ps"){
      observation <- gridArithmetics(observation, 100, operator = "/")
      attr(observation$Data, "dimensions") <- c("time", "lat", "lon")
    }
    pdf(paste("/home/ry4902/Documents/System4_Download/Interpolated_SAU-SQD/TercilePlots/",var,"_",season,".pdf", sep=""))
    tercilePlot(hindcast, observation)
    dev.off()
    
  }
}

