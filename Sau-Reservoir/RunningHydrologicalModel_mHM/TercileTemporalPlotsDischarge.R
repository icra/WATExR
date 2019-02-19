library(transformeR);library(loadeR.ECOMS);library(loadeR);library(downscaleR);library(lubridate)
library(visualizeR); library(sp);library(rgdal);library(loadeR.2nc); library(RNetCDF); library(sp)
library(ncdf4); library(raster)

low_date <- as.Date("1982-12-01") #Fecha limitada por las variables medidas atmosféricas
high_date <- as.Date("2010-11-30")


# Opening Model data
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
model_data[[1]]$Data <- model_data[[1]]$Data[1,,,,]
model_data <- lapply(1:length(winter), function(x) bindGrid(winter[[x]], spring[[x]], 
                                                            summer[[x]], autumn[[x]],
                                                            dimension = c("time")))
model_data[[1]]$Data <- model_data[[1]]$Data[1,,,,]
attr(model_data[[1]]$Data, "dimensions") <- c("member", "time", "lat", "lon")

var.set <- subsetGrid(model_data[[1]], years = c(1983:2010)) 
load("/home/ry4902/Documents/mhm-5.9_membersInitializedEWEMBI_LeadMonthEWEMBI/System4/TotalOutputs/simulated.RData")
for (m in 1:15){
  var.set$Data[m,,1:4,1:5] <- total_simulated[[m]]$Qsim_0000000113 
}

attr(var.set$Variable, "longname") <- "Discharge"
attr(var.set$Variable, "description") <- "Discharge from mHM model"
  
obs <- subsetGrid(var.set, members = 1)
total_simulated$member_1$Qobs_0000000113[which(total_simulated$member_1$Qobs_0000000113==-9999)] <- NA

obs$Data[,1:4,1:5] <-  total_simulated$member_1$Qobs_0000000113

var.set <- subsetGrid(var.set, years = c(1983:2009)) 
obs <- subsetGrid(obs, years = c(1983:2009)) 
#pdf("/home/ry4902/Documents/mhm-5.9_membersInitialized/System4/TotalOutputs/AllDates.pdf")
#tercilePlot(var.set, obs)
#dev.off()
pdf("/home/ry4902/Documents/mhm-5.9_membersInitializedEWEMBI/System4/TotalOutputs/winter-tercile.pdf")
tercilePlot(subsetGrid(var.set, season = c(12,1,2)), subsetGrid(obs, season = c(12,1,2)))
dev.off()
pdf("/home/ry4902/Documents/mhm-5.9_membersInitializedEWEMBI/System4/TotalOutputs/spring-tercile.pdf")
tercilePlot(subsetGrid(var.set, season = c(3:5)), subsetGrid(obs, season = c(3:5)))
dev.off()
pdf("/home/ry4902/Documents/mhm-5.9_membersInitializedEWEMBI/System4/TotalOutputs/summer-tercile.pdf")
tercilePlot(subsetGrid(var.set, season = c(6:8)), subsetGrid(obs, season = c(6:8)))
dev.off()
pdf("/home/ry4902/Documents/mhm-5.9_membersInitializedEWEMBI/System4/TotalOutputs/autumn-tercile.pdf")
tercilePlot(subsetGrid(var.set, season = c(9:11)), subsetGrid(obs, season = c(9:11)))
dev.off()

Sys4 <- var.set
Obs <- obs
pdf("/home/ry4902/Documents/mhm-5.9_membersInitializedEWEMBI_LeadMonthEWEMBI/System4/TotalOutputs/temporalPlot.pdf",
    width=13)
temporalPlot(Obs, Sys4)
dev.off()
