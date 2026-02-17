#!/bin/bash
set -euo pipefail
journalctl -u nginx --since "24 hours ago" --no-pager
