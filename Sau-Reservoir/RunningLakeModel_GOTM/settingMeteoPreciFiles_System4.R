########## SETTING FILES TO RUN GOTM AND SAVE SELECTED VARIABLES -----------------------

library(transformeR);library(loadeR.ECOMS);library(loadeR);library(downscaleR);library(lubridate)
library(visualizeR); library(sp);library(rgdal);library(loadeR.2nc); library(RNetCDF); library(sp)
library(ncdf4); library(raster);library(convertR);library(drought4R);library(imputeTS)
library(lubridate);library(mgcv); library(rowr)

#···········Setting Observation
setwd("/home/ry4902/Documents/GOTM/SAU/forcedbySystem4_doubleDepth")
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

# Give format to dates
yymmdd <- as.Date(data.interp$uas$Dates$start)
hhmmss <- format(as.POSIXlt(data.interp$uas$Dates$start), format = "%H:%M:%S") 

data_matrix <- lapply(data.interp, function(x) x$Data)
# data.frame creation
df <- data.frame(c(list("dates1" = yymmdd, "dates2" = hhmmss)), data_matrix)
df$wtemp <- 0.799*df$tas+5.120

#··········Setting temperature and level initial values
#Setting temperatures t_1 and t_2 for up and botton layers in GOTM
#temp <- read.csv( "/home/ry4902/Documents/GOTM/SAU/forcedbyEWEMBI/ToPrepare/temp.obs")
#colnames(temp) <- c("date", "hour", "depth", "temp")
#temp$depth <- abs(temp$depth)

#Bottom layer (t_1)
#min_temp <- merge(aggregate(depth ~ date, data=temp, FUN="min"), temp)
#min_temp$doy <- yday(as.Date(min_temp$date, format="%Y-%m-%d"))
#gam_temp_min <- gam(temp ~ s(doy, bs="cc"), data=min_temp) #cyclic cubic smooth
#temp_gam_min <- predict.gam(gam_temp_min, newdata=data.frame(doy=c(1:365)))

#Up layer (t_2)
#max_temp <- merge(aggregate(depth ~ date, data=temp, FUN="max"), temp)
#max_temp$doy <- yday(as.Date(max_temp$date, format="%Y-%m-%d"))
#gam_temp_max <- gam(temp ~ s(doy, bs="cc"), data=max_temp) #cyclic cubic smooth
#temp_gam_max <- predict.gam(gam_temp_max, newdata=data.frame(doy=c(1:365)))

#Setting temperatures t_1 and t_2 for up and botton layers in GOTM: using EWEMBI simulation
data_EWEMBI <- c()
for (depth in c(1, 50)){
  my.data <-open.nc("/home/ry4902/Documents/GOTM/SAU/forcedbyEWEMBI/output.nc")
  my.object <- var.get.nc(my.data, "temp") #[220, 3631]
  if (depth==1){
    data_EWEMBI <- my.object[round(nrow(my.object)-(depth*220/60.54)),]
  }else{
    data_EWEMBI <- cbind.fill(data_EWEMBI, my.object[round(nrow(my.object)-(depth*220/60.54)),], fill = -9999)
  }
}
level <- var.get.nc(my.data, "zeta") #[220, 3631]
data_EWEMBI <- cbind.fill(data_EWEMBI, level, fill = -9999)
data_EWEMBI <- data.frame(data_EWEMBI, date=seq(as.Date('1980-01-02'), as.Date('2013-12-31'), by=1))
colnames(data_EWEMBI) <- c("temp1","temp50","level", "dates1")

#Setting level values
#levels <- read.csv("/home/ry4902/Documents/GOTM/SAU/forcedbyEWEMBI/ToPrepare/LevelAnalysis.csv")

#Inflow data EWEMBI
daily_discharge <- read.csv("~/Documents/mhm-5.9_obs7/ForcedByEWEMBI/Third_Ter/output_b1/daily_discharge.out", sep="")
df$inflow <- c(rep(-9999, (which(df$dates1==as.Date(paste(daily_discharge$Year[1], 
                                                          daily_discharge$Mon[1], 
                                                          daily_discharge$Day[1], sep="-")))-1)),
               daily_discharge$Qsim_0000000113)

#Inflow data model
load("/home/ry4902/Documents/mhm-5.9_membersInitializedEWEMBI_LeadMonthEWEMBI/System4/TotalOutputs/simulated.RData")

#··········Setting Seasonal Forecasting Data
data_total_season <- list(); num_season <- 0
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
  
  # Give format to dates
  yymmdd <- as.Date(data.bc.cross$uas$Dates$start)
  hhmmss <- format(as.POSIXlt(data.bc.cross$uas$Dates$start), format = "%H:%M:%S") 
  
  data_matrix <- lapply(data.bc.cross, function(x) x$Data)
  data_matrix$cc <- data_matrix$cc[,,1,1] 
  
  data_total_member <- list()
  for (member_number in 1:15){
    
    data_matrix_member <- lapply(data_matrix, function(x) x[member_number,])
    # data.frame creation
    df_model <- data.frame(c(list("dates1" = yymmdd, "dates2" = hhmmss)), data_matrix_member)
    df_model$wtemp <- 0.799*df_model$tas+5.120
    
    #---------Setting streamflow data 
    inflow_data <- total_simulated[[member_number]]
    inflow_data$date1 <- as.Date(paste(inflow_data$Year, inflow_data$Mon, inflow_data$Day, sep="-"))
    
    df_model <- merge(df_model, data.frame(inflow=inflow_data$Qsim_0000000113, dates1=inflow_data$date1), by=c("dates1"))
    
    data_total_year <- c()
    for (year in c(1984:2009)){
      if (season=="autumn"){
        ini_day <- "01"; ini_month <- "09"; end_day <- "30"; end_month <- "11"
        ini_date <- as.Date(paste(year, ini_month, ini_day, sep="-"))-30
        end_date <- as.Date(paste(year, end_month, end_day, sep="-"))
      }
      if (season=="winter"){
        ini_day <- "01"; ini_month <- "12"; end_day <- "28"; end_month <- "02"
        ini_date <- as.Date(paste(year-1, ini_month, ini_day, sep="-"))-30
        end_date <- as.Date(paste(year, end_month, end_day, sep="-"))
      }
      if (season=="spring"){
        ini_day <- "01"; ini_month <- "03"; end_day <- "31"; end_month <- "05"
        ini_date <- as.Date(paste(year, ini_month, ini_day, sep="-"))-30
        end_date <- as.Date(paste(year, end_month, end_day, sep="-"))
      }
      if (season=="summer"){
        ini_day <- "01"; ini_month <- "06"; end_day <- "31"; end_month <- "08"
        ini_date <- as.Date(paste(year, ini_month, ini_day, sep="-"))-30
        end_date <- as.Date(paste(year, end_month, end_day, sep="-"))
      }
      
      observation_total <- df[which(df$dates1==ini_date):which(df$dates1==(ini_date+29)),]
      observation_total$ps <- observation_total$ps/100
        #cbind(df[which(df$dates1==ini_date):which(df$dates1==(ini_date+30)),1:2], 
        #                          na.ma(c((df[which(df$dates1==ini_date):which(df$dates1==(ini_date+30)),8])/(1000*24*60*60)))) #from mm/d to m/s
      model_total <- df_model[which(df_model$dates1==(ini_date+31)):which(df_model$dates1==end_date),]
        #cbind(df_model[which(df_model$dates1==(ini_date+31)):which(df_model$dates1==end_date),1:2], 
         #                   na.ma(c((df_model[which(df_model$dates1==(ini_date+31)):which(df_model$dates1==end_date),8])/(1000*24*60*60)))) #from mm/d to m/s
      
      data_total <- rbind(observation_total, model_total)
      
      #Saving precipitation file
      precip <- cbind(data_total[,1:2], na.ma(c((data_total[,8])/(1000*24*60*60)))) #from mm/d to m/s
      write.table(precip, paste(getwd(), "/precipitation.dat", sep=""),
                  sep = "\t", row.names = FALSE, col.names = FALSE, quote = FALSE)
      #Saving meteofile:dates, hours, E_Wind, N_Wind, pressure in hPa and the rest the variables
      meteo <- cbind(data_total[,1:2], round((data_total[,3:5]), 2), 
                     round((data_total[,6]), 2), round(data_total[,14], 2), round(data_total[,13], 2))
      write.table(meteo, paste(getwd(), "/meteo_file.dat", sep=""),
                  sep = "\t", row.names = FALSE, col.names = FALSE, quote = FALSE)
      #Saving swr file
      swr <- cbind(data_total[,1:2], round(data_total$rsds, 2))
      write.table(swr, paste(getwd(), "/swr.txt", sep=""),
                  sep = "\t", row.names = FALSE, col.names = FALSE, quote = FALSE)
      #Saving inflow file
      inflow_save <- cbind(data_total[,1:2], round(data_total$inflow, 2), round(data_total$wtemp, 2))
      write.table(inflow_save, paste(getwd(), "/inflow.dat", sep=""),
                  sep = "\t", row.names = FALSE, col.names = FALSE, quote = FALSE)
      
      #Changing obs.nml and gotmrun.nml files according to start and end dates
      #File to change: gotmtun.nml->lines 78 and 79
      gotmrun_file  <- readLines(paste(getwd(),"/gotmrun.nml", sep=""))
      gotmrun_file[78] <- paste("   start = '",  ini_date, " 00:00:00',", sep="") 
      gotmrun_file[79] <- paste("   stop = '",  end_date, " 00:00:00',", sep="") 
      writeLines(gotmrun_file, con=paste(getwd(),"/gotmrun.nml", sep=""))
      #File to change: obs.nml->lines 140(t_1), 142(t_2), 381(zeta_0)
      obs_file  <- readLines(paste(getwd(),"/obs.nml", sep=""))
      #Setting using EWEMBI simulation
      obs_file[140] <- paste("   t_1 = ",  round(data_EWEMBI$temp1[which(as.Date(data_EWEMBI$dates1)==ini_date)],2), ",", sep="")
      obs_file[142] <- paste("   t_2 = ",  round(data_EWEMBI$temp50[which(as.Date(data_EWEMBI$dates1)==ini_date)],2), ",", sep="")
      obs_file[381] <- paste("   zeta_0 = ",  round(data_EWEMBI$level[which(as.Date(data_EWEMBI$dates1)==ini_date)],2), ",", sep="")
      #Setting using observation
      #obs_file[140] <- paste("   t_1 = ",  round(temp_gam_min[yday(ini_date)], 2), ",", sep="")
      #obs_file[142] <- paste("   t_2 = ",  round(temp_gam_max[yday(ini_date)], 2), ",", sep="")
      #obs_file[381] <- paste("   zeta_0 = ",  -levels$depth[which(as.Date(levels$date)==ini_date)], ",", sep="") 
      writeLines(obs_file, con=paste(getwd(),"/obs.nml", sep=""))
      #File to change: output.yaml -> line 5
      outputyaml_file <- readLines(paste(getwd(),"/output.yaml", sep=""))
      outputyaml_file[5] <- paste("  time_start: ",  ini_date, " 00:00:00", sep="") 
      writeLines(outputyaml_file, con=paste(getwd(),"/output.yaml", sep=""))
      
      #Running GOTM model
      system("./gotm")
      
      names_data <- colnames(data_total)
      temperature <- c() 
      #c("abiotic_water_sDDOMW", "abiotic_water_sDIMW", "abiotic_water_sDPOMW")
      #c("phytoplankton_water_oChlaBlue", "phytoplankton_water_oChlaDiat", "phytoplankton_water_oChlaGren")
      #abiotic_water_sO2W
      for (depth in c(1,5,10, 15, 20,30,40,50)){ #
        my.data <-open.nc(paste(getwd(), "/output.nc", sep=""))
        my.object <- var.get.nc(my.data, "temp") #[220, 3631]
        temperature <- my.object[round(nrow(my.object)-(depth*220/120)),]
        data_total <- cbind.fill(data_total, temperature, fill = -9999)
        names_data <- c(names_data, paste("temp", depth, sep=""))
      }
      level <- var.get.nc(my.data, "zeta") #[220, 3631]
      data_total <- cbind.fill(data_total, level, fill = -9999)
      names_data <- c(names_data, "level")
      colnames(data_total) <-  names_data
      
      #Exporting water quality variables: 
      #MO = sDDOMW+sDIMW+sDPOMW
      #for (MO in c("abiotic_water_sDDOMW", "abiotic_water_sDIMW", "abiotic_water_sDPOMW")){
      #  variable_MO <- var.get.nc(my.data, MO) #[220, 3631]
      #  data_total <- cbind.fill(data_total, variable_MO, fill = -9999)
      #  names_data <- c(names_data, MO)
      #  colnames(data_total) <-  names_data
      #}
      #clorofila 
      
      data_total_year <- rbind(data_total_year, data_total) 
    }
    data_total_member[[member_number]] <- data_total_year
  }
  data_total_season[[num_season]] <- data_total_member
  save.image(paste(getwd(),"/Output/season", num_season,".RData", sep=""))
}
names(data_total_season) <- c("autumn", "spring", "summer", "winter")
save(data_total_season, file=paste(getwd(),"/Output/data_total_season.RData", sep=""))
