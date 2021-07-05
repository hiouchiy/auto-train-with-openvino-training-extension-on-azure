#!/bin/bash

cd
apt-get update
apt-get install git -y
pip install datumaro
cd /data
datum import -i train -o train-datum -f coco
datum transform -p train-datum -o train-split -t random_split -- --subset train:.67 --subset test:.33
datum export -p train-split/ -o train-coco -f coco
