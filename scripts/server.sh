#!bin/bash

sudo killall go-vpn
sudo ./bin/go-vpn -S -l=:3001 -c=172.16.0.1/24 &
echo "started!"
