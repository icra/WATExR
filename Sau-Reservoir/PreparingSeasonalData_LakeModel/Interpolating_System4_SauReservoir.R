library(transformeR)
library(loadeR.ECOMS)
library(loadeR)
library(visualizeR)
library(convertR)
library(drought4R)
library(downscaleR)

load("/home/ry4902/Documents/System4_Download/System4_AllVariableAndYears.RData")

lake <- list(x = 2.3994, y = 41.9702) # SAU ot SQD

# Bilinear interpolation of the data to the location of the lake
data.interp <- lapply(cfs_total, function(x) interpGrid(x, new.coordinates = lake, 
                                                        method = "bilinear", 
                                                        bilin.method = "akima"))

save(data.interp, file = "/home/ry4902/Documents/System4_Download/Interpolated_SAU-SQD/Interpolated_1982-2009.RData")
