setwd("C:\\Users\\mooret\\OneDrive - Dundalk Institute of Technology\\WateXr\\WATExR\\MtBold\\GOTM")

library(gotmtools)
library(airGR)
library(lubridate)
source('../R_scripts/modelling/functions/create_level.R')
source('../R_scripts/modelling/functions/match_hyps.R')
source('../R_scripts/modelling/functions/init_prof.R') #beta version - will be updated into gotmtools soon
source('../R_scripts/modelling/functions/run_gr4j.R')
source('../R_scripts/modelling/functions/streams_switch.R')

## Set output file
out = 'output.nc'

#Load and format met file
met_file <- 'meteo_temp.dat'
cnams <- c("DateTime","uas", "vas", "ps", "tas", "tasmax", "tasmin", "pr", "rsds", "rlds", "hurs", "cc", "petH")
met <- read.delim('../data/MtBold/CLIMATE/MtBold_DkIT_EWEMBI_observations_member01_day_19790101-20101231/meteo_file.dat', header = T)
# colnames(met) <- cnams

# met$ps <- met$ps *100 #Convert from mbar to Pa
met$pr_m.s.1 <- 1.157e-8*met$pr_mm
colnames(met)[1] <- '!DateTime'
met[,-1] <- signif(met[,-1], digits = 5)
write.table(met, met_file, col.names = T, row.names = F, quote = F, sep = '\t')

## Run catchment models and generate GOTM inputs
# from WateXr\MtBold_Data\Echunga Creek GR4J
#Echunga
ech_catch = 31.9
ech_param = as.vector(unlist(read.csv('../GR4J/Echunga/calib_param.csv')))
ech_outfile = 'ech_inflow.dat'
run_gr4j(time = as.POSIXct(met[,1], tz = 'UTC'), pet = met$petH_mm.day.1, pre = met$pr_mm, warmup_ratio = NULL, param = ech_param, catch_size = ech_catch, out_file = ech_outfile, airt = met$tas_degC, calc_T = TRUE)
plot_inp(ech_outfile, header = T)

#Onkaparinga
onk_catch = 324.87
onk_param = as.vector(unlist(read.csv('../GR4J/Onkaparinga/onka_gr4j_calib_param.csv')))
onk_outfile = 'onk_inflow.dat'
run_gr4j(time = as.POSIXct(met[,1], tz = 'UTC'), pet = met$petH_mm.day.1, pre = met$pr_mm, warmup_ratio = NULL, param = onk_param, catch_size = onk_catch, out_file = onk_outfile, airt = met$tas_degC, calc_T = TRUE)
plot_inp(onk_outfile, header = T)

## Set gotm.yaml met config
######
# Setup gotm.yaml file
yaml = 'gotm.yaml'
#u10
input_yaml(file = yaml, label = 'u10', key = 'file', value = met_file)
input_yaml(file = yaml, label = 'u10', key = 'column', value = 1)
input_yaml(file = yaml, label = 'u10', key = 'scale_factor', value = 1)
#v10
input_yaml(file = yaml, label = 'v10', key = 'file', value = met_file)
input_yaml(file = yaml, label = 'v10', key = 'column', value = 2)
input_yaml(file = yaml, label = 'v10', key = 'scale_factor', value = 1)
#airp
input_yaml(file = yaml, label = 'airp', key = 'file', value = met_file)
input_yaml(file = yaml, label = 'airp', key = 'column', value = 3)
input_yaml(file = yaml, label = 'airp', key = 'scale_factor', value = 1)
#airt
input_yaml(file = yaml, label = 'airt', key = 'file', value = met_file)
input_yaml(file = yaml, label = 'airt', key = 'column', value = 4)
input_yaml(file = yaml, label = 'airt', key = 'scale_factor', value = 1)
#hum
input_yaml(file = yaml, label = 'hum', key = 'file', value = met_file)
input_yaml(file = yaml, label = 'hum', key = 'column', value = 10)
input_yaml(file = yaml, label = 'hum', key = 'type', value = 1) #1=relative humidity (%), 2=wet-bulb temperature, 3=dew point temperature, 4=specific humidity (kg/kg)
input_yaml(file = yaml, label = 'hum', key = 'scale_factor', value = 1)
#cloud
input_yaml(file = yaml, label = 'cloud', key = 'file', value = met_file)
input_yaml(file = yaml, label = 'cloud', key = 'column', value = 11)
input_yaml(file = yaml, label = 'cloud', key = 'scale_factor', value = 1)
#swr
input_yaml(file = yaml, label = 'swr', key = 'file', value = met_file)
input_yaml(file = yaml, label = 'swr', key = 'column', value = 8)
input_yaml(file = yaml, label = 'swr', key = 'scale_factor', value = 1)
#precip
input_yaml(file = yaml, label = 'precip', key = 'file', value = met_file)
input_yaml(file = yaml, label = 'precip', key = 'column', value = 13)
input_yaml(file = yaml, label = 'precip', key = 'scale_factor', value = 1)
#back_radiation
input_yaml(file = yaml, label = 'back_radiation', key = 'method', value = 1)

#####

## Set background config
input_yaml(file = yaml, label = 'location', key = 'name', value = 'mt_bold')
input_yaml(file = yaml, label = 'location', key = 'latitude', value = -35.12)
input_yaml(file = yaml, label = 'location', key = 'longitude', value = 138.70)

## Set start stop time
start = '1980-08-01 00:00:00'
stop = '1982-08-01 00:00:00'
input_yaml(file = yaml, label = 'time', key = 'start', value = start)
input_yaml(file = yaml, label = 'time', key = 'stop', value = stop)
input_yaml(file = yaml, label = 'time', key = 'dt', value = 3600)

## Create water level
wlevel_median_file = 'median_height.dat'
wlevel_out = 'wlevel.dat'
init_dep = create_level(from = as.POSIXct(start), to = as.POSIXct(stop), in_file = wlevel_median_file, out_file = wlevel_out)
input_yaml(file = yaml, label = 'zeta', key = 'method', value = 2)
input_yaml(file = yaml, label = 'zeta', key = 'file', value = wlevel_out)
input_yaml(file = yaml, label = 'zeta', key = 'offset', value = -init_dep)

## Normlize hypsograph to new depth
match_hyps(in_file = 'hypsograph.dat', out_file = 'temp_hypsograph.dat', lake_level = init_dep)
input_yaml(file = yaml, label = 'location', key = 'hypsograph', value = 'temp_hypsograph.dat')

## Create initial temperature profile
obs_file = 'temp_02-18.obs'
init_prof(obs_file = obs_file, date = start, tprof_file = 'init_tprof.dat', month = 8, ndeps = 2, btm_depth = -init_dep, print = T)
input_yaml(file = yaml, label = 'temperature', key = 'method', value = 2)
input_yaml(file = yaml, label = 'temperature', key = 'file', value = 'init_tprof.dat')

## Switch streams on/off
streams_switch(yaml, method = 'on')
run_gotm()
p1 <- plot_wtemp(out)

streams_switch(yaml, method = 'off')
run_gotm()
p2 <- plot_wtemp(out)

library(ggpubr)
ggarrange(p1, p2, nrow = 2)

wbal <- get_vari(out, "Qlayer")[,1:2] #total inflow
res <- get_vari(out, "Qres")[,1:2] #water balance residuals
plot(wbal, type ='l', ylim = c(-40,40))
lines(res, col =2)
plot_vari(out, "Qlayer")
plot_wbal(out)
