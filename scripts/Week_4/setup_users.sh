#!/bin/bash

GROUP="greendevcorp"
USERS=("dev1" "dev2" "dev3" "dev4")

echo "Creating group..."
sudo groupadd -f $GROUP

for USER in "${USERS[@]}"
do
    echo "Creating user $USER"

    if id "$USER" &>/dev/null; then
        echo "$USER already exists"
    else
        sudo useradd -m -g $GROUP $USER
        echo "$USER:password" | sudo chpasswd
    fi
done

echo "Users created"