#!/usr/bin/env bash

# Require jq
if ! command -v jq &> /dev/null; then
  echo "Error: 'jq' is required but not installed."
  exit 1
fi

# Backup copies, in case we need to revert
cp /etc/iproute2/rt_tables /etc/iproute2/rt_tables.orig
cp /etc/netplan/50-cloud-init.yaml /etc/netplan/50-cloud-init.yaml.orig

# Routing table, in line with TF: https://github.com/weka/terraform-azure-weka/blob/dev/function-app/code/functions/scale_up/init_script.go
# Azure Documentation: https://learn.microsoft.com/en-us/troubleshoot/azure/virtual-machines/linux/linux-vm-multiple-virtual-network-interfaces-configuration
echo "200 eth0-rt" >> /etc/iproute2/rt_tables

# Templates for splicing
cat <<EOF > /tmp/netplan_template_eth0
        ethX:
            mtu: 3900
            dhcp4: true
            dhcp4-overrides:
                route-metric: 100
            dhcp6: false
            match:
                driver: hv_netvsc
                macaddress: MAC
            set-name: ethX
            routes:
             - to: SUBNET/PREFIX
               via: ROUTE
               metric: 200
               table: 200
             - to: 0.0.0.0/0
               via: ROUTE
               table: 200
            routing-policy:
             - from: III/32
               table: 200
             - to: III/32
               table: 200
EOF
cat <<EOF > /tmp/netplan_template_eth_others
        ethX:
            mtu: 3900
            dhcp4: true
            dhcp4-overrides:
                route-metric: MMM
                use-dns: false
            dhcp6: false
            match:
                driver: hv_netvsc
                macaddress: MAC
            set-name: ethX
EOF

# New netplan header
cat <<EOF > /etc/netplan/50-cloud-init.yaml
network:
    ethernets:
EOF

# Fetching Azure metadata
metadata_json=$(curl -s -H Metadata:true "http://169.254.169.254/metadata/instance/network/interface?api-version=2021-02-01")

if [ -z "$metadata_json" ]; then
  echo "Error: Failed to fetch metadata."
  exit 1
fi

# Matching interfaces based on MAC address
for i in $(seq 0 $(($(echo "$metadata_json" | jq 'length') - 1))); do
  meta_mac=$(echo "$metadata_json" | jq -r ".[$i].macAddress" | tr 'A-F' 'a-f' | sed 's/../&:/g;s/:$//')

  # Normalize MAC format to lowercase with colons
  normalized_mac=$(echo "$meta_mac" | tr 'A-F' 'a-f')
  route=$(ip r | grep default | awk '{print $3}')

  ### different for eth0
  ### change template files
  ### figure out base network range
  for iface in /sys/class/net/eth[0-7]; do
    iface_name=$(basename "$iface")
    sys_mac=$(cat "$iface/address" | tr 'A-F' 'a-f')
    route_metric=$(( 100 * ( $i + 1 )  ))

    # Generate new netplan assignment based on template
    if [ "$sys_mac" == "$normalized_mac" ]; then
      private_ip=$(echo "$metadata_json" | jq -r ".[$i].ipv4.ipAddress[0].privateIpAddress")
      if [ "$iface_name" == "eth0" ]; then
        subnet=$(echo "$metadata_json" | jq -r ".[$i].ipv4.subnet[0].address")
        prefix=$(echo "$metadata_json" | jq -r ".[$i].ipv4.subnet[0].prefix")
        cat /tmp/netplan_template_eth0 | sed -e "s/ethX/${iface_name}/" -e "s/III/${private_ip}/" -e "s/MAC/${meta_mac}/" -e "s/SUBNET/${subnet}/" -e "s/PREFIX/${prefix}/" -e "s/ROUTE/${route}/" >> /etc/netplan/50-cloud-init.yaml
      else
        cat /tmp/netplan_template_eth_others | sed -e "s/ethX/${iface_name}/" -e "s/MMM/${route_metric}/" -e "s/MAC/${meta_mac}/" >> /etc/netplan/50-cloud-init.yaml
      fi
      break
    fi
  done
done

# New netplan footer
echo -e '    version: 2' >> /etc/netplan/50-cloud-init.yaml

# Apply netplan configuration
netplan apply
rm /tmp/netplan_template*

# Generate the script to delete routes
SUBNET_RANGE="$(echo "$metadata_json" | jq -r ".[$i].ipv4.subnet[0].address")/$(echo "$metadata_json" | jq -r ".[$i].ipv4.subnet[0].prefix")"

# Make sure it's persistent across reboots
cat <<EOF >/usr/sbin/remove-routes.sh 
#!/usr/bin/env bash
set -ex
retry_max=24
#for(( i=0; i<\$retry_max; i++ )); do
#  if eval "ip route | grep eth4 && ip route | grep eth5 && ip route | grep eth6 && ip route | grep eth7"; then
#    for(( j=4; j<7; j++ )); do
#      /usr/sbin/ip route del $SUBNET_RANGE dev eth\$j
#	echo $SUBNET_RANGE dev eth\$j
#    done
#    break
#  fi
for(( i=0; i<\$retry_max; i++ )); do
  if eval "ip route | grep eth1 && ip route | grep eth2 && ip route | grep eth3 && ip route | grep eth4 && ip route | grep eth5 && ip route | grep eth6 && ip route | grep eth7"; then
    for(( j=1; j<8; j++ )); do
      /usr/sbin/ip route del $SUBNET_RANGE dev eth\$j
        echo $SUBNET_RANGE dev eth\$j
    done
    break
  fi
  ip route
  sleep 5
done
if [ \$i -eq \$retry_max ]; then
  echo "Routes are not ready on time"
  echo "try shutdown -r now"
  exit 1
fi
echo "Routes were removed successfully"
EOF

chmod +x /usr/sbin/remove-routes.sh
cat /usr/sbin/remove-routes.sh
cat <<EOF >/etc/systemd/system/remove-routes.service
[Unit]
Description=Remove specific routes
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/bin/bash /usr/sbin/remove-routes.sh

[Install]
WantedBy=multi-user.target
EOF

ip route # show routes before removing
systemctl daemon-reload
systemctl enable remove-routes.service
systemctl start remove-routes.service
systemctl status remove-routes.service
ip route # show routes after removing
