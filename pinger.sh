#!/bin/bash

declare -A HOST_IFACES=(
  [ccw-converged-gpu-1]="10.10.0.18 10.10.0.19 10.10.0.20 10.10.0.21 10.10.0.22 10.10.0.7 10.10.0.8 10.10.0.9"
    [ccw-converged-gpu-2]="10.10.0.47 10.10.0.48 10.10.0.49 10.10.0.50 10.10.0.51 10.10.0.52 10.10.0.53 10.10.0.54"
      [ccw-converged-gpu-3]="10.10.0.39 10.10.0.40 10.10.0.41 10.10.0.42 10.10.0.43 10.10.0.44 10.10.0.45 10.10.0.46"
        [ccw-converged-gpu-4]="10.10.0.55 10.10.0.56 10.10.0.57 10.10.0.58 10.10.0.59 10.10.0.60 10.10.0.61 10.10.0.62"
	  [ccw-converged-gpu-5]="10.10.0.23 10.10.0.24 10.10.0.25 10.10.0.26 10.10.0.27 10.10.0.28 10.10.0.29 10.10.0.30"
	    [ccw-converged-gpu-6]="10.10.0.31 10.10.0.32 10.10.0.33 10.10.0.34 10.10.0.35 10.10.0.36 10.10.0.37 10.10.0.38"
    )

    ALL_IPS=()
    for ip_list in "${HOST_IFACES[@]}"; do
	      for ip in $ip_list; do
		          ALL_IPS+=("$ip")
			    done
		    done

		    HOSTNAME=$(hostname)

		    for SRC_IP in ${HOST_IFACES[$HOSTNAME]}; do
			      echo "From $SRC_IP:"
			        for DST_IP in "${ALL_IPS[@]}"; do
					    if [[ "$SRC_IP" == "$DST_IP" ]]; then
						          continue
							      fi
							          if ping -I "$SRC_IP" -c 1 -W 1 "$DST_IP" >/dev/null 2>&1; then
									        echo "  -> $DST_IP: reachable"
										    else
											          echo "  -> $DST_IP: unreachable"
												      fi
												        done
													  echo
												  done

