#!/bin/bash

#COLORIZING
none='\033[0m'
bold='\033[01m'
disable='\033[02m'
underline='\033[04m'
reverse='\033[07m'
strikethrough='\033[09m'
invisible='\033[08m'

black='\033[30m'
red='\033[31m'
green='\033[32m'
orange='\033[33m'
blue='\033[34m'
purple='\033[35m'
cyan='\033[36m'
lightgrey='\033[37m'
darkgrey='\033[90m'
lightred='\033[91m'
lightgreen='\033[92m'
yellow='\033[93m'
lightblue='\033[94m'
pink='\033[95m'
lightcyan='\033[96m'


function show_help
{
  echo -e "${red}${bold}Arguments not set properly!${none}"
  echo -e "${green}Example: sudo ./victim.sh -d /home/singtel/debian9.qcow2 [-g 1]${none}"
  echo -e "\t\t-d <path>: Path to Drive"
  echo -e "\t\t-n: Net Interface to Use"

  exit
}

function connect_net
{
   ip link del tap1 > /dev/null

  ip tuntap add dev tap1 mode tap
  ifconfig tap1 192.168.101.3 up

  echo 1 > /proc/sys/net/ipv4/ip_forward
  iptables -t nat -A POSTROUTING -o eno1 -j MASQUERADE
  iptables -I FORWARD 1 -i tap1 -j ACCEPT
  iptables -I FORWARD 1 -o tap1 -m state --state RELATED,ESTABLISHED -j ACCEPT
}

NET=0
DRIVE="/home/singtel/debian9-clone.qcow2"
NOGRAPHIC=""
IFNAME=""
while getopts "h?n:g:" opt
do
  case "$opt" in
  h|\?)
    show_help
    ;;
  n)
    NET=$OPTARG
    ;;
  g)
   NOGRAPHIC="--nographic"
    ;;
  *)
    show_help
   ;;
  esac
done

if [[ "$DRIVE" == "" ]]
then
  show_help
  echo -e "${red} Drive Path Not Set${none}"
fi

if [[ "$NET" -ne "" ]]
then
  echo -ne "${yellow}Creating Tunnel for Internet Access ${none}"
  connect_net
  echo -e "\t\t${bold}${green}[DONE]${none}"
  IFNAME="-net nic -net tap,ifname=tap1,script=no"
fi


qemu-system-x86_64 -m 1024 -smp 4 -cpu host -drive file=${DRIVE},index=0,media=disk -boot c -enable-kvm -no-reboot -net none ${NOGRAPHIC} \
-chardev socket,id=char1,path=/usr/local/var/run/openvswitch/vhost-attacker \
-netdev type=vhost-user,id=mynet1,chardev=char1,vhostforce \
-device virtio-net-pci,mac=00:00:00:00:00:01,netdev=mynet1 \
$IFNAME \
-object memory-backend-file,id=mem,size=1G,mem-path=/dev/hugepages,share=on \
-numa node,memdev=mem -m 1024 -mem-prealloc -name attacker
