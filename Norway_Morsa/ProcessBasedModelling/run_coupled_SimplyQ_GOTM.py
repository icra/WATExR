


import numpy as np
import imp
import pandas as pd
import csv
from netCDF4 import Dataset
import os

wrapper_fpath = (r'mobius.py')               #This needs to point to your Mobius/PythonWrapper/mobius.py (or just copy it to this folder)
wr = imp.load_source('mobius', wrapper_fpath)
wr.initialize('simplyq_with_watertemp.dll')



#NOTE: You should set up parameter files for mobius and the GOTM lakes so that the start dates and time ranges match!
dataset = wr.DataSet.setup_from_parameter_and_input_files('mobius_vansjo_parameters.dat', 'mobius_vansjo_inputs.dat')

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

store_in = pd.DataFrame({
	'Date'  : dates,
	'Flow'  : inflow_storefjord,
	'Temp'  : inflow_temperature,
})

store_in.set_index('Date', inplace=True)

os.chdir('store')

store_in.to_csv('store_inflow.dat', sep='\t', header=False, date_format='%Y-%m-%d %H:%M:%S', quoting=csv.QUOTE_NONE)

os.system('gotm.exe') #or maybe '../gotm.exe' if you just want to have one in the top folder

# Read output from Storefjord and create input for Vanemfjord

store_out = Dataset('output.nc', 'r', format='NETCDF4')

store_outflow_temp = np.mean(store_out['/temp'][:, 95:99, 0, 0], 1)

store_water_balance = store_out['/int_water_balance'][:, 0, 0]

store_outflow = np.array(np.diff(store_water_balance, n=1))
np.insert(store_outflow, 1, store_water_balance[0])

store_out.close()

inflow_vanemfjord = store_outflow + flow_vanem

inflow_vanemfjord_temp = (store_outflow*store_outflow_temp + flow_vanem*inflow_temperature) / inflow_vanemfjord  #Average out the two inflow temperatures

vanem_in = pd.DataFrame({
	'Date'  : dates,
	'Flow'  : inflow_vanemfjord,
	'Temp'  : inflow_vanemfjord_temp,
})

vanem_in.set_index('Date', inplace=True)

os.chdir('../vanem')

vanem_in.to_csv('vanem_inflow.dat', sep='\t', header=False, date_format='%Y-%m-%d %H:%M:%S', quoting=csv.QUOTE_NONE)

os.system('gotm.exe')


#TODO process outputs of vanemfjorden run?

