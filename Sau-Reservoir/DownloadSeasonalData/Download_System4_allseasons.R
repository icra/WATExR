library(transformeR);library(loadeR.ECOMS);library(loadeR);library(downscaleR);library(visualizeR)

lonLim <- c(1.5, 3.5) # Or just a point, in this case the interpolation using interpGrid function is not required (but will work even if applying interpGrid)
latLim <- c(41.3, 42.7)
training_years <- c(1982:2010)
dataset <- "System4_seasonal_15"
variables <- c("tas", "tasmax", "tasmin", "pr", "ps", "uas", "vas", "hurs", "rsds", "rlds")
loginUDG("WATExR", "1234567890")
season <- c(12,1,2)
winter <- lapply(variables, function(x) loadECOMS(dataset = dataset, var = x,  #By default it donwloads all members 
                                                  years = training_years, lonLim = lonLim, latLim = latLim, 
                                                  season = season, leadMonth = 1, time= "DD", aggr.d = "mean"))
names(winter) <- variables
save.image("/home/ry4902/Documents/System4_Download/winter.RData")

loginUDG("WATExR", "1234567890")
season <- c(3:5)
spring <- lapply(variables, function(x) loadECOMS(dataset = dataset, var = x, 
                                                  years = training_years, lonLim = lonLim, latLim = latLim, 
                                                  season = season, leadMonth = 1, time= "DD", aggr.d = "mean"))
names(spring) <- variables
save.image("/home/ry4902/Documents/System4_Download/spring.RData")

loginUDG("WATExR", "1234567890")
season <- c(6:8)
summer <- lapply(variables, function(x) loadECOMS(dataset = dataset, var = x, 
                                                  years = training_years, lonLim = lonLim, latLim = latLim, 
                                                  season = season, leadMonth = 1, time= "DD", aggr.d = "mean"))
names(summer) <- variables
save.image("/home/ry4902/Documents/System4_Download/summer.RData")

loginUDG("WATExR", "1234567890")
season <- c(9:11)
autumn <- lapply(variables, function(x) loadECOMS(dataset = dataset, var = x,
                                                  years = training_years, lonLim = lonLim, latLim = latLim, 
                                                  season = season, leadMonth = 1, time= "DD", aggr.d = "mean"))
names(autumn) <- variables
save.image("/home/ry4902/Documents/System4_Download/autumn.RData")
                 
system4_allseasons <- lapply(1:length(winter), function(x) bindGrid(winter[[x]], spring[[x]], 
                                                              summer[[x]], autumn[[x]],
                                                              dimension = c("time")))
                             
save(system4_allseasons, file="/home/ry4902/Documents/System4_Download/System4_AllVariableAndYears.RData")                                                       
