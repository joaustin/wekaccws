#!/bin/bash

# Define the common subnet
SUBNET="10.10.0.0/24"

# Array of configurations: "table_number interface"
configs=(
  "207 eth7"
    "206 eth6"
      "205 eth5"
        "204 eth4"
	  "203 eth3"
	    "202 eth2"
	      "201 eth1"
      )

      for config in "${configs[@]}"; do
	        read -r table iface <<< "$config"
  rt_name="${iface}-rt"

  # Get the IP address interface
  ip=$(ip -4 addr show "$iface" | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n 1)

  if [[ -z "$ip" ]]; then
    echo "WARNING: Interface $iface has no IP address assigned. Skipping..."
    continue
  fi

  echo "Configuring table $table for $iface ($ip)..."

  # Add to rt_tables if not already present
  grep -q "$table $rt_name" /etc/iproute2/rt_tables || \
    sudo bash -c "echo \"$table $rt_name\" >> /etc/iproute2/rt_tables"

  # Set up routing and rules
  sudo ip route add "$SUBNET" dev "$iface" src "$ip" table "$table"
  sudo ip rule add from "$ip"/32 table "$table"
  sudo ip rule add to "$ip"/32 table "$table"
done
