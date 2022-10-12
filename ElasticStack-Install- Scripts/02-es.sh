#!/bin/bash
clear
NORMAL='\033[0;39m'
BLUE='\033[1;34m'
GREEN='\033[1;32m'
RED='\033[1;31m'
#debug=$(/dev/null 2>&1)
debug=debug-es-install.txt
echo -e "$RED"
echo '

xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
x                                                                                   x
x                                                                                   x
x        ..:: E L A S T I C S E A R C H   I N S T A L L A T I O N ::..              x 
x                                                                                   x
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

'
sleep 3
echo -e "$NORMAL"

echo '
THIS INSTALLATION IS SUCCESSFULLY TEST WITH THE FOLLOWING CIRCUMSTANCES 

5 HOSTS ( 1x KIBANA    3x ELASTICSEARCH NODES    1x JUMPHOST for SSH & ANSIBLE)
OS: ROCKY LINUX >8.6

= = >  REQUIREMENTS:
Involve all elastic nodes for this process ... like this ...

n1=node1
n2=node2
n3=node3
k1=kibana
domain=mynet.com
a1=kibana-alias

--> and save it to ~/host.ref

IMPORTANT: Be shure that you can connect via ssh from jumphost 
           to your Elastic Nodes without password prompt.
		   You can use "sshpass" and "ssh-copy-id" 
		   
WARNING:   Execute this script from your jumphost !
		   
'
sleep 3

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

#Cert Check

CAFILE=/root/ca.pem
CERTFILE=/root/http.pem
KEYFILE=/root/http.key

if [[ -f "$CAFILE" ]] && [[ -f "$CERTFILE" ]] && [[ -f "$KEYFILE" ]]; then
echo -e "$GREEN [OK]--> Certificate Files exists $NORMAL"
else
echo -e "$RED CERTIFICATE FILES DOES NOT EXIST--> FILES NOT FOUND $NORMAL"
exit 1
fi
if [[ $(openssl verify -CAfile ca.pem http.pem | grep 'OK') = *OK* ]]; then
  echo -e "$GREEN [OK]--> ca.pem and http.pem matched $NORMAL"
else
echo -e "$RED CERTIFICATE FILES DOES EXIST, BUT NOT BELONGS TO EACH OTHER $NORMAL"
exit 1
fi


echo '
--> INSTALL
'
echo "oooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo" 
echo "" 
echo "CREATE CONFIG FILES" 
echo "" 
echo "oooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo" 

echo '-> READ FROM ~/host.ref'

source ~/host.ref

echo '-> Elasticsearch Repository'

echo '
[elasticsearch]
name=Elasticsearch repository for 8.x packages
baseurl=https://artifacts.elastic.co/packages/8.x/yum
gpgcheck=0
gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
enabled=1
autorefresh=1
type=rpm-md' > elasticsearch.repo

echo '-> Elasticsearch TLS Certificate (STACK COMMUNICATION)'

openssl req -nodes -x509 -days 1825 -newkey rsa:4096 -keyout ca.key -out ca.crt -subj "/C=DE/ST=BY/L=Town/O=it/OU=IT/CN=`hostname -f`/emailAddress=root@mynet.de" > /dev/null 2>&1
openssl req -nodes -newkey rsa:2048 -keyout server.key -out server.csr -subj "/C=DE/ST=BY/L=Town/O=it/OU=IT/CN=`hostname -f`/emailAddress=root@mynet.de" > /dev/null 2>&1
openssl x509 -req -days 1824 -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt > /dev/null 2>&1
openssl pkcs12 -nodes -export -inkey server.key -in server.crt -certfile ca.crt -out stack.p12 -passout pass:

echo '-> Elasticsearch HTTPS Certificate (CLIENT COMMUNICATION)'

openssl pkcs12 -nodes -export -out es.p12 -inkey http.key -in http.pem -certfile ca.pem -passout pass:

echo '-> CREATE elasticsearch.yml'

echo '
cluster.name: cluster
node.name: ${HOSTNAME}
network.host: 0.0.0.0
http.port: 9200

xpack.security.enabled: true
xpack.security.transport.ssl.enabled: true
xpack.security.transport.ssl.verification_mode: certificate
xpack.security.transport.ssl.keystore.path: security/stack.p12
#xpack.security.transport.ssl.truststore.path: security/stack.p12
xpack.security.transport.ssl.certificate_authorities: [ "/etc/elasticsearch/security/ca.crt" ]

xpack.security.http.ssl.enabled: true
xpack.security.http.ssl.keystore.path: security/es.p12
#xpack.security.http.ssl.truststore.path: security/es.p12
xpack.security.http.ssl.certificate_authorities: [ "/etc/elasticsearch/security/ca.pem" ]
xpack.security.http.ssl.verification_mode: certificate
xpack.security.authc.api_key.enabled: true

xpack.monitoring.elasticsearch.collection.enabled: false
xpack.monitoring.collection.enabled: true

#path.repo: /backup

path.data: /var/lib/elasticsearch
path.logs: /var/log/elasticsearch' > ~/elasticsearch.yml


echo cluster.initial_master_nodes: "\"$n1,$n2,$n3"\" >> ~/elasticsearch.yml
echo discovery.seed_hosts: "\"$n1:9300,$n2:9300,$n3:9300"\" >> ~/elasticsearch.yml

echo "oooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo" 
echo "" 
echo "COPY REPO AND INSTALL ELASTICSEARCH" 
echo "" 
echo "oooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo" 
echo '-> Copy Elasticsearch Repository'
scp -q elasticsearch.repo root@$n1.$domain:/etc/yum.repos.d/elasticsearch.repo
scp -q elasticsearch.repo root@$n2.$domain:/etc/yum.repos.d/elasticsearch.repo
scp -q elasticsearch.repo root@$n3.$domain:/etc/yum.repos.d/elasticsearch.repo

echo '-> Import GPG-Key Elasticsearch Repository'
sleep 5
ansible -b --become-method=sudo -m shell -a 'rpm --import https://artifacts.elastic.co/GPG-KEY-elasticsearch' nodes >> $debug

echo '-> Update Repository'
sleep 5
ansible -b --become-method=sudo -m shell -a 'yum -y update' nodes >> $debug

echo '-> Install Elasticsearch'

ansible -b --become-method=sudo -m shell -a 'yum -y install elasticsearch' nodes >> $debug

ansible -b --become-method=sudo -m shell -a 'systemctl enable elasticsearch' nodes >> $debug

echo '-> Create folder for Elastic Certificates and set permissions'
sleep 5
ansible -b --become-method=sudo -m shell -a 'mkdir /etc/elasticsearch/security && chmod 0750 -R /etc/elasticsearch/security' nodes >> $debug


echo "oooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo" 
echo "" 
echo "COPY CERTIFICATES AND CONFIG FILES"
echo "" 
echo "oooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo" 
sleep 3
echo '-> Copy Job runs ...'
sleep 3
scp -q elasticsearch.yml ca.pem ca.crt stack.p12 es.p12 http.pem http.key root@$n1.$domain:~/
scp -q elasticsearch.yml ca.pem ca.crt stack.p12 es.p12 http.pem http.key root@$n2.$domain:~/
scp -q elasticsearch.yml ca.pem ca.crt stack.p12 es.p12 http.pem http.key root@$n3.$domain:~/

echo '-> Make trust to CA Certificate'

ansible -b --become-method=sudo -m shell -a 'update-ca-trust force-enable && cp ca.pem /etc/pki/ca-trust/source/anchors/ca.crt && update-ca-trust extract' nodes >> $debug
ansible -b --become-method=sudo -m shell -a 'cp ca.pem ca.crt stack.p12 es.p12 /etc/elasticsearch/security/' nodes > $debug
ansible -b --become-method=sudo -m shell -a 'chmod 0750 -R /etc/elasticsearch/security' nodes >> $debug
ansible -b --become-method=sudo -m shell -a 'cp ~/elasticsearch.yml /etc/elasticsearch/elasticsearch.yml' nodes >> $debug

echo '-> Remove Keystore and Truststore Passwords'

ansible -b --become-method=sudo -m shell -a '/usr/share/elasticsearch/bin/elasticsearch-keystore remove xpack.security.transport.ssl.keystore.secure_password' nodes >> $debug
ansible -b --become-method=sudo -m shell -a '/usr/share/elasticsearch/bin/elasticsearch-keystore remove xpack.security.transport.ssl.truststore.secure_password' nodes >> $debug
ansible -b --become-method=sudo -m shell -a '/usr/share/elasticsearch/bin/elasticsearch-keystore remove xpack.security.http.ssl.keystore.secure_password' nodes >> $debug


echo '-> Restart Elasticsearch Service...'

ansible -b --become-method=sudo -m shell -a 'systemctl restart elasticsearch' nodes >> $debug

echo "oooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo" 
echo "" 
echo "RESET ALL ELASTIC USER PW" 
echo "" 
echo "oooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo" 
sleep 40
echo -e "$RED NO ESCAPE CHARACTER ALLOWED ( \ )"
echo -e "$NORMAL"
read -p "ENTER HERE PW FOR USER elastic ->: " elastic1
read -p "ENTER HERE PW FOR USER kibana_system ->: " kibana1
read -p "ENTER HERE PW FOR USER logstash_system ->: " logstash1
read -p "ENTER HERE PW FOR USER beats_system ->: " beats1
read -p "ENTER HERE PW FOR USER apm_system ->: " apm1
read -p "ENTER HERE PW FOR USER remote_monitoring_user ->: " remote1

cat <<EOF > elastic-user.ref

elastic1=$elastic1
kibana1=$kibana1
logstash1=$logstash1
beats1=$beats1
apm1=$apm1
remote1=$remote1

EOF

cat <<EOF >> es-pw.sh
ws1=\$(/usr/share/elasticsearch/bin/elasticsearch-reset-password --username elastic -b)
sleep 10
ws2=\$(echo \$ws1 | cut -d ' ' -f 10)
sleep 2
echo OLD SUPERUSER elastic:\$ws2
sleep 2
curl --silent -u elastic:\$ws2 -X POST "https://$n1.$domain:9200/_security/user/elastic/_password?pretty" -H 'Content-Type: application/json' -d'{"password" : "$elastic1"}'
#kibana_system
curl --silent -u elastic:$elastic1 -X POST  "https://$n1.$domain:9200/_security/user/kibana_system/_password?pretty" -H 'Content-Type: application/json' -d'{"password" : "$kibana1"}'
#logstash_system
curl --silent -u elastic:$elastic1 -X POST  "https://$n1.$domain:9200/_security/user/logstash_system/_password?pretty" -H 'Content-Type: application/json' -d'{"password" : "$logstash1"}'
#beats_system
curl --silent -u elastic:$elastic1 -X POST  "https://$n1.$domain:9200/_security/user/beats_system/_password?pretty" -H 'Content-Type: application/json' -d'{"password" : "$beats1"}'
#apm_system
curl --silent -u elastic:$elastic1 -X POST  "https://$n1.$domain:9200/_security/user/apm_system/_password?pretty" -H 'Content-Type: application/json' -d'{"password" : "$apm1"}'
#remote_monitoring_user
curl --silent -u elastic:$elastic1 -X POST  "https://$n1.$domain:9200/_security/user/remote_monitoring_user/_password?pretty" -H 'Content-Type: application/json' -d'{"password" : "$remote1"}'
EOF

sleep 2
echo -e "$RED"
ssh $n1.$domain 'bash -s' < es-pw.sh | grep "SUPERUSER"
echo -e "$NORMAL"
echo "oooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo" 
sleep 2
echo -e "$GREEN"
echo superuser changed to elastic:$elastic1 | grep "superuser changed to elastic"
sleep 1
echo -e "$NORMAL"
echo kibana_system changed to kibana_system:$kibana1 | grep "kibana_system changed to kibana_system"
sleep 1
echo logstash_system changed to logstash_system:$logstash1 | grep "logstash_system changed to logstash_system"
sleep 1
echo beats_system changed to beats_system:$beats1 | grep "beats_system changed to beats_system"
sleep 1
echo apm_system changed to apm_system:$apm1 | grep "apm_system changed to apm_system"
sleep 1
echo remote_monitoring_user changed to remote_monitoring_user:$remote1 | grep "remote_monitoring_user changed to remote_monitoring_user"
sleep 1
echo ""
echo -e "$RED"
echo 'CHECK CLUSTER STATUS IS GREEN AND ALL 3 ELASTIC NODES ARE MEMBER OF THE CLUSTER, IF NOT INSTALL FAILED'
echo -e "$NORMAL"
curl --silent -XGET -u elastic:$elastic1 https://$n1.$domain:9200/_cluster/health?pretty | grep -E -i -w 'nodes|3|status|green'
sleep 10
echo -e "$GREEN ... FIN"
echo -e "$NORMAL"
