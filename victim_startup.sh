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
  echo -e "${green}Example: sudo ./victim_startup.sh [-n 1]${none}"
  echo -e "\t\t-d <path>: Path to Drive"
  echo -e "\t\t-n: Net Interface to Use"

  exit
}


NET=""
OVS_PORT="ens4"
NET_PORT=""

while getopts "h?n:" opt
do
  case "$opt" in
  h|\?)
    show_help
    ;;
  n)
    NET=$OPTARG
    ;;
  *)
    show_help
   ;;
  esac
done

if [[ "$NET" -ne "" ]]
then
    
    NET_PORT="ens3"
    OVS_PORT="ens4"

    echo -ne "${yellow}SETTING UP PORTS FOR INTERNET ACCESS ${none}"
    ifconfig ${NET_PORT} 192.168.100.2/24 up
    route add default gw 192.168.100.1 dev ens3
    echo "nameserver 8.8.8.8" > /etc/resolv.conf
    echo -e "\t\t${bold}${green}[DONE]${none}"
fi

echo -ne "${yellow}SETTING UP OVS PORT ${none}"
ifconfig ${OVS_PORT} 10.1.1.2/24 up
echo -e "\t\t${bold}${green}[DONE]${none}"