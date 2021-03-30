#!/bin/bash

influx_server="localhost:8086"


while true
do
#  maskinfo=$(ovs-dpctl show| grep -v port|grep -v system|sed "s/\t//g")
#maskinfo:
#lookups: hit:10362274947 missed:199883 lost:95531 flows: 3 masks: hit:94965047107 total:2 hit/pkt:9.16

  #DPDK
  #netdev@ovs-netdev:
  #  lookups: hit:2792353508 missed:609 lost:0
  #  flows: 275
  #  port 0: ovs-netdev (tap)

  maskinfo=$(ovs-appctl dpctl/show|grep flows|sed "s/ //g"|cut -d ":" -f 2|sed "s/ //g")

  lookuphit=0
  lookupmissed=0
  lookuplost=0

#  flows=$(echo $maskinfo|grep flows|awk '{print $6}')
  flows=$(echo $maskinfo)

  maskshit=0 #$(echo $maskinfo|awk '{print $8}'|cut -d ':' -f 2)
  maskstotal=0 #$(echo $maskinfo|awk '{print $9}'|cut -d ':' -f 2)
  maskshitperpacket=0 #$(echo $maskinfo|grep masks|awk '{print $10}'|cut -d ':' -f 2)

  curl -i -XPOST "http://${influx_server}/write?db=ovs_cache" \
  --data-binary "data,host=localhost lookuphit=$(echo $lookuphit),lookupmissed=$(echo $lookupmissed),lookuplost=$(echo $lookuplost),flows=$(echo $flows),maskshit=$(echo $maskshit),maskstotal=$(echo $maskstotal),maskshitperpacket=$(echo $maskshitperpacket)"

  sleep 1s
done
