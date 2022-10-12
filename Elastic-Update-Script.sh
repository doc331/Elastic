### ELASTICSEARCH CLUSTER UPGRADE V1.0 ###

##-> What does this script do

# - Enable ML Upgrade Mode 
# - Flush Index
# - Disable shard allocation
# - Update and restart node by node
# - Wait for unassigned shards
# - Wait till cluster is green and node up
# - Enable shard allocation
# - Disable ML Upgrade Mode
# - For Monitoring purposes use the following linx commands
# curl --silent -XGET -u elastic:$elastic1 https://$n1.$domain:9200/_cluster/health?pretty
# watch "curl --silent -XGET -u elastic:$elastic1 https://$n2.$domain:9200/_cluster/health?pretty | grep -E -i -w 'status|2|3|unassigned_shards'"

clear
NORMAL='\033[0;39m'
BLUE='\033[1;34m'
GREEN='\033[1;32m'
RED='\033[1;31m'
echo -e "$RED"
echo '

xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
x                                                                                   x
x                                                                                   x
x      ..:: E L A S T I C S E A R C H    R O L L I N G    U P D A T E ::..          x 
x                                                                                   x
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

'

sleep 3

echo -e "$NORMAL"

echo '
= = >  REQUIREMENTS:

Involve all elastic nodes for update process ... like this ...

n1=node1
n2=node2
n3=node3
domain=mynet.com

--> and save it to ~/host.ref

ONLY 3 ELASTIC NODES ARE ALLOWED !!!

IMPORTANT: Be shure that you can connect via ssh from jumphost 
           to your Elastic Nodes without password prompt.
		   You can use "sshpass" and "ssh-copy-id" 

WARNING:   Execute this script from your jumphost !

--   EVERY NODE WILL BE REBOOT AUTOMATICALLY AFTER UPDATE FINISHED --
		   
'

echo -e "$RED"
echo "PRESS space TO CONTINUE OR ABORT WITH strg + c "
echo -e "$NORMAL"
read -r -s -d ' '


FILE=~/host.ref
if [ -f "$FILE" ]; then
    echo -e "$GREEN[OK]$NORMAL -> READ FROM ~/host.ref"
	source ~/host.ref
else 
    echo -e "$RED $FILE does not exist. EXIT $NORMAL"
fi

sleep 2

PING1=$(ssh $n1.$domain 'echo 1' | grep 1)
if [[ ${PING1} == "1" ]]; then
      echo -e "$GREEN[OK]$NORMAL -> $n1 is online"
else 
    echo -e "$RED $n1 is not reachable via ssh. EXIT $NORMAL"
fi

PING2=$(ssh $n2.$domain 'echo 1' | grep 1)
if [[ ${PING2} == "1" ]]; then
      echo -e "$GREEN[OK]$NORMAL -> $n2 is online"
else 
    echo -e "$RED $n2 is not reachable via ssh. EXIT $NORMAL"
fi

PING3=$(ssh $n3.$domain 'echo 1' | grep 1)
if [[ ${PING3} == "1" ]]; then
      echo -e "$GREEN[OK]$NORMAL -> $n3 is online"
else 
    echo -e "$RED $n3 is not reachable via ssh. EXIT $NORMAL"
fi

echo ""
echo -e "-> all nodes should be online and reachable via ssh "
echo ""
sleep 3
read -p "ENTER HERE PW FOR USER elastic ->: " elastic1
echo ""
echo ""
#### preparation finish ######################################################################################


dna=$(curl --silent -XGET -u elastic:$elastic1 https://$n1.$domain:9200/_cat/nodes | grep "-" | grep -oE '[^ ]+$')

m1=$(curl --silent -XGET -u elastic:$elastic1 https://$n1.$domain:9200/_cat/nodes | grep "*" | grep -oE '[^ ]+$').$domain
d1=$(echo $dna | grep -Eo '^[^ ]+').$domain
d2=$(echo $dna | grep -oE '[^ ]+$').$domain


echo -e "1st node will be $RED" $d1 "$NORMAL"
echo -e "2nd node will be $RED" $d2 "$NORMAL"
echo -e "at least master node will be $RED" $m1 "$NORMAL"
echo ""
curl --silent -XGET -u elastic:$elastic1 https://$n1.$domain:9200/_cat/nodes
echo ""
echo -e "$RED"
echo "DOUBLE CHECK FOR CORRECT INPUT AND HOST NAMES"
echo ""
echo -e "$NORMAL"
echo "STARTING ELASTIC ROLLING UPDATE"
echo -e "$RED"
echo "PRESS space TO CONTINUE OR ABORT WITH strg + c "
echo -e "$NORMAL"
read -r -s -d ' '
echo ""

#### start update ######################################################################################

#ml
curl --silent -X POST -u elastic:$elastic1 https://$m1:9200/_ml/set_upgrade_mode?enabled=true 2>&1 | grep tuxluv
echo ""
echo -e "$GREEN[OK]$NORMAL -> Set ML to upgrade mode"
curl --silent -X POST -u elastic:$elastic1 https://$m1:9200/_flush?pretty 2>&1 | grep tuxluv
echo ""
echo -e "$GREEN[OK]$NORMAL -> Flushed a data stream or index"

#start update $d1 #################

curl --silent -X PUT -u elastic:$elastic1 https://$m1:9200/_cluster/settings \
  -H "Content-Type: application/json" \
  -d '{"persistent":{"cluster.routing.allocation.enable":"primaries"}}'
echo ""
echo -e "$GREEN[OK]$NORMAL -> Disable shard allocation..."
  
ssh $d1 'systemctl stop elasticsearch.service && yum -y update elasticsearch && reboot'

#-wait for status green
echo ""
while true; do
    NODES=$(curl -u elastic:$elastic1 https://$m1:9200/_cluster/health 2>/dev/null \
      | jq -r '.number_of_data_nodes')
    if [[ ${NODES} == "3" ]]; then
      echo -e "$GREEN[OK]$NORMAL Elasticsearch cluster status has stabilized"
      break
    fi
    echo -e "$RED[WAIT]$NORMAL Data nodes available: ${NODES}, waiting..."
    sleep 5
  done
echo ""
echo "Re-enabling shard allocation"
curl --silent -X PUT -u elastic:$elastic1 https://$m1:9200/_cluster/settings \
  -H "Content-Type: application/json" \
  -d '{"persistent":{"cluster.routing.allocation.enable":null}}'
echo ""

while true; do
    UNASSIGNED=$(curl -u elastic:$elastic1 https://$m1:9200/_cluster/health 2>/dev/null \
      | jq -r '.unassigned_shards')
    if [[ "${UNASSIGNED}" == "0" ]]; then
      echo -e "$GREEN[OK]$NORMAL All shards-reallocated"
      break
    fi
    echo -e "$RED[WAIT]$NORMAL Number of unassigned shards: ${UNASSIGNED}"
    sleep 3
  done
echo ""
while true; do
    STATUS=$(curl -u elastic:$elastic1 https://$m1:9200/_cluster/health 2>/dev/null \
      | jq -r '.status')
    if [[ "${STATUS}" == "green" ]]; then
      echo -e "$GREEN[OK]$NORMAL Cluster health is now ${STATUS}, continuing upgrade..."
      break
    fi
    echo -e "$RED[WAIT]$NORMAL Cluster status: ${STATUS}"
    sleep 3
  done
echo ""
#start update $d2 #################

echo "Disable shard allocation..."
curl --silent -X PUT -u elastic:$elastic1 https://$m1:9200/_cluster/settings \
  -H "Content-Type: application/json" \
  -d '{"persistent":{"cluster.routing.allocation.enable":"primaries"}}'
echo ""
  
ssh $d2 'systemctl stop elasticsearch.service && yum -y update elasticsearch && reboot'
##check left
#-wait for status green
echo ""
while true; do
    NODES=$(curl -u elastic:$elastic1 https://$m1:9200/_cluster/health 2>/dev/null \
      | jq -r '.number_of_data_nodes')
    if [[ ${NODES} == "3" ]]; then
      echo -e "$GREEN[OK]$NORMAL Elasticsearch cluster status has stabilized"
      break
    fi
    echo -e "$RED[WAIT]$NORMAL Data nodes available: ${NODES}, waiting..."
    sleep 5
  done
echo ""
echo "Re-enabling shard allocation"
curl --silent -X PUT -u elastic:$elastic1 https://$m1:9200/_cluster/settings \
  -H "Content-Type: application/json" \
  -d '{"persistent":{"cluster.routing.allocation.enable":null}}'
echo ""

while true; do
    UNASSIGNED=$(curl -u elastic:$elastic1 https://$m1:9200/_cluster/health 2>/dev/null \
      | jq -r '.unassigned_shards')
    if [[ "${UNASSIGNED}" == "0" ]]; then
      echo -e "$GREEN[OK]$NORMAL All shards-reallocated"
      break
    fi
    echo -e "$RED[WAIT]$NORMAL Number of unassigned shards: ${UNASSIGNED}"
    sleep 3
  done
echo ""
while true; do
    STATUS=$(curl -u elastic:$elastic1 https://$m1:9200/_cluster/health 2>/dev/null \
      | jq -r '.status')
    if [[ "${STATUS}" == "green" ]]; then
      echo -e "$GREEN[OK]$NORMAL Cluster health is now ${STATUS}, continuing upgrade..."
      break
    fi
    echo -e "$RED[WAIT]$NORMAL Cluster status: ${STATUS}"
    sleep 3
  done
echo ""
#start update $m1 #################

echo "Disable shard allocation..."
curl --silent -X PUT -u elastic:$elastic1 https://$d1:9200/_cluster/settings \
  -H "Content-Type: application/json" \
  -d '{"persistent":{"cluster.routing.allocation.enable":"primaries"}}'
echo ""
  
ssh $m1 'systemctl stop elasticsearch.service && yum -y update elasticsearch && reboot'
##check left
#-wait for status green
echo ""
while true; do
    NODES=$(curl -u elastic:$elastic1 https://$d1:9200/_cluster/health 2>/dev/null \
      | jq -r '.number_of_data_nodes')
    if [[ ${NODES} == "3" ]]; then
      echo -e "$GREEN[OK]$NORMAL Elasticsearch cluster status has stabilized"
      break
    fi
    echo -e "$RED[WAIT]$NORMAL Data nodes available: ${NODES}, waiting..."
    sleep 5
  done
echo ""
echo "Re-enabling shard allocation"
curl --silent -X PUT -u elastic:$elastic1 https://$d1:9200/_cluster/settings \
  -H "Content-Type: application/json" \
  -d '{"persistent":{"cluster.routing.allocation.enable":null}}'
echo ""

while true; do
    UNASSIGNED=$(curl -u elastic:$elastic1 https://$d1:9200/_cluster/health 2>/dev/null \
      | jq -r '.unassigned_shards')
    if [[ "${UNASSIGNED}" == "0" ]]; then
      echo -e "$GREEN[OK]$NORMAL All shards-reallocated"
      break
    fi
    echo -e "$RED[WAIT]$NORMAL Number of unassigned shards: ${UNASSIGNED}"
    sleep 3
  done
echo ""

while true; do
    STATUS=$(curl -u elastic:$elastic1 https://$d1:9200/_cluster/health 2>/dev/null \
      | jq -r '.status')
    if [[ "${STATUS}" == "green" ]]; then
      echo -e "$GREEN[OK]$NORMAL Cluster health is now ${STATUS}"
      break
    fi
    echo -e "$RED[WAIT]$NORMAL Cluster status: ${STATUS}"
    sleep 3
  done
echo ""
curl --silent -XGET -u elastic:$elastic1 https://$m1:9200/_cluster/health?pretty
echo ""

#ml enable
curl -X POST -u elastic:$elastic1 https://$m1:9200/_ml/set_upgrade_mode?enabled=false
echo ""
echo -e "$GREEN[OK]$NORMAL Exit ML Upgrade Mode"
echo ""
echo -e "$GREEN---CLUSTER UPGRADE DONE---$NORMAL"
echo ""
