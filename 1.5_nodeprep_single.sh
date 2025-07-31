#!/bin/bash
# remove old known_hosts entries in shared directory
#rm /shared/home/jonathan.austin/.ssh/known_hosts
#touch /shared/home/jonathan.austin/.ssh/known_hosts
ssh-keygen -R ccw-converged-gpu-2
# install pdcp support missing on nodes
pdsh -w ccw-converged-gpu-2 sudo apt-get install -y pdsh
pdsh -w ccw-converged-gpu-2 'scp ccw-converged-scheduler:/etc/pdsh/machines /tmp && sudo cp /tmp/machines /etc/pdsh/'
pdsh -w ccw-converged-gpu-2 sudo umount /mnt/nvme
pdsh -w ccw-converged-gpu-2 "sudo sed -i '/LABEL=azure_temp \/mnt\/nvme xfs defaults,nofail 0 0/d' /etc/fstab"
pdsh -w ccw-converged-gpu-2 sudo rm /etc/mdadm/mdadm.conf
pdsh -w ccw-converged-gpu-2 sudo mdadm --stop /dev/md0
pdsh -w ccw-converged-gpu-2 sudo mdadm --zero-superblock /dev/nvme0n1 /dev/nvme1n1 /dev/nvme2n1 /dev/nvme3n1 /dev/nvme4n1 /dev/nvme5n1 /dev/nvme6n1 /dev/nvme7n1
pdsh -w ccw-converged-gpu-2 -f 1 sudo lsblk
echo "Reboot nodes using pdsh sudo reboot and then re-verify md devices do not come back"
