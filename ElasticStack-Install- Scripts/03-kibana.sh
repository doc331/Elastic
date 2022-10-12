#!/bin/bash
clear
NORMAL='\033[0;39m'
BLUE='\033[1;34m'
GREEN='\033[1;32m'
RED='\033[1;31m'
#debug=$(/dev/null 2>&1)
debug=debug-kibana-install.txt
echo -e "$RED"
echo '
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
x                                                                                   x
x                                                                                   x
x   ..::                       K I B A N A - N G I N X                       ::..   x 
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
--> OS: ROCKY LINUX >8.5 '
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
	
	rsyslog unzip jq tar kibana nginx rsyslog
	
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

cat <<EOF >> kibana.yml
server.port: 5601
server.host: "0.0.0.0"

elasticsearch.username: "kibana_system"
elasticsearch.password: "$kibana1"
server.ssl.enabled: true
server.ssl.certificate: /etc/kibana/security/http.pem
server.ssl.key: /etc/kibana/security/http.key
elasticsearch.ssl.verificationMode: full

elasticsearch.ssl.certificateAuthorities: [ "/etc/kibana/security/ca.pem" ]

monitoring.kibana.collection.enabled: false

telemetry.enabled: false
telemetry.optIn: false

logging.appenders.file.type: file
logging.appenders.file.fileName: /var/log/kibana/kibana.log
logging.appenders.file.layout.type: pattern

logging.appenders.rolling-file.type: rolling-file
logging.appenders.rolling-file.fileName: /var/log/kibana/kibana.log
logging.appenders.rolling-file.policy.type: size-limit
logging.appenders.rolling-file.policy.size: 50mb
logging.appenders.rolling-file.strategy.type: numeric
logging.appenders.rolling-file.strategy.pattern: '-%i'
logging.appenders.rolling-file.strategy.max: 10
logging.appenders.rolling-file.layout.type: pattern
logging.root.appenders: [file, rolling-file]
logging.root.level: info
EOF


echo server.name: "\"$k1"\" >> kibana.yml
echo elasticsearch.hosts: >> kibana.yml
echo '  - https://'$n1.$domain':9200' >> kibana.yml
echo '  - https://'$n2.$domain':9200' >> kibana.yml
echo '  - https://'$n3.$domain':9200' >> kibana.yml
echo server.publicBaseUrl: "\"http://$a1.diosen.de"\" >> kibana.yml

key=$(tr -cd '[:alnum:]' < /dev/urandom | fold -w33 | head -n1)

echo xpack.security.encryptionKey: "\"$key"\" >> kibana.yml
echo xpack.encryptedSavedObjects.encryptionKey: "\"$key"\" >> kibana.yml

##NGINX

cat <<EOF >> nginx.conf
# For more information on configuration, see:
#   * Official English Documentation: http://nginx.org/en/docs/
#   * Official Russian Documentation: http://nginx.org/ru/docs/

user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

# Load dynamic modules. See /usr/share/doc/nginx/README.dynamic.
include /usr/share/nginx/modules/*.conf;

events {
    worker_connections 1024;
}

http {
    log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                      '\$status \$body_bytes_sent "\$http_referer" '
                      '"\$http_user_agent" "\$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile            on;
    tcp_nopush          on;
    tcp_nodelay         on;
    keepalive_timeout   65;
    types_hash_max_size 2048;

    include             /etc/nginx/mime.types;
    default_type        application/octet-stream;

    # Load modular configuration files from the /etc/nginx/conf.d directory.
    # See http://nginx.org/en/docs/ngx_core_module.html#include
    # for more information.
    include /etc/nginx/conf.d/*.conf;

#    server {
#        listen       80 default_server;
#        listen       [::]:80 default_server;
#        server_name  _;
#        root         /usr/share/nginx/html;

        # Load configuration files for the default server block.
#        include /etc/nginx/default.d/*.conf;

#        location / {
#        }
#
#        error_page 404 /404.html;
#            location = /40x.html {
#        }
#
#        error_page 500 502 503 504 /50x.html;
#            location = /50x.html {
#        }
#    }

# Settings for a TLS enabled server.
#
#    server {
#        listen       443 ssl http2 default_server;
#        listen       [::]:443 ssl http2 default_server;
#        server_name  _;
#        root         /usr/share/nginx/html;
#
#        ssl_certificate "/etc/pki/nginx/server.crt";
#        ssl_certificate_key "/etc/pki/nginx/private/server.key";
#        ssl_session_cache shared:SSL:1m;
#        ssl_session_timeout  10m;
#        ssl_ciphers PROFILE=SYSTEM;
#        ssl_prefer_server_ciphers on;
#
#        # Load configuration files for the default server block.
#        include /etc/nginx/default.d/*.conf;
#
#        location / {
#        }
#
#        error_page 404 /404.html;
#            location = /40x.html {
#        }
#
#        error_page 500 502 503 504 /50x.html;
#            location = /50x.html {
#        }
#    }

}
EOF



echo '
server {
        listen 80 default_server;
        listen [::]:80 default_server;
        server_name _;
        return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;

    server_name '$a1.$domain';

    location / {
        proxy_pass https://'$a1.$domain':5601;
    }

    ssl_certificate /etc/nginx/certs/siem.pem;
    ssl_certificate_key /etc/nginx/certs/siem.key;
}' >> proxy.conf

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

echo "oooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo" 
echo "" 
echo "COPY CONFIG FILES AND INSTALL KIBANA - NGINX AS A PROXY" 
echo "" 
echo "oooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo" 

echo '-> Run copy job'
scp -q kibana.yml nginx.conf proxy.conf ca.pem http.pem http.key root@$k1.$domain:~/
scp -q elasticsearch.repo root@$k1.$domain:/etc/yum.repos.d/elasticsearch.repo

echo '-> Import GPG-Key Elasticsearch Repository'
sleep 2
ansible -b --become-method=sudo -m shell -a 'rpm --import https://artifacts.elastic.co/GPG-KEY-elasticsearch' kibana >> $debug

echo '-> Update Repository'
sleep 2
ansible -b --become-method=sudo -m shell -a 'yum -y update' kibana >> $debug
echo '-> Install rsyslog unzip jq tar kibana nginx rsyslog'
sleep 2
ansible -b --become-method=sudo -m shell -a 'yum -y install rsyslog unzip jq tar kibana nginx rsyslog' kibana >> $debug
ansible -b --become-method=sudo -m shell -a 'systemctl enable kibana' kibana >> $debug
ansible -b --become-method=sudo -m shell -a 'systemctl enable nginx' kibana >> $debug
echo '-> Trust CA Update'
sleep 2
ansible -b --become-method=sudo -m shell -a 'update-ca-trust force-enable && cp ca.pem /etc/pki/ca-trust/source/anchors/ca.crt && update-ca-trust extract' kibana >> $debug
echo '-> Create Directory for Certificates'
sleep 2
ansible -b --become-method=sudo -m shell -a 'mkdir /etc/kibana/security && mkdir /etc/nginx/certs' kibana >> $debug
echo '-> Copy Certificates and Config Files'
sleep 2
ansible -b --become-method=sudo -m shell -a 'cp http.pem /etc/nginx/certs/siem.pem' kibana >> $debug
ansible -b --become-method=sudo -m shell -a 'cp http.key /etc/nginx/certs/siem.key' kibana >> $debug
ansible -b --become-method=sudo -m shell -a 'cp http.pem http.key ca.pem /etc/kibana/security/' kibana >> $debug
ansible -b --become-method=sudo -m shell -a 'cp kibana.yml /etc/kibana/' kibana >> $debug
ansible -b --become-method=sudo -m shell -a 'chmod -R 0750 /etc/kibana/security' kibana >> $debug
ansible -b --become-method=sudo -m shell -a 'cp proxy.conf /etc/nginx/conf.d/proxy.conf' kibana >> $debug
ansible -b --become-method=sudo -m shell -a 'cp nginx.conf /etc/nginx/nginx.conf' kibana >> $debug

echo '-> Restart Kibana and NGINX'

ansible -b --become-method=sudo -m shell -a 'systemctl restart kibana' kibana >> $debug
sleep 30
ansible -b --become-method=sudo -m shell -a 'systemctl restart nginx' kibana >> $debug
sleep 30
##curl test on $k1.$domain
if [[ $(curl --silent --max-time 5 -u elastic:$elastic1 https://$k1.$domain/status | grep -E -i -w 'chrome' ) = *chrome* ]]; then
echo -e "$GREEN [OK]--> Kibana found $NORMAL"
else
echo -e "$RED ERROR KIBANA NOT READY $NORMAL"
exit 1
fi


