#!/bin/bash
#set here which binaries you want to use!
OVS_PATH_SET=1 #if set to 0, then /usr/[local]/bin/ binaries will be used
OVS_MODULE_NAME="openvswitch"

# ALWAYS USE MODPROBE INSTEAD OF INSMOD
# IF YOU DO NOT KNOW HOW TO INSTALL A KERNEL MODULE THAT DOES NOT OVERWRITE YOUR CURRENT ONE
# CHECK THE INFO FILE IN THIS REPOSITORY sign_and_use_ovs_module.info!

OVS_PATH="/home/lele/ovs"
OVSDB_PATH="${OVS_PATH}/ovsdb"
OVSVSWITCHD_PATH="${OVS_PATH}/vswitchd"
OVSUTILITIES_PATH="${OVS_PATH}/utilities"
OVS_MODPATH="${OVS_PATH}/datapath/linux/openvswitch.ko"

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
  echo -e "${green}Example: sudo ./start_ovs.sh -n ovsbr ${none}"
  echo -e "\t\t-n <name>: name of the OVS bridge"
  echo -e "\t\t-d <path_to_db.sock>: Path where db.sock will be created!"
  echo -e "\t\t-a <val>: To Add Vhost ports to bridge"
  exit
}

DBR=""
ADD_PORT=""
cores="1"
while getopts "h?n:d:a" opt
do
  case "$opt" in
  h|\?)
    show_help
    ;;
  n)
    DBR=$OPTARG
    ;;
  d)
   DB_SOCK=$OPTARG
    ;;
  a)
    ADD_PORT=1
    ;;
  *)
    show_help
   ;;
  esac
done

if [[ "$DBR" == "" ]]
then
  show_help
fi

if [[ "$DB_SOCK" == "" ]]
then
  echo -e "${yellow}No DB_SOCK has been set, using defaults (/usr/local/var/run/openvswitch/db.sock)${none}"
  DB_SOCK=/usr/local/var/run/openvswitch
fi

mkdir -p $DB_SOCK
DB_SOCK="${DB_SOCK}/db.sock"


ptcp_port=16633
#echo -ne "${yellow}Adding OVS kernel module${none}"
#sudo modprobe $OVS_MODULE_NAME 2>&1

#echo -e "\t\t${bold}${green}[DONE]${none}"


echo -ne "${yellow}Delete preconfigured ovs data${none}"
if [ $OVS_PATH_SET -eq 0 ]
then
  sudo rm -rf /etc/openvswitch/conf.db 2>&1
else
  sudo rm -rf /usr/local/etc/openvswitch/conf.db 2>&1
fi
echo -e "\t\t${bold}${green}[DONE]${none}"

if [ $OVS_PATH_SET -eq 0 ]
then
  sudo mkdir -p /etc/openvswitch/
else
  sudo mkdir -p /usr/local/etc/openvswitch/
fi

echo -ne "${yellow}Create ovs database structure${none}"
if [ $OVS_PATH_SET -eq 0 ]
then
  sudo ovsdb-tool create /etc/openvswitch/conf.db  /usr/share/openvswitch/vswitch.ovsschema
else
  sudo $OVSDB_PATH/ovsdb-tool create /usr/local/etc/openvswitch/conf.db  $OVSVSWITCHD_PATH/vswitch.ovsschema
fi

echo -e "\t\t${bold}${green}[DONE]${none}"

if [ $OVS_PATH_SET -eq 0 ]
then
  sudo mkdir -p /var/run/openvswitch
else
  sudo mkdir -p /usr/local/var/run/openvswitch
fi

echo -ne "${yellow}Start ovsdb-server...${none}"
if [ $OVS_PATH_SET -eq 0 ]
then
  sudo ovsdb-server --remote=punix:$DB_SOCK --remote=db:Open_vSwitch,Open_vSwitch,manager_options --pidfile --detach
else
  sudo $OVSDB_PATH/ovsdb-server --remote=punix:$DB_SOCK --remote=db:Open_vSwitch,Open_vSwitch,manager_options --pidfile --detach
fi
echo -e "\t\t${bold}${green}[DONE]${none}"

echo -e "${bold}${yellow}DPDK SETUP${none}"
#Check out first which cores have you isolated for OVS/DPDK in your GRUB cmd command
#example: https://fast.dpdk.org/doc/perf/DPDK_19_08_Mellanox_NIC_performance_report.pdf
#isolcpus=12-19 intel_idle.max_cstate=0 processor.max_cstate=0 nohz_full=12-19 rcu_nocbs=12-19 intel_pstate=disable
#default_hugepagesz=1G hugepagesz=1G hugepages=24 audit=0 nosoftlockup intel_iommu=on iommu=pt rcu_nocb_poll
#coremap for our 20 core system:
# 19 18 17 16 | 15 14 13 12 | 11 10 9 8 | 7 6 5 4 | 3 2 1 0
# we use up to the topmost 8 cores, but now use only core 15 14 13 for DP, and 12 for handler/revalidator
# 0  0  0  0  | 1  1  1  1  |  0  0 0 0 | 0 0 0 0 | 0 0 0 0

#set first some parameters to DPDK
#hugepages: this MUST be set before dpdk-init
echo -ne "${blue}Hugepages (8G) on the first NUMA node...${none}"
ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-socket-mem="8192,0"
echo -e "${green}\t\t[DONE]${none}"


#We need to set which cores will be handlers and revalidators, i.e., non-DP threads for DPDK
#This MUST NOT overlap with DP cores (see below), let's choose core no. 12.
#This MUST be set before dpdk-init
echo -ne "${blue}Pin handler and revalidator thread to core 12...${none}"
ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-lcore-mask=0x01000
echo -e "${green}\t\t[DONE]${none}"


#initialize DPDK
echo -ne "${blue}Init DPDK...${none}"
ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-init=true
echo -e "${green}\t\t[DONE]${none}"


#this is for the Datapath (DP) - can be set at any given time, so set it now
#we want to use 3 cores for DP, namely core no 13,14,15 so the mask is 0x0e000
echo -ne "${blue}Pin datapath cores to core 13,14,15...${none}"
ovs-vsctl --no-wait set Open_vSwitch . other_config:pmd-cpu-mask=0x02000
echo -e "${green}\t\t[DONE]${none}"


echo -e "Initializing..."
if [ $OVS_PATH_SET -eq 0 ]
then
  sudo ovs-vsctl --no-wait init
else
  sudo $OVSUTILITIES_PATH/ovs-vsctl --no-wait init
fi


# CAN NOW BE SET AS RUNTIME ARGUMENT
#echo -ne "${yellow}exporting environmental variable DB_SOCK${none}"
#if [ $OVS_PATH_SET -eq 0 ]
#then
#  export DB_SOCK=/var/run/openvswitch/db.sock
#else
#  export DB_SOCK=/usr/local/var/run/openvswitch/db.sock
#fi
#echo -e "${bold}${green}\t\t[DONE]${none}"

echo -ne "${yellow}start vswitchd...${none}"
if [ $OVS_PATH_SET -eq 0 ]
then
  sudo ovs-vswitchd unix:$DB_SOCK --pidfile --detach
else
  sudo $OVSVSWITCHD_PATH/ovs-vswitchd unix:$DB_SOCK --pidfile --detach
fi
echo -e "${bold}${green}\t\t[DONE]${none}"


echo -ne "${yellow}Create bridge (${DBR})${none}"
if [ $OVS_PATH_SET -eq 0 ]
then
  sudo ovs-vsctl add-br $DBR -- set bridge $DBR datapath_type=netdev
else
  sudo $OVSUTILITIES_PATH/ovs-vsctl add-br $DBR -- set bridge $DBR datapath_type=netdev
fi



echo -ne "${yellow}Adding Mellanox ConnectX5 PHY port to ${DBR}${none}"
if [ $OVS_PATH_SET -eq 0 ]
then
  sudo ovs-vsctl add-port ovsbr dpdk0 -- set Interface dpdk0 type=dpdk options:dpdk-devargs=0000:b3:00.0
else
  sudo $OVSUTILITIES_PATH/ovs-vsctl add-port ovsbr dpdk0 -- set Interface dpdk0 type=dpdk options:dpdk-devargs=0000:b3:00.0
fi

echo -e "${bold}${green}\t\t[DONE]${none}"

echo -ne "${yellow}Deleting flow rules from ${DBR}${none}"
if [ $OVS_PATH_SET -eq 0 ]
then
  sudo ovs-ofctl del-flows $DBR
else
  sudo $OVSUTILITIES_PATH/ovs-ofctl del-flows $DBR
fi
echo -e "${bold}${green}\t\t[DONE]${none}"


echo -ne "${yellow}Add passive controller listener port on ${ptcp_port}${none}"
if [ $OVS_PATH_SET -eq 0 ]
then
  sudo ovs-vsctl set-controller $DBR ptcp:$ptcp_port
else
  sudo $OVSUTILITIES_PATH/ovs-vsctl set-controller $DBR ptcp:$ptcp_port
fi
echo -e "\t\t${bold}${green}[DONE]${none}"


echo -e "Assigning RX queues to ports"
if [ $OVS_PATH_SET -eq 0 ]
then
  sudo ovs-vsctl set interface dpdk0 options:n_rxq=${cores}
else
  sudo $OVSUTILITIES_PATH/ovs-vsctl set interface dpdk0 options:n_rxq=${cores}
fi

if [[ "$ADD_PORT" -ne "" ]]
then
    echo -ne "${yellow}Adding Ports to ${DBR}"
    ovs-vsctl add-port ovsbr vhost-attacker -- set Interface vhost-attacker type=dpdkvhostuser
    ovs-vsctl add-port ovsbr vhost-victim -- set Interface vhost-victim type=dpdkvhostuser
    echo -e "\t\t${bold}${green}[DONE]${none}"
fi

echo -e "OVS (${DBR}) has been fired up!"
if [ $OVS_PATH_SET -eq 0 ]
then
  sudo ovs-vsctl show
else
  sudo $OVSUTILITIES_PATH/ovs-vsctl show
fi


echo -e "${none}"
echo -ne "${yello}DPDK Status : ${none}"
echo -e "\t\t${green}$(ovs-vsctl get Open_vSwitch . dpdk_initialize)${none}"
echo -e "${yello}DPDK Version : ${none}"
echo -e "${green}$(ovs-vswitchd --version)${none}"

#for some reason, it is good have the following setting, otherwise virsh returns with an error
sudo chmod 777 /usr/local/var/run/openvswitch/vhost-*


# ovs-vsctl add-port ovsbr vhost-attacker -- set Interface vhost-attacker type=dpdkvhostuser
# ovs-vsctl add-port ovsbr vhost-victim -- set Interface vhost-victim type=dpdkvhostuser

