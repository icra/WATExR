library(transformeR);library(loadeR.ECOMS);library(loadeR);library(downscaleR);library(lubridate)
library(visualizeR); library(sp);library(rgdal);library(loadeR.2nc); library(RNetCDF); library(sp)

season_num <- c(6:8)
season_name <- "summer"

# Setting observation data
load("/home/ry4902/Documents/EWEMBI_Download/all_data.RData")
#Hargreaves-Samani PET calculation
tas_min <- data.prelim$tasmin
tas_max <- data.prelim$tasmax
tas <- data.prelim$tas
julian_dates <- yday(as.Date(tas_max$Dates$start))
# relative distance between sun and earth
dr <- 1 + 0.033 * (cos(((2*pi*julian_dates) / 365.25)))
# solar inclination
delta <- 0.4093 * sin( 2*pi*julian_dates/365.25 - 1.39)
c <- 0; pet <- tas_max
for (latitude in tas_max$xyCoords$y){
  c <- c+1
  lat <- abs(latitude)*pi/180
  # sunset hour angle [degree]
  ws <- acos(ramify::clip(-tan(lat) * tan(delta), -1, 1))
  # extraterrestrial radiation (DUFFIE and BECKMAN, 1980)
  ra <- 15.3351 * dr * (ws * sin(lat) * sin(delta) + cos(lat) * cos(delta) * sin(ws))
  #Finally PET H-S
  pet$Data[,c,] = 0.0023 * ra * (tas$Data[,c,] + 17.8) * sqrt(tas_max$Data[,c,] - tas_min$Data[,c,])
}
data.prelim$pet <- pet
data_obs <- list(pr=data.prelim$pr, tas=data.prelim$tas, pet=pet)

# Setting model data
load("/home/ry4902/Documents/System4_Download/System4_AllVariableAndYears.RData")
names(system4_allseasons) <- c("tas", "tasmax", "tasmin", "pr", "ps", "uas", "vas", "hurs", "rsds", "rlds")

data.prelim_model <- system4_allseasons["tas","tasmax","tasmin","pr"]
data.prelim_model$tas$Data <- data.prelim_model$tas$Data[1,,,,]
data.prelim_model$tasmax$Data <- data.prelim_model$tasmax$Data[1,,,,]
data.prelim_model$tasmin$Data <- data.prelim_model$tasmin$Data[1,,,,]
data.prelim_model$pr$Data <- data.prelim_model$pr$Data[1,,,,]
#Hargreaves-Samani PET calculation
tas_min <- data.prelim_model$tasmin
tas_max <- data.prelim_model$tasmax
tas <- data.prelim_model$tas
julian_dates <- yday(as.Date(tas_max$Dates$start))
# relative distance between sun and earth
dr <- 1 + 0.033 * (cos(((2*pi*julian_dates) / 365.25)))
# solar inclination
delta <- 0.4093 * sin( 2*pi*julian_dates/365.25 - 1.39)
c <- 0; pet <- tas_max
for (latitude in tas_max$xyCoords$y){
  c <- c+1
  lat <- abs(latitude)*pi/180
  # sunset hour angle [degree]
  ws <- acos(ramify::clip(-tan(lat) * tan(delta), -1, 1))
  # extraterrestrial radiation (DUFFIE and BECKMAN, 1980)
  ra <- 15.3351 * dr * (ws * sin(lat) * sin(delta) + cos(lat) * cos(delta) * sin(ws))
  #Finally PET H-S
  pet$Data[,,c,] = 0.0023 * ra * (tas$Data[,,c,] + 17.8) * sqrt(tas_max$Data[,,c,] - tas_min$Data[,,c,])
}
data.prelim_model$pet <- pet

attr(data.prelim_model$pr$Data, "dimensions") <- c("member", "time", "lat", "lon")
attr(data.prelim_model$tas$Data, "dimensions") <- c("member", "time", "lat", "lon")
attr(data.prelim_model$pet$Data, "dimensions") <- c("member", "time", "lat", "lon")
data_model <- list(pr=data.prelim_model$pr, tas=data.prelim_model$tas, pet=data.prelim_model$pet)

#Points from EWEMBI to set as UTM coordinates
#1 = data.prelim$pr$Data[,3,2]
#2 = data.prelim$pr$Data[,2,2]
#3 = data.prelim$pr$Data[,3,1]

years <- c(1983:2009)
season <- season_num

data_obs_sub <- lapply(1:length(data_obs), function(x) subsetGrid(data_obs[[x]], season = season, years = years))
names(data_obs_sub) <- c("pr","tas","pet")
data_model_sub <- lapply(1:length(data_obs), function(x) subsetGrid(data_model[[x]], season = season, years = years))
names(data_model_sub) <- c("pr","tas","pet")

pdf(paste("/home/ry4902/Documents/System4_Download/BiasCorrectedWithEWEMBI_TerRiver/tercilePlots/", season_name,"_tas.pdf", sep=""))
tercilePlot(data_model_sub$tas, data_obs_sub$tas)
dev.off()
pdf(paste("/home/ry4902/Documents/System4_Download/BiasCorrectedWithEWEMBI_TerRiver/tercilePlots/", season_name,"_pr.pdf", sep=""))
tercilePlot(data_model_sub$pr, data_obs_sub$pr)
dev.off()
pdf(paste("/home/ry4902/Documents/System4_Download/BiasCorrectedWithEWEMBI_TerRiver/tercilePlots/", season_name, "_pet.pdf", sep=""))
tercilePlot(data_model_sub$pet, data_obs_sub$pet)
dev.off()

data.bc.cross <- lapply(1:length(data_obs_sub), function(x)  {
  precip <- FALSE
  if (names(data_obs_sub)[x] == "pr") precip <- TRUE
  biasCorrection(y = data_obs_sub[[x]], x = data_model_sub[[x]], 
                 method = "eqm", cross.val = "loo",
                 precipitation = precip,
                 window = c(30,7),
                 wet.threshold = 1)
}) 
names(data.bc.cross) <- c("pr","tas","pet")

data.bc.cross <- lapply(1:length(data.bc.cross), function(x) subsetGrid(data.bc.cross[[x]], season = season, years = years))
names(data.bc.cross) <- c("pr","tas","pet")
pdf(paste("/home/ry4902/Documents/System4_Download/BiasCorrectedWithEWEMBI_TerRiver/tercilePlots/", season_name,"_BC_tas.pdf", sep=""))
tercilePlot(data.bc.cross$tas, data_obs_sub$tas)
dev.off()
pdf(paste("/home/ry4902/Documents/System4_Download/BiasCorrectedWithEWEMBI_TerRiver/tercilePlots/", season_name,"_BC_pr.pdf", sep=""))
tercilePlot(data.bc.cross$pr, data_obs_sub$pr)
dev.off()
pdf(paste("/home/ry4902/Documents/System4_Download/BiasCorrectedWithEWEMBI_TerRiver/tercilePlots/", season_name, "_BC_pet.pdf", sep=""))
tercilePlot(data.bc.cross$pet, data_obs_sub$pet)
dev.off()

save(data.bc.cross, file=paste("/home/ry4902/Documents/System4_Download/BiasCorrectedWithEWEMBI_TerRiver/", season_name,".RData", sep=""))
