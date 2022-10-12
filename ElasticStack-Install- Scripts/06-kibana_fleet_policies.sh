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
x   ..::     K I B A N A - E L A S T I C - A G E N T - P O L I C I E S       ::..   x 
x                                                                                   x
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
'
sleep 3
echo -e "$NORMAL"

echo '

ADD A LOT OF PACKAGES AND SOME FLEET POLICIES

'

echo "oooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo" 
echo "" 
echo "CREATE CONFIG FILES" 
echo "" 
echo "oooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo" 

echo '-> READ FROM ~/host.ref'

source ~/host.ref

echo '

###---Packages---###
xpack.fleet.packages:
  - name: system
    version: latest
  - name: elastic_agent
    version: latest
  - name: windows
    version: latest
  - name: auditd
    version: latest
  - name: logstash
    version: latest
  - name: ti_abusech
    version: latest
  - name: tcp
    version: latest
  - name: log
    version: latest
  - name: nginx_ingress_controller
    version: latest
  - name: nginx
    version: latest
  - name: mysql
    version: latest


###---WIN---###

xpack.fleet.agentPolicies:
  - name: Lobby
    id: LOBBY
    namespace: default
    monitoring_enabled:
      - logs
#      - metrics
    package_policies:
      - name: system-lobby
        id: lobby-001
        package:
          name: system
        inputs:
          - type: system/metrics
            enabled: false
          - type: winlog
            enabled: true
          - type: logfile
            enabled: true

			
  - name: WIN
    id: WIN-001
    namespace: default
    monitoring_enabled:
      - logs
#      - metrics
    package_policies:
      - name: system-win
        id: system-win-001
        package:
          name: system
        inputs:
          - type: system/metrics
            enabled: false
          - type: winlog
            enabled: true
          - type: logfile
            enabled: false
      - name: windows
        package:
          name: windows
        inputs:
          - type: winlog
            enabled: true
          - type: windows/metrics
            enabled: false

###---LINUX---###

  - name: Linux
    id: LINUX-001
    namespace: default
    monitoring_enabled:
      - logs
#      - metrics
    package_policies:
      - name: system-linux
        id: system-linux-001
        package:
          name: system
        inputs:
          - type: system/metrics
            enabled: false
          - type: winlog
            enabled: false
          - type: logfile
            enabled: true
      - name: auditd
        package:
          name: auditd
        inputs:
          - type: logfile
            enabled: true
' > fleet-add-config.tmp

scp -q fleet-add-config.tmp root@$k1.$domain:~/

ansible -b --become-method=sudo -m shell -a 'cat fleet-add-config.tmp >> /etc/kibana/kibana.yml' kibana

sleep 5

echo -e "$GREEN [OK] copied kibana pre-config $NORMAL"

ansible -b --become-method=sudo -m shell -a 'systemctl restart kibana' kibana

echo -e "$GREEN [OK] kibana restarted $NORMAL"
