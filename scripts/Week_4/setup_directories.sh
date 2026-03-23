#!/bin/bash
# setup_directories.sh — Creació d'estructura de directoris del projecte
# Crea bin/ i shared/ sota /home/greendevcorp amb permisos adecuats i fitxer done.log
set -euo pipefail

BASE="/home/greendevcorp"

echo "Creating directory structure..."

sudo mkdir -p $BASE/bin
sudo mkdir -p $BASE/shared

sudo touch $BASE/done.log

sudo chown root:greendevcorp $BASE
sudo chown root:greendevcorp $BASE/bin
sudo chown root:greendevcorp $BASE/shared

# bin/ :: 750 permissions (executable directory with group restriction)
sudo chmod 750 $BASE/bin
# shared/ :: 3770 permissions (setgid + sticky bit for collaboration)
sudo chmod 3770 $BASE/shared

# done.log :: propietat de dev1 amb permisos restrictius
sudo chown dev1:greendevcorp $BASE/done.log
sudo chmod 640 $BASE/done.log

echo "Directory structure created"