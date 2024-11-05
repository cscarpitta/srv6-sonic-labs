#!/bin/bash -e

modprobe vrf

docker image pull cscarpit/debian:latest
docker image pull cscarpit/srv6-sonic-vs:latest

function remove_sonic_switch {
    SWNAME=$1

    docker stop sw-$SWNAME && docker rm sw-$SWNAME
    docker stop $SWNAME && docker rm $SWNAME

    for srv in `seq 0 31`; do

        SRV="$SWNAME-srv$srv"

        ip netns del $SRV

    done
}

function create_sonic_switch {
    SWNAME=$1

    docker run --privileged -id --name sw-$SWNAME --hostname $SWNAME debian bash
}

function start_sonic_switch {
    SWNAME=$1

    docker run --privileged -v /var/run/redis-vs/$SWNAME:/var/run/redis -v ${PWD}/config/$SWNAME/config_db.json:/usr/share/sonic/virtual_chassis/default_config.json -v ${PWD}/config/$SWNAME/frr.conf:/etc/frr/frr.conf --network container:sw-$SWNAME -d --name $SWNAME cscarpit/srv6-sonic-vs:latest
}

function create_neighbor {
    SWNAME=$1
    IDX=$2

    pid=$(docker inspect --format '{{.State.Pid}}' sw-$SWNAME)

    srv=$IDX
    SRV="$SWNAME-srv$srv"

    NSS="ip netns exec $SRV"

    ip netns add $SRV

    $NSS ip addr add 127.0.0.1/8 dev lo
    $NSS ip addr add ::1/128 dev lo
    $NSS ip link set dev lo up

    # add virtual link between neighbor and the virtual switch docker

    IF="eth$((srv+1))"

    ip link add ${SRV} type veth peer name $SWNAME-$IF
    ip link set ${SRV} netns $SRV
    ip link set $SWNAME-$IF netns ${pid}
    nsenter -t $pid -n ip link set dev $SWNAME-$IF name $IF

    echo "Bring ${SRV} up"
    $NSS ip link set dev ${SRV} name eth0
    $NSS ip link set dev eth0 up

    echo "Bring $IF up in the virtual switch docker"
    nsenter -t $pid -n ip link set dev $IF up

}

function create_link {
    SW1NAME=$1
    SW2NAME=$2
    SW1LINKNAME=$3
    SW2LINKNAME=$4

    pid1=$(docker inspect --format '{{.State.Pid}}' sw-$SW1NAME)
    pid2=$(docker inspect --format '{{.State.Pid}}' sw-$SW2NAME)


    IF="eth$((link+1))"

    ip link add $SW1NAME-$IF type veth peer name $SW2NAME-$IF
    ip link set $SW1NAME-$IF netns $pid1
    ip link set $SW2NAME-$IF netns $pid2
    nsenter -t $pid1 -n ip link set dev $SW1NAME-$IF name $SW1LINKNAME
    nsenter -t $pid2 -n ip link set dev $SW2NAME-$IF name $SW2LINKNAME

    echo "Bring $IF up in the virtual switch docker"
    nsenter -t $pid1 -n ip link set dev $SW1LINKNAME up
    nsenter -t $pid2 -n ip link set dev $SW2LINKNAME up

}

function create_link_host {
    SW1NAME=$1
    SW2NAME=$2
    SW1LINKNAME=$3
    SW2LINKNAME=$4

    pid1=$(docker inspect --format '{{.State.Pid}}' $SW1NAME)
    pid2=$(docker inspect --format '{{.State.Pid}}' sw-$SW2NAME)


    IF="eth$((link+1))"

    ip link add $SW1NAME-$IF type veth peer name $SW2NAME-$IF
    ip link set $SW1NAME-$IF netns $pid1
    ip link set $SW2NAME-$IF netns $pid2
    nsenter -t $pid1 -n ip link set dev $SW1NAME-$IF name $SW1LINKNAME
    nsenter -t $pid2 -n ip link set dev $SW2NAME-$IF name $SW2LINKNAME

    echo "Bring $IF up in the virtual switch docker"
    nsenter -t $pid1 -n ip link set dev $SW1LINKNAME up
    nsenter -t $pid2 -n ip link set dev $SW2LINKNAME up

}

function create_host {
    SWNAME=$1

    docker run --privileged -id --name $SWNAME --hostname $SWNAME cscarpit/debian bash
}

function remove_host {
    SWNAME=$1

    docker stop $SWNAME && docker rm $SWNAME
}

function configure_host {
    SWNAME=$1

    pid=$(docker inspect --format '{{.State.Pid}}' $SWNAME)
    nsenter -t $pid -n bash config/$SWNAME/config.sh
}

function configure_sonic_switch {
    SWNAME=$1

    pid=$(docker inspect --format '{{.State.Pid}}' sw-$SWNAME)
    nsenter -t $pid -n bash config/$SWNAME/config.sh
}

remove_sonic_switch sonic10
remove_sonic_switch sonic20
remove_sonic_switch sonic21
remove_sonic_switch sonic11
remove_sonic_switch a0
remove_sonic_switch a1
remove_host h0
remove_host h1

# create sonic10
create_sonic_switch sonic10
for idx in `seq 5 31`; do
    create_neighbor sonic10 $idx
done

# create sonic20
create_sonic_switch sonic20
for idx in `seq 4 31`; do
    create_neighbor sonic20 $idx
done

# create sonic21
create_sonic_switch sonic21
for idx in `seq 4 31`; do
    create_neighbor sonic21 $idx
done

# create sonic11
create_sonic_switch sonic11
for idx in `seq 5 31`; do
    create_neighbor sonic11 $idx
done

# create a0
create_sonic_switch a0
for idx in `seq 2 31`; do
    create_neighbor a0 $idx
done

# create a1
create_sonic_switch a1
for idx in `seq 2 31`; do
    create_neighbor a1 $idx
done

create_host h0
create_host h1

# create links
create_link sonic20 sonic10 eth1 eth1
create_link sonic20 sonic10 eth2 eth2
create_link sonic20 sonic11 eth3 eth1
create_link sonic20 sonic11 eth4 eth2
create_link sonic21 sonic10 eth1 eth3
create_link sonic21 sonic10 eth2 eth4
create_link sonic21 sonic11 eth3 eth3
create_link sonic21 sonic11 eth4 eth4
create_link sonic10 a0 eth5 eth1
create_link sonic11 a1 eth5 eth1
create_link_host h0 a0 eth1 eth2
create_link_host h1 a1 eth1 eth2

# run sonic
start_sonic_switch sonic10
start_sonic_switch sonic20
start_sonic_switch sonic21
start_sonic_switch sonic11
start_sonic_switch a0
start_sonic_switch a1

# configure nodes
configure_sonic_switch sonic10
configure_sonic_switch sonic11
configure_sonic_switch sonic20
configure_sonic_switch sonic21
configure_sonic_switch a0
configure_sonic_switch a1

configure_host h0
configure_host h1