#!/bin/bash -x

echo "Stopping local containers"
seq 1 6 | xargs -I {} -P 0 ssh ccw-converged-gpu-{} 'sudo weka local stop -f'
sleep 2

echo "Removing containers"
seq 1 6 | xargs -I {} -P 0 ssh ccw-converged-gpu-{} 'sudo weka local rm --all -f'
sleep 2

echo "Setting up containers"
ssh ccw-converged-gpu-1 'sudo weka local setup container --name drives0 --failure-domain weka1 --cores 1 --core-ids 1 --only-drives-cores --net $(ip a | grep "master eth1" | awk -F": " "{print \$2}")/$(ip -4 -o a | grep eth1 | cut -d " " -f7)/10.10.0.1 --management-ips $(ip -4 -o a | grep eth0 | cut -d " " -f7 | cut -d "/" -f1)'
ssh ccw-converged-gpu-2 'sudo weka local setup container --name drives0 --failure-domain weka2 --cores 1 --core-ids 1 --only-drives-cores --net $(ip a | grep "master eth1" | awk -F": " "{print \$2}")/$(ip -4 -o a | grep eth1 | cut -d " " -f7)/10.10.0.1 --management-ips $(ip -4 -o a | grep eth0 | cut -d " " -f7 | cut -d "/" -f1)'
ssh ccw-converged-gpu-3 'sudo weka local setup container --name drives0 --failure-domain weka3 --cores 1 --core-ids 1 --only-drives-cores --net $(ip a | grep "master eth1" | awk -F": " "{print \$2}")/$(ip -4 -o a | grep eth1 | cut -d " " -f7)/10.10.0.1 --management-ips $(ip -4 -o a | grep eth0 | cut -d " " -f7 | cut -d "/" -f1)'
ssh ccw-converged-gpu-4 'sudo weka local setup container --name drives0 --failure-domain weka4 --cores 1 --core-ids 1 --only-drives-cores --net $(ip a | grep "master eth1" | awk -F": " "{print \$2}")/$(ip -4 -o a | grep eth1 | cut -d " " -f7)/10.10.0.1 --management-ips $(ip -4 -o a | grep eth0 | cut -d " " -f7 | cut -d "/" -f1)'
ssh ccw-converged-gpu-5 'sudo weka local setup container --name drives0 --failure-domain weka5 --cores 1 --core-ids 1 --only-drives-cores --net $(ip a | grep "master eth1" | awk -F": " "{print \$2}")/$(ip -4 -o a | grep eth1 | cut -d " " -f7)/10.10.0.1 --management-ips $(ip -4 -o a | grep eth0 | cut -d " " -f7 | cut -d "/" -f1)'
ssh ccw-converged-gpu-6 'sudo weka local setup container --name drives0 --failure-domain weka6 --cores 1 --core-ids 1 --only-drives-cores --net $(ip a | grep "master eth1" | awk -F": " "{print \$2}")/$(ip -4 -o a | grep eth1 | cut -d " " -f7)/10.10.0.1 --management-ips $(ip -4 -o a | grep eth0 | cut -d " " -f7 | cut -d "/" -f1)'

#seq 1 6 | xargs -I {} -P 0 ssh ccw-converged-gpu-{} "sudo weka local setup container --name drives0 --failure-domain weka{} --cores 1 --core-ids 1 --only-drives-cores --net eth9/\`ip -4 -o a | grep eth1 | cut -d ' ' -f7\` --management-ips \`ip -4 -o a | grep eth0 | cut -d ' ' -f7 | cut -d '/' -f1\`"

echo "Forming cluster"
ssh ccw-converged-gpu-1 sudo weka cluster create ccw-converged-gpu-{1..6}

sleep 5
ssh ccw-converged-gpu-1 sudo weka cluster update --data-drives 3 --parity-drives 2 --cluster-name Weka-Azure-Converged-Testing
ssh ccw-converged-gpu-1 sudo weka cloud enable
ssh ccw-converged-gpu-1 sudo weka cluster hot-spare 1

sleep 2

echo "Adding drives"
seq 0 5 | xargs -I {} -P 0 ssh ccw-converged-gpu-1 sudo weka cluster drive add {} /dev/nvme{0..3}n1

sleep 10

echo "Creating compute and frontend containers"
ssh ccw-converged-gpu-1 'sudo weka local setup container --name compute0 --failure-domain weka1 --cores 2 --core-ids 2,3 --only-compute-cores --memory 50GB --base-port 14200 --join-ips 10.10.0.18  --net $(ip a | grep "master eth2" | awk -F": " "{print \$2}")/$(ip -4 -o a | grep eth2 | cut -d " " -f7)/10.10.0.1 --net $(ip a | grep "master eth3" | awk -F": " "{print \$2}")/$(ip -4 -o a | grep eth3 | cut -d " " -f7)/10.10.0.1 --management-ips $(ip -4 -o a | grep eth0 | cut -d " " -f7 | cut -d "/" -f1)'
ssh ccw-converged-gpu-2 'sudo weka local setup container --name compute0 --failure-domain weka2 --cores 2 --core-ids 2,3 --only-compute-cores --memory 50GB --base-port 14200 --join-ips 10.10.0.18  --net $(ip a | grep "master eth2" | awk -F": " "{print \$2}")/$(ip -4 -o a | grep eth2 | cut -d " " -f7)/10.10.0.1 --net $(ip a | grep "master eth3" | awk -F": " "{print \$2}")/$(ip -4 -o a | grep eth3 | cut -d " " -f7)/10.10.0.1 --management-ips $(ip -4 -o a | grep eth0 | cut -d " " -f7 | cut -d "/" -f1)'
ssh ccw-converged-gpu-3 'sudo weka local setup container --name compute0 --failure-domain weka3 --cores 2 --core-ids 2,3 --only-compute-cores --memory 50GB --base-port 14200 --join-ips 10.10.0.18  --net $(ip a | grep "master eth2" | awk -F": " "{print \$2}")/$(ip -4 -o a | grep eth2 | cut -d " " -f7)/10.10.0.1 --net $(ip a | grep "master eth3" | awk -F": " "{print \$2}")/$(ip -4 -o a | grep eth3 | cut -d " " -f7)/10.10.0.1 --management-ips $(ip -4 -o a | grep eth0 | cut -d " " -f7 | cut -d "/" -f1)'
ssh ccw-converged-gpu-4 'sudo weka local setup container --name compute0 --failure-domain weka4 --cores 2 --core-ids 2,3 --only-compute-cores --memory 50GB --base-port 14200 --join-ips 10.10.0.18  --net $(ip a | grep "master eth2" | awk -F": " "{print \$2}")/$(ip -4 -o a | grep eth2 | cut -d " " -f7)/10.10.0.1 --net $(ip a | grep "master eth3" | awk -F": " "{print \$2}")/$(ip -4 -o a | grep eth3 | cut -d " " -f7)/10.10.0.1 --management-ips $(ip -4 -o a | grep eth0 | cut -d " " -f7 | cut -d "/" -f1)'
ssh ccw-converged-gpu-5 'sudo weka local setup container --name compute0 --failure-domain weka5 --cores 2 --core-ids 2,3 --only-compute-cores --memory 50GB --base-port 14200 --join-ips 10.10.0.18  --net $(ip a | grep "master eth2" | awk -F": " "{print \$2}")/$(ip -4 -o a | grep eth2 | cut -d " " -f7)/10.10.0.1 --net $(ip a | grep "master eth3" | awk -F": " "{print \$2}")/$(ip -4 -o a | grep eth3 | cut -d " " -f7)/10.10.0.1 --management-ips $(ip -4 -o a | grep eth0 | cut -d " " -f7 | cut -d "/" -f1)'
ssh ccw-converged-gpu-6 'sudo weka local setup container --name compute0 --failure-domain weka6 --cores 2 --core-ids 2,3 --only-compute-cores --memory 50GB --base-port 14200 --join-ips 10.10.0.18  --net $(ip a | grep "master eth2" | awk -F": " "{print \$2}")/$(ip -4 -o a | grep eth2 | cut -d " " -f7)/10.10.0.1 --net $(ip a | grep "master eth3" | awk -F": " "{print \$2}")/$(ip -4 -o a | grep eth3 | cut -d " " -f7)/10.10.0.1 --management-ips $(ip -4 -o a | grep eth0 | cut -d " " -f7 | cut -d "/" -f1)'

#seq 1 6 | xargs -I {} -P 0 ssh ccw-converged-gpu-{} "sudo weka local setup container --name compute0 --failure-domain weka{} --cores 2 --core-ids 2,3 --only-compute-cores --memory 50GB --base-port 14200 --join-ips 10.10.0.18  --net eth10/\`ip -4 -o a | grep eth2 | cut -d ' ' -f7\` --net eth11/\`ip -4 -o a | grep eth3 | cut -d ' ' -f7\` --management-ips \`ip -4 -o a | grep eth0 | cut -d ' ' -f7 | cut -d '/' -f1\`"

ssh ccw-converged-gpu-1 'sudo weka local setup container --name frontends0 --cores 1 --core-ids 4 --only-frontend-cores --base-port 14300 --allow-protocols true --join-ips 10.10.0.18  --net $(ip a | grep "master eth4" | awk -F": " "{print \$2}")/$(ip -4 -o a | grep eth4 | cut -d " " -f7)/10.10.0.1 --management-ips $(ip -4 -o a | grep eth0 | cut -d " " -f7 | cut -d "/" -f1)'
ssh ccw-converged-gpu-2 'sudo weka local setup container --name frontends0 --cores 1 --core-ids 4 --only-frontend-cores --base-port 14300 --allow-protocols true --join-ips 10.10.0.18  --net $(ip a | grep "master eth4" | awk -F": " "{print \$2}")/$(ip -4 -o a | grep eth4 | cut -d " " -f7)/10.10.0.1 --management-ips $(ip -4 -o a | grep eth0 | cut -d " " -f7 | cut -d "/" -f1)'
ssh ccw-converged-gpu-3 'sudo weka local setup container --name frontends0 --cores 1 --core-ids 4 --only-frontend-cores --base-port 14300 --allow-protocols true --join-ips 10.10.0.18  --net $(ip a | grep "master eth4" | awk -F": " "{print \$2}")/$(ip -4 -o a | grep eth4 | cut -d " " -f7)/10.10.0.1 --management-ips $(ip -4 -o a | grep eth0 | cut -d " " -f7 | cut -d "/" -f1)'
ssh ccw-converged-gpu-4 'sudo weka local setup container --name frontends0 --cores 1 --core-ids 4 --only-frontend-cores --base-port 14300 --allow-protocols true --join-ips 10.10.0.18  --net $(ip a | grep "master eth4" | awk -F": " "{print \$2}")/$(ip -4 -o a | grep eth4 | cut -d " " -f7)/10.10.0.1 --management-ips $(ip -4 -o a | grep eth0 | cut -d " " -f7 | cut -d "/" -f1)'
ssh ccw-converged-gpu-5 'sudo weka local setup container --name frontends0 --cores 1 --core-ids 4 --only-frontend-cores --base-port 14300 --allow-protocols true --join-ips 10.10.0.18  --net $(ip a | grep "master eth4" | awk -F": " "{print \$2}")/$(ip -4 -o a | grep eth4 | cut -d " " -f7)/10.10.0.1 --management-ips $(ip -4 -o a | grep eth0 | cut -d " " -f7 | cut -d "/" -f1)'
ssh ccw-converged-gpu-6 'sudo weka local setup container --name frontends0 --cores 1 --core-ids 4 --only-frontend-cores --base-port 14300 --allow-protocols true --join-ips 10.10.0.18  --net $(ip a | grep "master eth4" | awk -F": " "{print \$2}")/$(ip -4 -o a | grep eth4 | cut -d " " -f7)/10.10.0.1 --management-ips $(ip -4 -o a | grep eth0 | cut -d " " -f7 | cut -d "/" -f1)'

#seq 1 6 | xargs -I {} -P 0 ssh ccw-converged-gpu-{} "sudo weka local setup container --name frontends0 --cores 1 --core-ids 4 --only-frontend-cores --base-port 14300 --allow-protocols true --join-ips 10.10.0.18  --net eth12/\`ip -4 -o a | grep eth4 | cut -d ' ' -f7\` --management-ips \`ip -4 -o a | grep eth0 | cut -d ' ' -f7 | cut -d '/' -f1\`"

sleep 10

ssh ccw-converged-gpu-1 sudo weka cluster start-io
