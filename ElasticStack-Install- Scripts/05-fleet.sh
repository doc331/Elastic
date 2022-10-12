#!/bin/bash
clear
NORMAL='\033[0;39m'
BLUE='\033[1;34m'
GREEN='\033[1;32m'
RED='\033[1;31m'
#debug=$(/dev/null 2>&1)
debug=debug-api-fleet-install.txt
echo -e "$RED"
echo '
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
x                                                                                   x
x                                                                                   x
x   ..::        E L A S T I C - A G E N T - F L E E T - S E R V E R          ::..   x 
x                                                                                   x
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
'
sleep 3
echo -e "$NORMAL"

echo '
THIS IS ELASTIC API AND FLEET SETUP SCRIPT TO INSTALL THE FOLLOWING ...

-> Elastic Trail License

-> Download SIEM Pre-Built Rules

-> Install Fleet Server
- - > Download Elastic-Agent
- - > Config Fleet Server ( Fleet Hostname & Elasticsearch Output )
- - > Create a Fleet Policy and initial Fleet Server
- - > Create other Policy for Elastic Agent
- - > Download Integrations Packs

'

echo -e "$RED *** REQUIREMENTS ***"

echo '

INSTALLED tar jq gzip unzip

'

echo '
	Create certificates for Fleet-Server
	-> Place them on your Ansible Host like this:
	/root/ca.pem 
	/root/http.key
	/root/http.pem 
	
'


echo "PRESS space TO CONTINUE OR ABORT WITH strg + c "
echo -e "$NORMAL"
read -r -s -d ' '

echo "oooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo" 
echo "" 
echo "CREATE CONFIG FILES" 
echo "" 
echo "oooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo" 

echo '-> READ FROM ~/host.ref'
echo '-> READ FROM ~/elastic-user.ref'

source ~/host.ref
source ~/elastic-user.ref

echo "oooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo" 

echo " ELASTIC API " 

echo "oooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo" 

#TRAIL LICENSE
curl --silent -X POST -u elastic:$elastic1 https://$n1.$domain:9200/_license/start_trial?acknowledge=true&pretty
echo ""
echo -e "$GREEN [OK] $NORMAL --> Elastic Trail License active"


#SIEM download Pre-Built Rules
curl --silent -X PUT -u elastic:$elastic1 https://$k1.$domain:5601/api/detection_engine/rules/prepackaged -H 'kbn-xsrf: true'
echo ""
echo -e "$GREEN [OK] $NORMAL --> SIEM Rules loading..."
# FLEET SETUP


echo -e "$RED [RUN] $NORMAL --> Fleet setup initializing ..."
sleep 3
curl --silent -k -u elastic:$elastic1 -XPOST https://$k1.$domain:5601/api/fleet/setup --header 'kbn-xsrf: true'
echo ""
echo -e "$GREEN [OK] $NORMAL"


echo ""
sleep 2
echo -e "$RED [RUN] $NORMAL --> Prepaire Fleet Settings"

curl -k -u elastic:$elastic1 -XPUT https://$k1.$domain:5601/api/fleet/settings \
--header 'kbn-xsrf: true' \
--header 'Content-Type: application/json' \
--data-raw '{"fleet_server_hosts":["https://'$a1.$domain':8220"]}'


curl -X 'PUT' -u elastic:$elastic1  \
  https://$k1.$domain:5601/api/fleet/outputs/fleet-default-output \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -H 'kbn-xsrf: true' \
  -d '{
  "name": "default",
  "type": "elasticsearch",
  "is_default": true,
  "is_default_monitoring": true,
  "hosts": [
    "https://'$n1.$domain':9200","https://'$n2.$domain':9200","https://'$n3.$domain':9200"
  ]  
}'
echo ""
echo -e "$GREEN [OK] $NORMAL"

curl -k -u elastic:$elastic1 https://$k1.$domain:5601/api/fleet/agent_policies?sys_monitoring=true \
--header 'kbn-xsrf: true' \
--header 'Content-Type: application/json' \
--data-raw '{"id":"fleet-server-policy","name":"Fleet Server policy","description":"","namespace":"default","monitoring_enabled":["logs","metrics"],"has_fleet_server":true}'

echo -e "$GREEN [CREATED] $NORMAL --> Fleet Server Policy ready to use"

#Get current version of elasticsearch 

cat <<EOF > fleet-rollout.sh

#!/bin/bash

NORMAL='\033[0;39m'
BLUE='\033[1;34m'
GREEN='\033[1;32m'
RED='\033[1;31m'

esv=\$(curl --silent -u elastic:elastic -XGET 'https://$n1.$domain:9200' | jq .version.number | grep -e "[0-9]" | sed 's/"//g' | sed s/'\s'//g)
echo \$esv

curl -L -O https://artifacts.elastic.co/downloads/beats/elastic-agent/elastic-agent-\$esv-linux-x86_64.tar.gz

tar xzvf > echo elastic-agent-\$esv-linux-x86_64.tar.gz


esdir=\$(ls -d */ | grep elastic-agent-)
cd \$esdir

sleep 3
echo -e "\$RED [RUN] \$NORMAL --> Try to get a service token from Elasticsearch"

ws1=\$(curl -X POST -u elastic:$elastic1 https://$k1.$domain:5601/api/fleet/service_tokens --header 'kbn-xsrf: true')
sleep 5
ws2=\$(echo \$ws1 | cut -c 40-129)
sleep 2
echo \$ws2
sleep 2

echo -e "\$GREEN [OK] \$NORMAL --> got one ... ;-)"
sleep 2

echo -e "\$RED [RUN] \$NORMAL --> start install fleet server ..."

sleep 2

sudo ./elastic-agent install -f --url=https://$k1.$domain:8220 \\
  --fleet-server-es=https://$n1.$domain:9200 \\
  --fleet-server-service-token=\$ws2 \\
  --fleet-server-policy=fleet-server-policy \\
  --certificate-authorities=/root/ca.pem \\
  --fleet-server-es-ca=/root/ca.pem \\
  --fleet-server-cert=/root/http.pem \\
  --fleet-server-cert-key=/root/http.key

EOF

echo -e "\$GREEN [OK] \$NORMAL --> copy certificates"

scp -q ca.pem http.pem http.key root@$k1.$domain:~/

ssh $k1.$domain 'bash -s' < fleet-rollout.sh

echo "...waiting for fleet data..."

sleep 15

ansible -b --become-method=sudo -m shell -a 'elastic-agent status' kibana
ansible -b --become-method=sudo -m shell -a 'elastic-agent version' kibana

echo -e "$GREEN Check Kibana Fleet UI ... $NORMAL"