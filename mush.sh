#!/bin/bash
declare -A ip_array
while read -r iface ip; do
	  ip=${ip%%/*}  # Strip netmask
	    [[ "$iface" =~ ^eth ]] && [[ ! "$iface" =~ ^(ib|lo|docker) ]] && ip_array["$iface"]="$ip"
    done < <(ip a | awk '/^[0-9]+: / {iface=$2; sub(/:/,"",iface)} /inet / {print iface, $2}' | sort -k1)

    # Print sorted array
    for iface in "${!ip_array[@]}"; do
	      echo "$iface ${ip_array[$iface]}"
      done | sort -k1
