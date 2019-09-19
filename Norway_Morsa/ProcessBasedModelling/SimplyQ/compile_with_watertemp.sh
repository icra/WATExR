#!/bin/bash
g++ -fpic -m64 -std=c++11 -c -O2 simplyq_with_water_temperature_dll.cpp
g++ -o simplyq_with_watertemp.so -m64 -shared simplyq_with_water_temperature_dll.o