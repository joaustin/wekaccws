#!/bin/bash

host=ccw-converged-gpu-
lower_backend=1
upper_backend=7
DOIT=echo
#DOIT=""

version=4.4.7.1386-6309c347e85cf692ce7b1e4ca757ebf0 # a version one commit before netvsc code, with latest trace fix
version=4.4.4.127-azure_poc_netvsc-beta
#ersion=4.4.7.1280-7a91c858183a681b593cabe33ece93db # release version containning netvsc code, with latest trace fix

echo "pdsh -R ssh -w $host[$lower_backend-$upper_backend] 'sudo weka version get $version'"
pdsh -R ssh -w $host[$lower_backend-$upper_backend] "sudo weka version get $version"


echo "pdsh -R ssh -w $host[$lower_backend-$upper_backend] 'sudo weka local stop -f && sudo  weka local rm -f --all'"
pdsh -R ssh -w $host[$lower_backend-$upper_backend] "sudo weka local stop -f && sudo  weka local rm -f --all"

#after we set a new version we need to remove the containers that sometimes are created as a result from set
echo "pdsh -R ssh -w $host[$lower_backend-$upper_backend] 'sudo weka version set $version' && sudo weka local stop -f && sudo  weka local rm -f --all"
pdsh -R ssh -w $host[$lower_backend-$upper_backend] "sudo weka version set $version && sudo weka local stop -f && sudo  weka local rm -f --all "


#Example to get the eth0 ip
#pdsh -R ssh -w weka1 "echo --net \`ifconfig eth0 | grep inet | grep -v inet6 | awk '{print \$2}' \`" 

#Example on how to get the slave of eth1
#pdsh -R ssh -w weka1  "ls -l /sys/class/net/eth1/ | grep lower | awk -F"_" '{print \$2}' | awk '{print \$1}'"
#weka1: eth15


pdsh -R ssh -w $host[$lower_backend-$upper_backend] $DOIT "sudo weka local setup container --name drives0 --failure-domain \`hostname\` --cores 2 --core-ids 1,2 --only-drives-cores --memory 0 --base-port 14000 --net \`ls -l /sys/class/net/eth1/ | grep lower | awk -F"_" '{print \$2}' | awk '{print \$1}'\`,\`ls -l /sys/class/net/eth2/ | grep lower | awk -F"_" '{print \$2}' | awk '{print \$1}'\` --management-ips \`ifconfig eth0 | grep inet | grep -v inet6 | awk '{print \$2}' \`"

ps=""
for ((i=$lower_backend; i<=$upper_backend; i++))
do 
   if [[ $(($i-$lower_backend)) -gt 0 ]]
   then
 	ips+=','
   fi
   eth0=`ssh $host$i "ifconfig eth0 | grep -v inet6 | grep 'inet '" | awk '{print $2}'`
   ips+=$eth0
done

pdsh -R ssh -w $host[$lower_backend] $DOIT "weka cluster create $host{$lower_backend..$upper_backend} --host-ips $ips"  #eth0

$DOIT sleep 10


#compute containers
pdsh -R ssh -w $host[$lower_backend-$upper_backend] $DOIT  "sudo weka local setup container --name compute0 --failure-domain \`hostname\` --cores 3 --core-ids 6,7,8 --only-compute-cores --memory 24GB --base-port 16000 --net \`ls -l /sys/class/net/eth3/ | grep lower | awk -F"_" '{print \$2}' | awk '{print \$1}'\`,\`ls -l /sys/class/net/eth4/ | grep lower | awk -F"_" '{print \$2}' | awk '{print \$1}'\`,\`ls -l /sys/class/net/eth5/ | grep lower | awk -F"_" '{print \$2}' | awk '{print \$1}'\` --management-ips \`ifconfig eth0 | grep inet | grep -v inet6 | awk '{print \$2}' \` --join-ips $ips"


#Frontend containers
pdsh -R ssh -w $host[$lower_backend-$upper_backend] $DOIT  "sudo weka local setup container --name frontend0 --failure-domain \`hostname\` --cores 2 --core-ids 12,13 --only-frontend-cores --base-port 17000 --net \`ls -l /sys/class/net/eth6/ | grep lower | awk -F"_" '{print \$2}' | awk '{print \$1}'\`,\`ls -l /sys/class/net/eth7/ | grep lower | awk -F"_" '{print \$2}' | awk '{print \$1}'\` --management-ips \`ifconfig eth0 | grep inet | grep -v inet6 | awk '{print \$2}' \` --join-ips $ips"


#pdsh -R ssh -w $host[$lower_backend] $DOIT "\`for i in {0..$(($upper_backend-$lower_backend))}; do weka cluster drive add \$i /dev/nvme0n1; done\`"
echo "watch weka cluster process -s -uptime #Make sure all nodes are up and runnning and the system is stable before proceding to the next steps
for i in {0..4}; do weka cluster drive add \$i /dev/nvme{0..6}n1; done
weka cluster start-io
weka fs group create default

weka fs create default default 60TB

sudo mkdir -p /mnt/weka
sudo mount -t wekafs default /mnt/weka" 




