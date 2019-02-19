library(transformeR);library(loadeR.ECOMS);library(loadeR);library(downscaleR);library(lubridate)
library(visualizeR); library(sp);library(rgdal);library(loadeR.2nc); library(RNetCDF); library(sp)
library(ncdf4); library(raster); library(rowr)

#Opening observed data
temperature <- c()
for (depth in c(1,5,10, 15, 20,30,40,50)){
  my.data <-open.nc("/home/ry4902/Documents/GOTM/SAU/forcedbyEWEMBI/output.nc")
  my.object <- var.get.nc(my.data, "temp") #[220, 3631]
  if (depth==1){
    temperature <- my.object[round(nrow(my.object)-(depth*220/60.54)),]
  }else{
    temperature <- cbind.fill(temperature, my.object[round(nrow(my.object)-(depth*220/60.54)),], fill = -9999)
  }
  #data_total <- cbind.fill(data_total, temperature, fill = -9999)
  #names_data <- c(names_data, paste("temp", depth, sep=""))
}
level <- var.get.nc(my.data, "zeta") #[220, 3631]
temperature <- cbind.fill(temperature, level, fill = -9999)
temperature <- data.frame(temperature, date=seq(as.Date('1980-01-02'), as.Date('2013-12-31'), by=1))
colnames(temperature) <- c("temp1","temp5","temp10","temp15","temp20","temp30","temp40","temp50","level", "dates1")

# Opening Model data
load("/home/ry4902/Documents/GOTM/SAU/forcedbySystem4_doubleDepth/Output/data_total_season.RData")
#names(data_total_season) <- c("autumn", "spring", "summer", "winter")
winter <- data_total_season$winter
spring <- data_total_season$spring
summer <- data_total_season$summer
autumn <- data_total_season$autumn

# Opening netcdf data
load("/home/ry4902/Documents/System4_Download/BiasCorrectedWithEWEMBI_TerRiver/winter.RData")
winter1 <- data.bc.cross
load("/home/ry4902/Documents/System4_Download/BiasCorrectedWithEWEMBI_TerRiver/spring.RData")
spring1 <- data.bc.cross
load("/home/ry4902/Documents/System4_Download/BiasCorrectedWithEWEMBI_TerRiver/summer.RData")
summer1 <- data.bc.cross
load("/home/ry4902/Documents/System4_Download/BiasCorrectedWithEWEMBI_TerRiver/autumn.RData")
autumn1 <- data.bc.cross
model_data <- lapply(1:length(winter1), function(x) bindGrid(winter1[[x]], spring1[[x]], 
                                                            summer1[[x]], autumn1[[x]],
                                                            dimension = c("time")))
model_data[[1]]$Data <- model_data[[1]]$Data[1,,,,]
attr(model_data[[1]]$Data, "dimensions") <- c("member", "time", "lat", "lon")
var.set <- subsetGrid(model_data[[1]], years = c(1984:2009)) 

obs.set <- var.set

obs.set$Data <- obs.set$Data[1,,,]
attr(obs.set$Data, "dimensions") <- c("time", "lat", "lon")
dates_obs_set <- data.frame(dates1=as.Date(obs.set$Dates$start))
merge_obs<-merge(dates_obs_set, temperature, by="dates1")
obs.set$InitializationDates<-NULL
obs.set$Members<-NULL
for (temp in c(2,4,6,7,8,9,10)){ #columns in merge dataframe 2y17(1m), 4y19(10m), 6y21(20m), 7y22(30m), 8y23(30m), 9y24(50m)
  obs.set$Data[,1:4,1:5] <- merge_obs[,temp]
  #pdf(paste("/home/ry4902/Documents/GOTM/SAU/forcedbySystem4/Output/temp", temp, ".pdf", sep=""), width = 15)
  for (member_number in c(1:15)){
    winter_ok <- winter[[member_number]][which(month(as.Date(winter[[member_number]]$dates1)) %in% c(12,1,2)),]
    spring_ok <- spring[[member_number]][which(month(as.Date(spring[[member_number]]$dates1)) %in% c(3:5)),]
    summer_ok <- summer[[member_number]][which(month(as.Date(summer[[member_number]]$dates1)) %in% c(6:8)),]
    autumn_ok <- autumn[[member_number]][which(month(as.Date(autumn[[member_number]]$dates1)) %in% c(9:11)),]
    
    all_seasons <- rbind(winter_ok, spring_ok, summer_ok, autumn_ok, stringAsFactors=F)
    all_seasons_ok <- all_seasons[order(as.Date(all_seasons$dates1, format="%Y-%m-%d")),]
    all_seasons_ok$dates1<-as.Date(all_seasons_ok$dates1)
    
    dates_var_set <- data.frame(dates1=as.Date(var.set$Dates$start))
    merge_seasons<-merge(dates_var_set, all_seasons_ok, by="dates1", all=TRUE)
    var.set$Data[member_number,,1:4,1:5] <- merge_seasons[,(temp+15)][1:9497]
  }
  attr(obs.set$Variable, "longname") <- paste("temperature profile", names(merge_obs)[temp], "m")
  attr(var.set$Variable, "longname") <- paste("temperature profile", names(merge_obs)[temp], "m")
  if (temp==10){
    pdf(paste("/home/ry4902/Documents/GOTM/SAU/forcedbySystem4_doubleDepth/Output/temporalPlot", names(merge_obs)[temp], ".pdf",sep=""),
        width = 15)
    print(temporalPlot(obs.set, var.set, xyplot.custom =list(ylim=c(-50,10))))
    dev.off()
  }else{
    pdf(paste("/home/ry4902/Documents/GOTM/SAU/forcedbySystem4_doubleDepth/Output/winter", names(merge_obs)[temp], ".pdf",sep=""))
    tercilePlot(subsetGrid(var.set, season=c(12,1,2)), subsetGrid(obs.set, season = c(12,1,2)))
    dev.off()
    pdf(paste("/home/ry4902/Documents/GOTM/SAU/forcedbySystem4_doubleDepth/Output/spring", names(merge_obs)[temp], ".pdf",sep=""))
    tercilePlot(subsetGrid(var.set, season=c(3:5)), subsetGrid(obs.set, season = c(3:5)))
    dev.off()
    pdf(paste("/home/ry4902/Documents/GOTM/SAU/forcedbySystem4_doubleDepth/Output/summer", names(merge_obs)[temp], ".pdf",sep=""))
    tercilePlot(subsetGrid(var.set, season=c(6:8)), subsetGrid(obs.set, season = c(6:8)))
    dev.off()
    pdf(paste("/home/ry4902/Documents/GOTM/SAU/forcedbySystem4_doubleDepth/Output/autumn", names(merge_obs)[temp], ".pdf",sep=""))
    tercilePlot(subsetGrid(var.set, season=c(9:11)), subsetGrid(obs.set, season = c(9:11)))
    dev.off()
    
    pdf(paste("/home/ry4902/Documents/GOTM/SAU/forcedbySystem4_doubleDepth/Output/temporalPlot", names(merge_obs)[temp], ".pdf",sep=""),
        width = 15)
    print(temporalPlot(obs.set, var.set, xyplot.custom =list(ylim=c(0,30))))
    dev.off()
  }
}