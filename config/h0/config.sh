#!/bin/bash -e

apt-get install -y tcpdump
apt-get install -y iperf

ip addr add 2001:db8:0::1/64 dev eth1

ip -6 route add default via 2001:db8:0::2