library(transformeR);library(loadeR.ECOMS);library(loadeR);library(downscaleR);library(lubridate)
library(visualizeR); library(sp);library(rgdal);library(loadeR.2nc); library(RNetCDF); library(sp)
library(ncdf4); library(raster)

# Opening Model data
load("/home/ry4902/Documents/System4_Download/BiasCorrectedWithEWEMBI_TerRiver/winter.RData")
winter <- data.bc.cross
load("/home/ry4902/Documents/System4_Download/BiasCorrectedWithEWEMBI_TerRiver/spring.RData")
spring <- data.bc.cross
load("/home/ry4902/Documents/System4_Download/BiasCorrectedWithEWEMBI_TerRiver/summer.RData")
summer <- data.bc.cross
load("/home/ry4902/Documents/System4_Download/BiasCorrectedWithEWEMBI_TerRiver/autumn.RData")
autumn <- data.bc.cross
model_data <- lapply(1:length(winter), function(x) bindGrid(winter[[x]], spring[[x]], 
                                                         summer[[x]], autumn[[x]],
                                                         dimension = c("time")))
names(model_data) <- c("pr","tas","pet")

# Opening observation data
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

morpho_res <- raster(xmn=410000, xmx=410000+5*10000, ymn=4620000, ymx=4620000+8*10000, resolution=c(10000,10000))
lat_utm <- seq(morpho_res@extent@ymin, morpho_res@extent@ymax, 10000); lat_utm_mean <-c()
for (ylat in 1:(length(lat_utm)-1) ){lat_utm_mean <-  c(lat_utm_mean, mean(c(lat_utm[ylat+1], lat_utm[ylat])))}
lon_utm <- seq(morpho_res@extent@xmin, morpho_res@extent@xmax, 1e+04); lon_utm_mean <-c()
for (ylat in 1:(length(lon_utm)-1) ){lon_utm_mean <-  c(lon_utm_mean, mean(c(lon_utm[ylat+1], lon_utm[ylat])))}
source("/home/ry4902/Documents/Inputs_nhm-5.9/MeteorologicalVar/grid2ncUTM.R")

database <- "System4"

setwd(paste("/home/ry4902/Documents/mhm-5.9_membersInitializedEWEMBI/", database, sep=""))

#Opening latitude and longitud corrdinates
load("/home/ry4902/Documents/EWEMBI_Download/coord_save.rda")
lon_add <- coord_save[,1]
lat_add <- coord_save[,2]

total_simulated <- list(); total_initializers <- list()
for (member_number in 1:15){
  initializers <- c(); simulated <- c()
  for (year in c(1983:2010)){
    if (year==1983 | year==1984 | year==1985 | year==1986){spinup <- 1331}else{spinup <- 2455}
    #spinup <- 1107 #365*(year-1980)1331 
    porsiaca <- 100
    for (season in list(c(12,1,2), c(3:5), c(6:8), c(9:11))){
      for (variable in c("tas", "pet", "pr")){
        
        if(variable=="tas"){variable_save <- "tavg"}
        if(variable=="pet"){variable_save <- "pet"}
        if(variable=="pr"){variable_save <- "pre"}
        
        var.new <- model_data[[variable]]
        var.new$Data <- var.new$Data[1,,,,]
        attr(var.new$Data, "dimensions") <- c("member", "time", "lat", "lon")
        var.new_obs <- data_obs[[variable]]
      
        #Setting specific year and season
        var.new_exact <- subsetGrid(var.new, years = year, season = season, members = member_number)
        target_date <- var.new_exact$Dates$start[1]
        
        position_date <- match(target_date, var.new_obs$Dates$start)
        
        obs_selected <- var.new_obs
        obs_selected$Data <- obs_selected$Data[(position_date-spinup-porsiaca):(position_date-1),,]
        obs_selected$Dates$start <- obs_selected$Dates$start[(position_date-spinup-porsiaca):(position_date-1)]
        obs_selected$Dates$end <- obs_selected$Dates$end[(position_date-spinup-porsiaca):(position_date-1)]
        attr(obs_selected$Data, "dimensions") <- c("time", "lat", "lon")
        
        total_var <- bindGrid(obs_selected, var.new_exact, dimension = c("time"))
        data_array <- total_var$Data[1,1,,,]
        data_array_save <- array(data = NA, dim = c(length(total_var$Dates$start), 8, 5))
        
        data_array_save[,4:8,1:5] <- data_array[,3,2]
        data_array_save[,1:3,1:5] <- data_array[,2,2]
        data_array_save[,7,1] <- data_array[,3,1]
        attr(data_array_save, "dimensions") <- c("time", "lat", "lon")
        #total_var$Data <- data_array_save
        
        total_var_ok <- loadeR::loadGridData("/home/ry4902/Documents/Inputs_nhm-5.9/MeteorologicalVar/FromCDO/tavg_ready.nc",  var="tavg")
        total_var_ok$Dates$start <- total_var$Dates$start
        total_var_ok$Dates$end <- total_var$Dates$end
        total_var_ok$xyCoords$x <- unique(coord_save[,1])
        total_var_ok$xyCoords$y <- unique(coord_save[,2])
        attr(total_var_ok$xyCoords, "projection") <- "+proj=utm +zone=31 +datum=WGS84 +units=m +no_defs"
        total_var_ok$Variable$varName <- variable_save 
        attr(total_var_ok$Variable, "longname") <- variable_save 
        attr(total_var_ok$Variable, "description") <- variable_save 
        total_var_ok$Data <- data_array_save
        
        grid2ncUTM(total_var_ok, paste(getwd(), "/input/meteo/", variable_save,"/", variable_save, ".nc", sep=""),
                   lon = lon_utm_mean, lat = lat_utm_mean)
      }
      #Changins mhm.nml file according to start and end dates
      mhm_file  <- readLines(paste(getwd(),"/mhm.nml", sep=""))
      mhm_file[488] <- paste("warming_Days(1) =",  spinup) #paste("warming_Days(1) =",  (spinup-50))
      mhm_file[491] <- paste("eval_Per(1)%yStart =",  year(as.Date(target_date)-30))
      mhm_file[494] <- paste("eval_Per(1)%mStart =",  month(as.Date(target_date)-30))
      mhm_file[497] <- paste("eval_Per(1)%dStart =",  day(as.Date(target_date)-30))
      end_day <- as.Date(total_var$Dates$start[length(total_var$Dates$start)])
      mhm_file[500] <- paste("eval_Per(1)%yEnd =",  year(end_day))
      mhm_file[503] <- paste("eval_Per(1)%mEnd =",  month(end_day))
      mhm_file[506] <- paste("eval_Per(1)%dEnd =",  day(end_day))
      writeLines(mhm_file, con=paste(getwd(),"/mhm.nml", sep=""))
      
      #Running mHM model
      system("./mhm")
      
      #Saving discharge results from mHM model                                                                                 sep="", stringsAsFactors = F)
      daily_discharge <- read.csv(paste(getwd(), "/output_b1/daily_discharge.out", sep=""),
                                  sep="", stringsAsFactors = F)
      initializers <- rbind(initializers, daily_discharge[1:30,])
      simulated <- rbind(simulated, daily_discharge[31:nrow(daily_discharge),])
    }
  }
  total_simulated[[paste("member", member_number, sep = "_")]] <- simulated
  total_initializers[[paste("member", member_number, sep = "_")]] <- initializers
}

save(total_simulated, file =paste(getwd(), "/TotalOutputs/simulated.RData", sep=""))
save(total_initializers, file = paste(getwd(), "/TotalOutputs/initializers.RData", sep=""))