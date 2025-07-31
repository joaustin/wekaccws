#!/bin/bash

# Declare an associative array for host interfaces
declare -A HOST_IFACES

# Run pdsh to collect IPs and feed into while loop
while IFS=': ' read -r node ip_list; do
	    # Skip empty lines or invalid input
	        [[ -z "$node" || -z "$ip_list" ]] && continue
		    # Assign the IP list to the node in the associative array
		        HOST_IFACES["$node"]="$ip_list"
		done < <(pdsh -f 1 -w ccw-converged-gpu-[1-8] "ip -br a | awk '\$1 ~ /^eth[0-9]+\$/ {split(\$3, a, \"/\"); print a[1], \$1}' | sort -k2 | awk '{printf \"%s \", \$1}' | sed 's/ \$//'")

		# Check if pdsh succeeded and HOST_IFACES is populated
		if [ ${#HOST_IFACES[@]} -eq 0 ]; then
			    echo "Error: Failed to collect IPs from pdsh."
			        exit 1
		fi

		# Create a flat array of all IPs
		ALL_IPS=()
		for ip_list in "${HOST_IFACES[@]}"; do
			    for ip in $ip_list; do
				            # Validate IP address format (basic regex check)
					            if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
							                ALL_IPS+=("$ip")
									        else
											            echo "Warning: Invalid IP address '$ip' skipped."
												            fi
													        done
													done

													# Get current hostname
													HOSTNAME=$(hostname)

													# Check if this host is in HOST_IFACES
													#if [ -z "${HOST_IFACES[$HOSTNAME]}" ]; then
													#    echo "Error: Host $HOSTNAME not found in collected IPs."
													#    exit 1
													#fi

													# Ping from each local interface to all other IPs
													echo "Pinging from $HOSTNAME interfaces..."
													for SRC_IP in ${HOST_IFACES[$HOSTNAME]}; do
														    echo "From $SRC_IP:"
														        # Parallelize pings using background jobs
															    declare -A ping_results
															        for DST_IP in "${ALL_IPS[@]}"; do
																	        if [[ "$SRC_IP" == "$DST_IP" ]]; then
																			            continue
																				            fi
																					            # Run ping in background
																						            ping -I "$SRC_IP" -c 1 -W 1 "$DST_IP" >/dev/null 2>&1 &
																							            pid=$!
																								            # Store PID and destination IP for later
																									            ping_results[$pid]="$DST_IP"
																										        done

																											    # Wait for all pings to complete and collect results
																											        for pid in "${!ping_results[@]}"; do
																													        if wait "$pid"; then
																															            echo "  -> ${ping_results[$pid]}: reachable"
																																            else
																																		                echo "  -> ${ping_results[$pid]}: unreachable"
																																				        fi
																																					    done | sort  # Sort output for readability
																																					        echo
																																					done
