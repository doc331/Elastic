#!/bin/bash
clear
NORMAL='\033[0;39m'
BLUE='\033[1;34m'
GREEN='\033[1;32m'
RED='\033[1;31m'
#debug=$(/dev/null 2>&1)
debug=debug-metricbeat-install.txt
echo -e "$RED"
echo '
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
x                                                                                   x
x                                                                                   x
x   ..::                        M E T R I C B E A T                          ::..   x 
x                                                                                   x
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
'
sleep 3
echo -e "$NORMAL"

echo '
THIS INSTALLATION IS SUCCESSFULLY TEST WITH THE FOLLOWING CIRCUMSTANCES 
'
sleep 1
echo '
<==>REQUIREMENTS: 5 HOSTS ( 1x KIBANA    3x ELASTICSEARCH NODES    1x JUMPHOST ANSIBLE )'
echo '
--> OS: ROCKY LINUX >8.5'
echo '
--> A FRESH INSTALLED ROCKY LINUX OS (Minimal installation)'
echo -e "$RED"
echo '
--> IMPORTANT ! EXECUTE THIS SCRIPT FROM JUMPHOST'
sleep 5
echo -e "$NORMAL"
echo '
--> PACKEGES GET INSTALLED :'

echo '
	
	metricbeat
	
'

echo '
	Create certificates for Kibana, Elasticsearch ( HTTP ), Fleet-Server, Nginx and SSO SAML (Optional)
	-> Place them on your Ansible Host like this:
	/root/ca.pem ( ROOT CA and Sub CA )
	/root/http.key ( NGINX, KIBANA and Elasticsearch ( HTTP ) )
	/root/http.pem ( NGINX, KIBANA and Elasticsearch ( HTTP ) )
	/root/fs.crt ( SAML Signing Request ) (Optional)
	/root/fs.key ( SAML Signing Request ) (Optional)
	
	Elasticsearch TLS (CA, Cert and Key ) will be create by this script also xpack encryptionKey !
	
'

echo -e "$RED"
echo "PRESS space TO CONTINUE OR ABORT WITH strg + c "
echo -e "$NORMAL"
read -r -s -d ' '
echo '
--> INSTALL
'
echo "oooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo" 
echo "" 
echo "CREATE CONFIG FILES" 
echo "" 
echo "oooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo" 

echo '-> READ FROM ~/host.ref'
echo '-> READ FROM ~/elastic-user.ref'

source ~/host.ref
source ~/elastic-user.ref

echo '-> CREATE kibana-xpack.yml'

cat <<EOF >> kibana-xpack.yml
- module: kibana
  metricsets:
    - stats
    - status
  period: 30s
  #basepath: ""
  username: "remote_monitoring_user"
  password: "$remote1"
  xpack.enabled: true
  ssl.enabled: true
  ssl.certificate_authorities: ["/etc/metricbeat/security/ca.pem"]
  hosts: ["https://$k1.$domain:5601"]
EOF

#echo '  hosts: ["https://'$k1.$domain':5601"]' >> kibana-xpack.yml

echo '-> CREATE metricbeat.yml'

cat <<EOF >> metricbeat.yml
metricbeat.config.modules:
  path: \${path.config}/modules.d/*.yml

  reload.enabled: false

setup.template.settings:
  index.number_of_shards: 1
  index.codec: best_compression

processors:
  - add_host_metadata: ~
  - add_cloud_metadata: ~
  - add_docker_metadata: ~
  - add_kubernetes_metadata: ~

logging.to_files: true
logging.files:
  path: /var/log/metricbeat
  name: metricbeat
  rotateeverybytes: 10485760
  keepfiles: 7
  permissions: 0600
  interval: 24h
  rotateonstartup: true

#monitoring.enabled: true

setup.kibana:
  host: "https://$k1.$domain:5601"

output.elasticsearch:
  hosts: ["https://$n1.$domain:9200","https://$n2.$domain:9200","https://$n3.$domain:9200"]
  username: "elastic"
  password: "$elastic1"

EOF

#echo output.elasticsearch: >> metricbeat.yml
#echo '  hosts: ["https://'$n1.$domain':9200","https://'$n2.$domain':9200","https://'$n3.$domain':9200"]' >> metricbeat.yml
#echo '  username: "elastic"' >> metricbeat.yml
#echo '  password: "\$elastic1"' >> metricbeat.yml

#echo setup.kibana: >> metricbeat.yml
#echo '  host: "https://'$k1.$domain':5601"' >> metricbeat.yml

echo '-> CREATE elasticsearch-xpack.yml'

cat <<EOF >> elasticsearch-xpack.yml
- module: elasticsearch
  metricsets:
    - node
    - node_stats
  xpack.enabled: true
  period: 30s
  username: "remote_monitoring_user"
  password: "$remote1"
  #scope: node
  ssl.enabled: true
  ssl.certificate_authorities: ["/etc/metricbeat/security/ca.pem"]
  #ssl.certificate: "/etc/pki/client/cert.pem"
  #ssl.key: "/etc/pki/client/cert.key"
  #ssl.verification_mode: "full"
  hosts: ["https://$n1.$domain:9200","https://$n2.$domain:9200","https://$n3.$domain:9200"]


EOF

#echo '  hosts: ["https://'$n1.$domain':9200","https://'$n2.$domain':9200","https://'$n3.$domain':9200"]' >> elasticsearch-xpack.yml


echo "oooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo" 
echo "" 
echo "INSTALL METRICBEAT AND COPY CONFIG FILES" 
echo "" 
echo "oooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo"

scp -q metricbeat.yml kibana-xpack.yml root@$k1.$domain:~/
scp -q metricbeat.yml elasticsearch-xpack.yml root@$n1.$domain:~/
scp -q metricbeat.yml elasticsearch-xpack.yml root@$n2.$domain:~/
scp -q metricbeat.yml elasticsearch-xpack.yml root@$n3.$domain:~/
sleep 2
ansible -b --become-method=sudo -m shell -a 'yum -y install metricbeat' elkhosts >> $debug
sleep 2
ansible -b --become-method=sudo -m shell -a 'sudo metricbeat modules disable system && sudo metricbeat modules enable elasticsearch-xpack' nodes >> $debug
sleep 2
ansible -b --become-method=sudo -m shell -a 'sudo metricbeat modules disable system && sudo metricbeat modules enable kibana-xpack' kibana >> $debug
sleep 2
ansible -b --become-method=sudo -m shell -a 'mkdir /etc/metricbeat/security' elkhosts >> $debug
sleep 2
ansible -b --become-method=sudo -m shell -a 'cp ~/ca.pem /etc/metricbeat/security/' elkhosts >> $debug
sleep 2
ansible -b --become-method=sudo -m shell -a 'cp metricbeat.yml /etc/metricbeat/metricbeat.yml' elkhosts >> $debug
sleep 2
ansible -b --become-method=sudo -m shell -a 'cp elasticsearch-xpack.yml /etc/metricbeat/modules.d/elasticsearch-xpack.yml' nodes >> $debug
sleep 2
ansible -b --become-method=sudo -m shell -a 'cp kibana-xpack.yml /etc/metricbeat/modules.d/kibana-xpack.yml' kibana >> $debug
sleep 2
ansible -b --become-method=sudo -m shell -a 'systemctl enable --now metricbeat' elkhosts >> $debug
sleep 2
ansible -b --become-method=sudo -m shell -a 'systemctl restart metricbeat' elkhosts >> $debug

echo 'FIN'
