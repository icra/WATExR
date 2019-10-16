


import numpy as np
import imp
import pandas as pd
import csv
from netCDF4 import Dataset
import os
from subprocess import Popen, PIPE
import datetime
import matplotlib.pyplot as plt
import time
import shutil
from calendar import monthrange

wr = imp.load_source('mobius', 'mobius.py')
wr.initialize('SimplyQ/simplyq_with_watertemp.so')


def save_gotm_input_file(name, dates, flow, temperature) :
	out_data = pd.DataFrame({
		'Date' : dates,
		'Flow' : flow,
		'Temp' : temperature,
	})

	out_data.set_index('Date', inplace=True)
	out_data.to_csv(name, sep='\t', header=False, date_format='%Y-%m-%d %H:%M:%S', quoting=csv.QUOTE_NONE)


def run_single_coupled_model(dataset, store_folder, vanem_folder, store_result_name, vanem_result_name) :

	#NOTE: handling of folder structure is not very robust at the moment, so store_folder and vanem_folder can't be nested folders (they have to be in the same top folder as the CoupledRunResults folder	

	start_run = time.time()

	dataset.run_model()

	flow_vaaler = dataset.get_result_series('Reach flow (daily mean, cumecs)', ['Vaaler'])
	flow_store  = dataset.get_result_series('Reach flow (daily mean, cumecs)', ['Store'])
	flow_vanem  = dataset.get_result_series('Reach flow (daily mean, cumecs)', ['Vanem'])

	inflow_temperature = dataset.get_result_series('Water temperature', ['Vaaler']) #It will be the same for all reaches unless somebody decide to recalibrate that


	inflow_storefjord = flow_vaaler + flow_store


	# Create input file for gotm at Storefjord

	start_date = dataset.get_parameter_time('Start date', []).replace(hour=12)
	timesteps  = dataset.get_parameter_uint('Timesteps', [])

	dates = pd.date_range(start=start_date, periods=timesteps, freq='D')


	os.chdir(store_folder)

	save_gotm_input_file('store_inflow.dat', dates, inflow_storefjord, inflow_temperature)

	proc = Popen(['./gotm'], stdout=PIPE)
	print(proc.communicate())

	# Read output from Storefjord and create input for Vanemfjord

	store_out = Dataset('output.nc', 'r', format='NETCDF4')

	store_outflow_temp = np.mean(store_out['/temp'][:, 95:99, 0, 0], 1)

	store_water_balance = store_out['/int_water_balance'][:, 0, 0]

	store_outflow = np.array(np.diff(store_water_balance, n=1)) / 86400.0
	store_outflow = np.insert(store_outflow, 1, store_water_balance[0]/86400.0)

	store_out.close()

	shutil.copy2('output.nc', '../CoupledRunResults/%s' % store_result_name)

	os.chdir('../%s' % vanem_folder)

	save_gotm_input_file('store_outflow.dat', dates, store_outflow, store_outflow_temp)
	save_gotm_input_file('vanem_subcatchment_outflow.dat', dates, flow_vanem, inflow_temperature)

	proc = Popen(['./gotm'], stdout=PIPE)
	print(proc.communicate())

	shutil.copy2('output.nc', '../CoupledRunResults/%s' % vanem_result_name)

	os.chdir('..')

	end_run = time.time()

	print('Elapsed time for a single coupled run: %f' % (end_run - start_run))


def run_single_coupled_model_with_input(dataset, store_result_name, vanem_result_name, df) :

	timesteps = len(df.index)

	start_date = pd.to_datetime(str(df['Date'].values[0])).strftime('%Y-%m-%d')
	end_date   = pd.to_datetime(str(df['Date'].values[-1])).strftime('%Y-%m-%d')

	dataset.set_parameter_time('Start date', [], start_date)
	dataset.set_parameter_uint('Timesteps', [], timesteps)

	dataset.set_input_series('Precipitation', [], df['pr'].values, alignwithresults=True)
	dataset.set_input_series('Air temperature', [], df['tas'].values, alignwithresults=True)	

	# make temp copy of store and vanem to store_temp, vanem_temp

	os.system('cp -r store store_temp')
	os.system('cp -r vanem vanem_temp')

	# modify the met input files in those folders with the data from df

	precip_df = df[['Date', 'pr']]

	precip_df.to_csv('store_temp/precip_van.dat', index=False, sep='\t', header=False, date_format='%Y-%m-%d %H:%M:%S', quoting=csv.QUOTE_NONE)
	precip_df.to_csv('vanem_temp/precip_van.dat', index=False, sep='\t', header=False, date_format='%Y-%m-%d %H:%M:%S', quoting=csv.QUOTE_NONE)


	rad_df = df[['Date', 'rsds']]
	
	rad_df.to_csv('store_temp/radiation_van.dat', index=False, sep='\t', header=False, date_format='%Y-%m-%d %H:%M:%S', quoting=csv.QUOTE_NONE)
	rad_df.to_csv('vanem_temp/radiation_van.dat', index=False, sep='\t', header=False, date_format='%Y-%m-%d %H:%M:%S', quoting=csv.QUOTE_NONE)

	weather_df = df[['Date', 'uas', 'vas', 'ps', 'tas', 'hurs', 'cc']]

	weather_df.to_csv('store_temp/weather_van_cc.dat', index=False, sep='\t', header=False, date_format='%Y-%m-%d %H:%M:%S', quoting=csv.QUOTE_NONE)
	weather_df.to_csv('vanem_temp/weather_van_cc.dat', index=False, sep='\t', header=False, date_format='%Y-%m-%d %H:%M:%S', quoting=csv.QUOTE_NONE)	

	# NOTE: Update gotmrun.nml to have correct start_date and end_date
	for filename in ['store_temp/gotmrun.nml', 'vanem_temp/gotmrun.nml']:
		with open(filename, 'r') as myfile:
	  		data = myfile.read()
			data = data.replace('1979-01-01', start_date)   #WARNING: This is kind of volatile if we change start date in the default gotmrun.nml
			data = data.replace('2015-12-31', end_date)
			myfile.close()
			with open(filename, 'w') as myfile :
				myfile.write(data)
				myfile.close()

	run_single_coupled_model(dataset, 'store_temp', 'vanem_temp', store_result_name, vanem_result_name)

	os.system('rm -r store_temp')
	os.system('rm -r vanem_temp')


def renormalize(year, month) :
	if month > 12 :
		return year+1, month-12
	else :
		return year, month

def full_scenario_run(dataset) :
	for year in range(1981, 2011) :   #range is noninclusive in the second argument, so final year is 2010
		for season_idx, season in enumerate(['MAM', 'JJA', 'SON', 'DJF']):
			
			#start the run 1 year and 1 month before the target season

			warmup_start_year, warmup_start_month = renormalize(year - 1, 3 + 3*season_idx - 1)

			warmup_end_year, warmup_end_month = renormalize(warmup_start_year + 1, warmup_start_month - 1)

			run_start_year, run_start_month = renormalize(warmup_end_year, warmup_end_month + 1)
			
			run_end_year, run_end_month = renormalize(run_start_year, run_start_month + 3)


			def monthlen(year, month) :
				return monthrange(year, month)[1]

			print('%d %s : warmup: (%d-%d-%d) - (%d-%d-%d) run (%d-%d-%d) - (%d-%d-%d)'
				% (year, season, warmup_start_year, warmup_start_month, 1, warmup_end_year, warmup_end_month, monthlen(warmup_end_year, warmup_end_month), run_start_year, run_start_month, 1, run_end_year, run_end_month, monthlen(run_end_year, run_end_month)))



			era_interim_df = pd.read_csv('climate_forecast/eraInterim_bias_corrected_with_ewembi.csv', parse_dates=[0,])   #It is actually a hindcast, not a forecast, but anywhoo..

			era_interim_df = era_interim_df.rename(columns={'Unnamed: 0': 'Date'})

			era_interim_df['Date'] = [date.replace(hour=12) for date in era_interim_df['Date']]


			#for scenario_idx, scenario in enumerate(['put', 'a', 'bunch', 'of', 'system4', 'scenario', 'names', 'here']) :
			
				#TODO: prepare meteorological timeseries, where the warmup part is eraInterim, and the rest is from the scenario
				
				warmup_mask = (era_interim_df['Date'] >= '%d-%d-%d' % (warmup_start_year, warmup_start_month, 1)) & (era_interim_df['Date'] <= '%d-%d-%d' % (warmup_end_year, warmup_end_month, monthlen(warmup_end_year, warmup_end_month)))   #TODO: Check inclusivity of last date..
				warmup_df = era_interim_df[warmup_mask]
				
				scenario_df = blablabla #TODO!!!
				
				run_mask = (scenario_df['Date'] >= '%d-%d-%d' % (run_start_year, run_start_month, 1)) & (scenario_df['Date'] >= '%d-%d-%d' % (run_end_year, run_end_month, monthlen(run_end_year, run_end_month))
				run_df = scenario_df[run_mask]
				
				df = pd.concat([warmup_df, run_df], )

				print(df)

				name = '%d_%s_%s' % (year, season, scenario)

				#run_single_coupled_model_with_input(dataset, 'store_%s.nc' % name, 'vanem_%s.nc' % name, df)

def single_eraInterim_run(dataset) :
	
	df = pd.read_csv('climate_forecast/eraInterim_bias_corrected_with_ewembi.csv', parse_dates=[0,])   #It is actually a hindcast, not a forecast, but anywhoo..

	df = df.rename(columns={'Unnamed: 0': 'Date'})

	df['Date'] = [date.replace(hour=12) for date in df['Date']]

	mask = (df['Date'] >= '1981-1-1') & (df['Date'] <= '2011-1-1')   #NOTE: The last date is non-inclusive, but I have no idea why ( I use <= .... )
	df = df.loc[mask]

	elevation_coeff = 0.0065*100
	
	#correct atmospheric pressure for elevation and temperature
	df['ps'] = df['ps']*(1.0 - elevation_coeff / (df['tas'] + 273.15 + elevation_coeff))**(-5.257)	

	run_single_coupled_model_with_input(dataset, 'store_full_eraInterim.nc', 'vanem_full_eraInterim.nc', df)



dataset = wr.DataSet.setup_from_parameter_and_input_files('SimplyQ/mobius_vansjo_parameters.dat', 'SimplyQ/mobius_vansjo_inputs.dat')

#run_single_coupled_model(dataset, 'store', 'vanem', 'store.nc', 'vanem.nc')
#full_scenario_run(dataset)
single_eraInterim_run(dataset)


			

		





