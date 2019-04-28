#!/bin/bash

sudo ./build/MoonGen examples/loopback_cable_test.lua 0 10.1.1.2 2 30.1.1.2 &
sleep 5
sudo killall -15 MoonGen
sleep 2

sudo ./build/MoonGen examples/loopback_cable_test.lua 2 30.1.1.2 0 10.1.1.2 &
sleep 5
sudo killall -15 MoonGen
sleep 2

sudo ./build/MoonGen examples/loopback_cable_test.lua 1 20.1.1.2 3 40.1.1.2 &
sleep 5
sudo killall -15 MoonGen
sleep 2

sudo ./build/MoonGen examples/loopback_cable_test.lua 3 40.1.1.2 1 20.1.1.2 &
sleep 5
sudo killall -15 MoonGen
sleep 2



