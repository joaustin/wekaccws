#!/bin/bash

IFACE="eth7"
SRC_IP="10.10.0.9"
SUBNET="10.10.0.0/24"
TABLE_NAME="eth7_table"
TABLE_ID=207

# Add to /etc/iproute2/rt_tables 
grep -q "$TABLE_ID $TABLE_NAME" /etc/iproute2/rt_tables || echo "$TABLE_ID $TABLE_NAME" | sudo tee -a /etc/iproute2/rt_tables

# Add route for local subnet
sudo ip route add "$SUBNET" dev $IFACE src $SRC_IP table $TABLE_NAME

# Add default route
sudo ip route add default dev $IFACE src $SRC_IP table $TABLE_NAME

# Source-based rules
sudo ip rule add from $SRC_IP/32 table $TABLE_NAME
sudo ip rule add to $SRC_IP/32 table $TABLE_NAME
