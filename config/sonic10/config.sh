#!/bin/bash -e

ip link add sr0 type dummy
ip link set sr0 up
sysctl -w net.vrf.strict_mode=1
sysctl -w net.ipv6.seg6_flowlabel=1
sysctl -w net.ipv6.fib_multipath_hash_policy=3
sysctl -w net.ipv6.fib_multipath_hash_fields=0x0008