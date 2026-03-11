#!/bin/bash

BASE="/home/greendevcorp"

echo "Checking directories..."

ls -ld $BASE
ls -ld $BASE/bin
ls -ld $BASE/shared

echo ""
echo "Checking done.log permissions"

ls -l $BASE/done.log

echo ""
echo "Checking users"

id dev1
id dev2
id dev3
id dev4

echo ""
echo "Testing write permissions"

sudo -u dev2 bash -c "echo test >> $BASE/done.log" 2>/dev/null

if [ $? -ne 0 ]; then
    echo "dev2 correctly blocked"
else
    echo "ERROR: dev2 should not write"
fi

sudo -u dev1 bash -c "echo test >> $BASE/done.log"

echo "Verification complete"