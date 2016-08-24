#!/bin/sh

##################################################################################
#
#  Copyright (C) 2016 Craig Miller
#
#  See the file "LICENSE" for information on usage and redistribution
#  of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#  Distributed under GPLv2 License
#
##################################################################################


#
# Script to start tayga (NAT 64) server on OpenWRT
#
# Craig Miller 9 July 2016
#

#
# Define interfaces
#
WAN="eth0.2"

# Define files
tayga_conf="/etc/tayga.conf"


# script version
VERSION=0.92


usage () {
	# show help
	echo "help is here"
	echo "	$0 - sets up tayga.conf, creates tun device, and starts tayga (NAT64)"
	echo "	-w <int>   WAN interface of the router, typically eth1 or eth0.2"
	echo "	-h         this help"
	echo "  "
	echo " By Craig Miller - Version: $VERSION"
	exit 1
}


# check that the WAN interface has been passed in
if [ $# -eq 0 ]; then
	usage
	exit 1
fi


# default options values
DEBUG=0
numopts=0
# get args from CLI
while getopts "?hdw:" options; do
  case $options in
    w ) WAN=$OPTARG
    	numopts=$((numopts+2));;
    d ) DEBUG=1
		numopts=$((numopts+1));;
    h ) usage;;
    \? ) usage	# show usage with flag and no value
         exit 1;;
    * ) usage		# show usage with unknown flag
    	 exit 1;;
  esac
done

# remove the options as cli arguments
shift $((numopts))

# check that there are no arguments left to process
if [ $# -ne 0 ]; then
	usage
	exit 1
fi


echo "=== Check that WAN interface is present and up"
i=0
max=5
result=1
while [ $result -ne 0 ]
do
	i=$((i+1))
	if [ $i -gt $max ]; then 
		echo "=== Is $WAN the correct WAN interface?" 
		# exit the script
		exit 1 
	fi
	
	# is $WAN present and UP?
	ifconfig "$WAN" | grep UP
	result=$?
	
	# sleep if not invoked from terminal
	if [ ! -t 1 ]; then
		sleep 10
	fi
done



# get some IP addresses from Router
LAN_IP6=$(ip addr | grep '::1' | grep global | awk '{print $2}' | cut -f 1 -d '/')
 
WAN_IP4=$(ip addr show dev "$WAN" | grep "inet " | awk '{print $2}' | cut  -f 1 -d '/')

WAN_IP6=$(ip addr show dev eth0.2 | grep "inet6" | grep global | head -1| awk '
{print $2}' | cut  -f 1 -d '/')

echo "=== Collected address info:"
echo "=== WAN4 $WAN_IP4"
echo "=== WAN6 $WAN_IP6"
echo "=== LAN6 $LAN_IP6"

# tayga info from tayga website http://www.litech.org/tayga/

# kill any existing tayga to clean up
killall tayga

# make tayga db dir
mkdir -p /tmp/db/tayga

# create tayga config file
mv $tayga_conf $tayga_conf.old
touch $tayga_conf
echo "tun-device nat64" >> $tayga_conf
echo "ipv4-addr 192.168.2.1 " >> $tayga_conf	 
echo "prefix  64:ff9b::/96  " >> $tayga_conf	 
echo "ipv6-addr $LAN_IP6" >> $tayga_conf
echo "dynamic-pool 192.168.2.0/24" >> $tayga_conf
echo "data-dir /tmp/db/tayga" >> $tayga_conf

if [ $DEBUG -eq 1 ]; then echo "=== tayga.conf file"; cat $tayga_conf; fi

# configure tun interface and start tayga
echo "=== Making tun device: nat64"
tayga --mktun
ip link set nat64 up

ip addr add "$WAN_IP4" dev nat64	   		
ip addr add "$WAN_IP6" dev nat64
ip route add 192.168.2.0/24 dev nat64
ip route add 64:ff9b::/96 dev nat64
tayga &

# test connection
echo "=== Testing tayga"
ping6 -c3 64:ff9b::8.8.4.4

echo "Pau!"


