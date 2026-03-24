#!/bin/bash

BASE="/home/greendevcorp"

echo "Creating directory structure..."

sudo mkdir -p $BASE/bin
sudo mkdir -p $BASE/shared

sudo touch $BASE/done.log

sudo chown root:greendevcorp $BASE
sudo chown root:greendevcorp $BASE/bin
sudo chown root:greendevcorp $BASE/shared

sudo chmod 750 $BASE/bin
sudo chmod 3770 $BASE/shared

sudo chown dev1:greendevcorp $BASE/done.log
sudo chmod 640 $BASE/done.log

echo "Directory structure created"