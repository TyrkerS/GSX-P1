#!/bin/bash
set -euo pipefail

# Workload simple: consume CPU hasta que reciba una señal de parada.
exec yes > /dev/null
