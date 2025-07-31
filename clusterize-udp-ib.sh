pdsh -R ssh -w ccw-converged-gpu-[1-6] 'sudo umount /mnt/weka'

pdsh -R ssh -w ccw-converged-gpu-[1-6] 'ip addr show ib0'

pdsh -R ssh -w ccw-converged-gpu-[1-6] 'sudo weka local stop -f && sudo weka local rm --force --all'
pdsh -R ssh -w ccw-converged-gpu-[1-6] 'sudo weka local setup container --name drives0 --cores 8 --core-ids 2,4,6,8,10,12,14,16 --net udp --only-drives-cores'

weka cluster create ccw-converged-gpu-{1..6} --host-ips 172.16.4.42,172.16.4.66,172.16.4.18,172.16.4.34,172.16.4.58,172.16.4.50

pdsh -R ssh -w ccw-converged-gpu-[1-6] 'sudo weka local setup container --name compute0 --cores 12 --core-ids 18,20,22,24,26,28,30,32,34,36,38,40 --net udp --only-compute-cores --join-ips 172.16.4.58 --memory 64GB'

pdsh -R ssh -w ccw-converged-gpu-[1-6] 'sudo weka local setup container --name frontend0 --cores 12 --core-ids 68,70,72,74,76,78,80,82,84,86,88,90 --net udp --only-frontend-cores --join-ips 172.16.4.58'

seq 0 5 | xargs -I {} -P 0 weka cluster drive add {} /dev/nvme{0..7}n1

weka cloud enable --cloud-url https://api.home.rnd.weka.io
weka cluster license payg CAb8oUcHUAVSyeWtnWF7ZS 6l2ItpW2Zmk8maVK/Z6CFT06VToGfiPXmhZl9YD/wgQgChOYe5UTW8blsyHfpZXm	

weka cluster start-io

weka fs group create default
weka fs create default default 60TB

pdsh -R ssh -w ccw-converged-gpu-[1-6] 'sudo mount -t wekafs default /mnt/weka'
