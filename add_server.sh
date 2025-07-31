#!/usr/bin/env bash
set -ex

# These values are overridden by getopt below, see the README.
WEKA_VERSION=4.4.4.127-azure_poc_netvsc-beta
#WEKA_VERSION=4.4.8.53
#WEKA_VERSION=4.4.4.126-azure_poc-beta
#WEKA_VERSION=4.4.7.2522-570aef6ac30836e3dc41037f60743eab #release netvsc
#WEKA_VERSION=4.4.10.2071-32b548b60f4b1aa2b256213f8dd14ccf #release w UDP fix
#WEKA_VERSION=4.4.10.2120-b95d7f369a6f81a32bbed66ffa1a8229 # w Paul's RDMA code 
CLUSTER_NAME=mspoc
DATA_DRIVES=5
PARITY_DRIVES=2
COMPUTE_GB=24
NUM_FRONTEND_NODES=3
NUM_DRIVE_NODES=2
NUM_COMPUTE_NODES=2
BASEPORT=14000
MGMT_NIC=eth0
DOIT=
PDSH_MODE="-R ssh"

# TODO: remove this from the script
GET_WEKA_TOKEN=Kltv1cX7AreQhSeS

help() {
	cat<<EOF
Usage: $0 [-options] <servers>

Options:
	-h                     : Show this message.
	-n                     : Dry-run.
	--token <token>        : Specify get.weka.io token.
	--version <version>    : Specify weka version to use. (default is ${WEKA_VERSION})
	--computes <cores>     : Number of computes cores to use. (default is ${NUM_COMPUTE_NODES})
	--drives <cores>       : Number of drives cores to use. (default is ${NUM_DRIVE_NODES})
	--frontends <cores>    : Number of frontend cores to use. (default is ${NUM_FRONTEND_NODES})
	--name <name>          : Name of cluster (default is ${CLUSTER_NAME})
	--data-drives <num>    : Number of data drives (default is ${DATA_DRIVES})
	--parity-drives <num>  : Number of parity drives (default is ${PARITY_DRIVES})
	--compute-memory <GB>  : Size of compute memory in gigabytes (default is ${COMPUTE_GB}).
	--baseport <port>      : Base UDP port number (default is ${BASEPORT}).
	--management-nic <nic> : NIC to use for management (default is ${MGMT_NIC}).
	--join-ips <ip,...>    : Join IPs (cluster host to join)

EOF
	exit 1
}

OPTS=$(getopt -a --long help --l name: --l version: -l token: -l computes: -l drives: -l frontends: -l compute-memory: -l data-drives: -l parity-drives: -l baseport: -l management-nic: -l join-ips: "n" "$@")

if [ $? -ne 0 ]; then
    echo "Failed to parse options, use --help for help message."
    exit 1
fi

## Reset the positional parameters to the parsed options
eval set -- "$OPTS"
FLAGS=()

while true; do
    case "$1" in
        -n) DOIT=echo
            FLAGS+=( $1 )
            shift
            ;;

        --help)
            help
            shift
            ;;

        --version)
            WEKA_VERSION=$2
            FLAGS+=( $1 $2 )
            shift 2
            ;;

        --token)
            GET_WEKA_TOKEN=$2
            FLAGS+=( $1 $2 )
            shift 2
            ;;

        --computes)
            NUM_COMPUTE_NODES=$2
            FLAGS+=( $1 $2 )
            shift 2
            ;;

        --drives)
            NUM_DRIVE_NODES=$2
            FLAGS+=( $1 $2 )
            shift 2
            ;;

        --frontends)
            NUM_FRONTEND_NODES=$2
            FLAGS+=( $1 $2 )
            shift 2
            ;;

        --name)
            CLUSTER_NAME=$2
            FLAGS+=( $1 $2 )
            shift 2
            ;;

        --baseport)
            BASEPORT=$2
            FLAGS+=( $1 $2 )
            shift 2
            ;;

        --compute-memory)
            COMPUTE_GB=$2
            FLAGS+=( $1 $2 )
            shift 2
            ;;

        --data-drives)
            DATA_DRIVES=$2
            FLAGS+=( $1 $2 )
            shift 2
            ;;

        --parity-drives)
            PARITY_DRIVES=$2
            FLAGS+=( $1 $2 )
            shift 2
            ;;

        --management-nic)
            MGMT_NIC=$2
            FLAGS+=( $1 $2 )
            shift 2
            ;;

	--join-ips)
	    JOIN_IPS=$2
	    FLAGS+=( $1 $2 )
	    shift 2
	    ;;

        --) shift; break ;;
    esac
done

GET_WEKA_IO=https://${GET_WEKA_TOKEN}:@get.weka.io

# Names of the servers to configure.
# These must be ssh-able.
ARGLIST=( ${@} )

# Strip the servers from the options list
NARGS=${#ARGLIST[@]}

SERVERS="${@:1:5}"
SERVERS="${@}"
## How much we offset each containers port by.
## Must be >= 100.
PORT_OFFSET=200
# Should this be 24GiB ?
COMPUTE_MEMORY="--memory ${COMPUTE_GB}GB"

## Ethernet NICs are "unpredictable" (entirely), but there is a 50/50 split across NUMA nodes.
## It may turn out that because of IB and RDMA, the NUMA awareness matters far less,
## at least until the IB round robin logic is made NUMA aware.
## For now we just use NUMA 0 for drives (because NVMEs are there), NUMA 1 for computes.
## The frontend(s) will use whatever NUMA they are left on.
# Base options we provide for each node type
DRIVES_OPTIONS="--only-drives-cores --cores ${NUM_DRIVE_NODES} --clusterize"
COMPUTE_OPTIONS="$COMPUTE_MEMORY --only-compute-cores --cores ${NUM_COMPUTE_NODES}"
FRONTEND_OPTIONS="$FRONTEND_MEMORY --only-frontend-cores --cores ${NUM_FRONTEND_NODES}"

##
## NO MORE TUNABLES PAST THIS POINT
##

MAX_DRIVE_NODE=$((NUM_DRIVE_NODES - 1))
declare -a DRIVE_NODES=( $(eval echo {0..$MAX_DRIVE_NODE}) )
MAX_COMPUTE_NODE=$((NUM_COMPUTE_NODES - 1))
declare -a COMPUTE_NODES=( $(eval echo {0..$MAX_COMPUTE_NODE}) )
MAX_FRONTEND_NODE=$((NUM_FRONTEND_NODES - 1))
declare -a FRONTEND_NODES=( $(eval echo {0..$MAX_FRONTEND_NODE}) )

## find_slave looks at the NIC passed as $1, and finds the matching slave and returns it.
## The notion of a slave here is an Azure specific thing when using the failsafe PMD.
find_slave() {
	NIC=$1
	echo /sys/class/net/$NIC/lower_eth* | cut -d _ -f2
}

## find_all_nics finds all "master" NICs.
## These are located by looking for a NIC with a slave, and that is type 1 (Ethernet)
find_all_nics() {
	for path in /sys/class/net/*; do
		[[ $path == "/sys/class/net/$MGMT_NIC" ]] && continue
		[ -d ${path}/lower_* ] || continue
		[[ $(cat ${path}/type) == "1" ]] || continue
		echo ${path##*/}
	done
}

## find_numa_nodes evaluates to shell code that defines
## variables for numa nodes.  It has to be done this way because read needs a subshell.
## Just evaluate the result of this.
find_numa_nodes() {
	echo declare -a "NUMA_NODES=();"
	numactl --hardware | grep cpus: | while read node NUM cpus CPUS
        do
                # remove CPU 0 from consideration
                CPUS=${CPUS#0 }
                echo "declare -a NUMA_${NUM}_CORES=( ${CPUS} );"
                echo "declare -a NUMA_${NUM}_NICS=();"
                echo "NUMA_NODES+=( $NUM );"
        done
}

## Install weka version
install_weka() {
	if [ ! -x /usr/bin/weka ]; then
		echo "WEKA agent is not installed."
		curl ${GET_WEKA_IO}/dist/v1/install/${WEKA_VERSION} | bash
	fi

	$DOIT weka version get ${WEKA_VERSION}
	$DOIT weka local stop -f default 2>/dev/null || true
	$DOIT weka local rm -f default 2>/dev/null || true
	$DOIT weka version set ${WEKA_VERSION}
}

## Setup containers runs on the system being configured, and creates
## all the containers locally.
setup_local_containers() {

	install_weka

	# disable numa load balancing
	echo 0 > /proc/sys/kernel/numa_balancing

	# determine our numa nodes
	# We create variables like NUMA_1_CORES=( 48 49 ... )
	eval $(find_numa_nodes)

	HOST=$(hostname)
	if [ -z "${JOIN_IPS}" ]
	then
		JOIN_IPS="${@// /,}"
	fi
	IP=$(ip -br addr show dev $MGMT_NIC | awk '{print $3}' | cut -d/ -f1)
	CLUSTERIZE="--join-ips ${JOIN_IPS}"
	SUFFIX=${HOST##*-}
	PREFIX=${HOST%%-*}
	FDOMAIN=${PREFIX}-${SUFFIX}

	for NIC in $(find_all_nics); do
		NUM=$(cat /sys/class/net/$NIC/device/numa_node)
		case "${NUM}" in
		[0-9]*)
			eval "NUMA_${NUM}_NICS+=( $NIC ) "
			;;
		*)
			echo "Cannot resolve NUMA for $NIC, will not use"
			;;
		esac

		# We don't have source routing, but we don't want these used for routing to
		# the local subnet, so we're going to remove the routes if they exist.
		ip route | grep $NIC | grep "/" | while read netspec devword dev ; do
			case $netspec in
			*/*)
				$DOIT ip route del $netspec dev $NIC
				;;
			*)
				# host specific routes we ignore
				continue
				;;
			esac
		done
	done

	# Get list of NICs sorted by NUMA.  This way containers will at least tend to
	# have NICs in the same NUMA.
	declare -a ALL_NICS
	for NUM in ${NUMA_NODES[@]}; do
		ALL_NICS+=( $( eval echo '${NUMA_'${NUM}'_NICS[@]}' ) )
	done

	OFFSET=0
	# start by creating the drives containers
	CORES=
	NICS=
	for ID in ${DRIVE_NODES[@]}; do
		# pick the next nic in the list
		NIC=${ALL_NICS[0]}
		ALL_NICS=( ${ALL_NICS[@]:1} )

		NUM=$(cat /sys/class/net/$NIC/device/numa_node)
		eval 'CORE=${NUMA_'$NUM'_CORES[0]}'
		eval 'NUMA_'$NUM'_CORES=( ${NUMA_'$NUM'_CORES[@]:1} )'

		SLAVE=$(find_slave $NIC)
		NICS="${SLAVE} ${NICS}"
		CORES="${CORE} ${CORES}"
	done
	NICS="${NICS// /,}"
	NICS="${NICS%,}"
	CORES="${CORES// /,}"
	CORES="${CORES%,}"

	PORT=$(( ${BASEPORT} + ${PORT_OFFSET} * ${OFFSET} ))
	OFFSET=$(( ${OFFSET} + 1 ))
	#FDOMAIN=${HOST}
	OPTIONS="${DRIVES_OPTIONS}"
	echo "CREATING drives0 CONTAINER..."
	$DOIT weka local setup container --name drives0 --base-port ${PORT} --management-net ${MGMT_NIC} ${OPTIONS} --core-ids ${CORES} --failure-domain ${FDOMAIN} --net ${NICS} $CLUSTERIZE

	# computes next, very similar but uses NUMA1 (for balance)
	CORES=
	NICS=
	for ID in ${COMPUTE_NODES[@]}; do

		# pick the next nic in the list
		NIC=${ALL_NICS[0]}
		ALL_NICS=( ${ALL_NICS[@]:1} )

		# pick a core from the same numa
		NUM=$(cat /sys/class/net/$NIC/device/numa_node)
		eval 'CORE=${NUMA_'$NUM'_CORES[0]}'
		eval 'NUMA_'$NUM'_CORES=( ${NUMA_'$NUM'_CORES[@]:1} )'
		SLAVE=$(find_slave $NIC)
		NICS="${SLAVE} ${NICS}"
		CORES="${CORE} ${CORES}"
	done
	NICS=${NICS// /,}
	NICS=${NICS%,}
	CORES=${CORES// /,}
	CORES=${CORES%,}

	PORT=$(( ${BASEPORT} + ${PORT_OFFSET} * ${OFFSET} ))
	OFFSET=$(( ${OFFSET} + 1 ))
	#FDOMAIN=${HOST}
	OPTIONS=${COMPUTE_OPTIONS}
	echo "CREATING compute0 CONTAINER..."
	$DOIT weka local setup container --name compute0 --base-port ${PORT} --management-net ${MGMT_NIC} ${OPTIONS} --core-ids ${CORES} --failure-domain ${FDOMAIN} --net ${NICS} $CLUSTERIZE

	# frontends next, for this we just use whatever NICs are left over
	CORES=
	NICS=
	for ID in ${FRONTEND_NODES[@]}; do
		# NIC first, so we can use the right numa for it
		NIC=${ALL_NICS[0]}
		ALL_NICS=( ${ALL_NICS[@]:1} )

		# pick a core from the same numa
		NUM=$(cat /sys/class/net/$NIC/device/numa_node)
		eval 'CORE=${NUMA_'$NUM'_CORES[0]}'
		eval 'NUMA_'$NUM'_CORES=( ${NUMA_'$NUM'_CORES[@]:1} )'
		SLAVE=$(find_slave $NIC)
		NICS="${SLAVE} ${NICS}"
		CORES="${CORE} ${CORES}"
	done
	NICS=${NICS// /,}
	NICS=${NICS%,}
	CORES=${CORES// /,}
	CORES=${CORES%,}

	PORT=$(( ${BASEPORT} + ${PORT_OFFSET} * ${OFFSET} ))
	OFFSET=$(( ${OFFSET} + 1 ))
	OPTIONS=${FRONTEND_OPTIONS}
	echo "CREATING frontend0 CONTAINER..."
	$DOIT weka local setup container --name frontend0 --base-port ${PORT} --management-net ${MGMT_NIC} ${OPTIONS} --core-ids ${CORES} --failure-domain ${FDOMAIN} --net ${NICS} $CLUSTERIZE

	# Last part; let's add our own NVME drives.
	# We look for a container with our own IP address named drives0, and add our drives to them.

	while true; do
		echo "Waiting for WEKA cluster to form..."
		if $DOIT weka -T 5s status >/dev/null 2>/dev/null; then
			CONTAINER=99999
			$DOIT declare CONTAINER=$(weka -T 5s cluster container --filter container=drives0 --filter ips=$IP --no-header -o id)
			if [[ -z "${CONTAINER}" ]]; then
				# we might not quite be up yet, lets make sure we are...
				echo "Did not get container id... trying again"
				sleep 5
				continue
			fi
			echo "My drives container is $CONTAINER"
			break
		fi
		sleep 5
	done

	lsblk | egrep '^nvme' | while read NVME rest ; do
		echo "Adding NVME drive $NVME to container $CONTAINER"
		$DOIT weka cluster drive add $CONTAINER $NVME || echo "** FAILED ADDING $NVME to CONTAINER $CONTAINER"
	done

	return 0
}

# get the script name
# If its 'setup_containers' then we are running as setup containers.
myname=${0##*/}
myname=${myname%.*}
case $myname in
	setup_containers)
		echo "DOING LOCAL CONTAINER SETUP"
		echo "==========================="
		setup_local_containers $*
		exit $?
		;;
esac

# Servers as a comma separated list
ALL_SERVERS="${SERVERS// /,}"
SERVER=${SERVERS%% *}

if [ -z "${ALL_SERVERS}" ]; then
    echo "Missing required list of servers."
    exit 1
fi

get_join_ips() {
	SERVERS="${@:1:5}"
	SERVERS="${SERVERS// /,}"

	pdsh ${PDSH_MODE} -N -w ${SERVERS}  ip -4 -br addr show dev $MGMT_NIC | while read nic state netaddr others; do
		echo "${netaddr%%/*}:${BASEPORT}"
	done
}

## The rest of this script is run on the "controller" ... this would be replaced eventually by
## having this in instance metadata, but for the POC we simply drive it from a central host.
## One special exception is the bit of adding nvmes and start-io.  Those both need follow up work.
## Determine join IPs.  We pick the first 5 drive nodes, distributing as evenly across servers as we can.


# Get our JOIN IPS from the first five servers, using their NICs
# But only if the environment does not already have them set.
JOIN_IPS="${JOIN_IPS:-$(get_join_ips ${SERVERS})}"

echo "Using JOIN IPs of ${JOIN_IPS}" | tr '\n' ' '
echo

# Master pdsh that starts everything.
pdcp ${PDSH_MODE} -w ${ALL_SERVERS} $0 /tmp/setup_containers.sh
pdsh ${PDSH_MODE} -w ${ALL_SERVERS} sudo bash /tmp/setup_containers.sh ${FLAGS[@]} ${JOIN_IPS[@]}


exit 0 

## SCRIPT below is only for first time setup....

## This would be a good place to add licenses, cluster configuration
$DOIT ssh ${SERVER} sudo weka cluster update \
	--data-drives $DATA_DRIVES \
	--parity-drives $PARITY_DRIVES \
	--cluster-name $CLUSTER_NAME

$DOIT ssh ${SERVER} sudo weka cluster start-io
$DOIT ssh ${SERVER} sudo weka fs group create default

# get the total capacity
CAPACITY=$(ssh ${SERVER} weka status | grep storage | ( read label1 label2 SZ UNITS other ; echo $SZ$UNITS ))

echo "Creating filesystem of $CAPACITY"

$DOIT ssh ${SERVER} sudo weka fs create default default $CAPACITY
# $DOIT ssh 172.16.14.106  sudo mkdir -p /mnt/weka
# insert overrides here
echo "wait 1 minute for containers to come up"
sleep 60
$DOIT ssh ${SERVER} weka debug config override clusterInfo.singleHopWriteEnabled true
pdsh ${PDSH_MODE} -w ${ALL_SERVERS} sudo mkdir /mnt/weka
pdsh ${PDSH_MODE} -w ${ALL_SERVERS} sudo mount -t wekafs default /mnt/weka
pdsh ${PDSH_MODE} -w ${ALL_SERVERS} sudo chmod 777 /mnt/weka
