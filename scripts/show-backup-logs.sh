#!/bin/bash
set -euo pipefail
journalctl -u p1-backup.service --since "7 days ago" --no-pager
