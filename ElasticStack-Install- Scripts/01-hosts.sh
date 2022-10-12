#!/bin/bash

NORMAL='\033[0;39m'
BLUE='\033[1;34m'
GREEN='\033[1;32m'
RED='\033[1;31m'
debug=$(&>> ~/debug.tmp)

clear
echo -e "$RED"

echo '

xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
x                                                                                   x
x                                                                                   x
x   ..:: H O S T - C O N F I G - S C R I P T - F O R - R O C K Y - L I N U X ::..   x 
x                                                                                   x
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

'
sleep 3
echo -e "$NORMAL"
if [ "$(id -u)" != "0" ]; then
    echo "Sorry, you are not root."
    exit 1
fi

echo -e "$NORMAL---> CONFIG YOUR DNS (2 SERVER FOR REDUNDANCY) <--- "

read -p "ENTER HERE YOUR DNS-Server1 ->: " dns1
read -p "ENTER HERE YOUR DNS-Server2 ->: " dns2
echo -e "$RED BOTH DNS Server WILL BE ALSO USED AS NTP Server"
sleep 3
echo -e "$NORMAL"
read -p "ENTER HERE THE IP OF Elastic Node1 ->: " ipn1
read -p "ENTER HERE THE IP OF Elastic Node2 ->: " ipn2
read -p "ENTER HERE THE IP OF Elastic Node3 ->: " ipn3
read -p "ENTER HERE THE IP OF Kibana Node ->: " ipk1
read -p "ENTER HERE THE HOSTNAME OF Elastic Node1 ->: " n1
read -p "ENTER HERE THE HOSTNAME OF Elastic Node2 ->: " n2
read -p "ENTER HERE THE HOSTNAME OF Elastic Node3 ->: " n3
read -p "ENTER HERE THE HOSTNAME OF Kibana Node ->: " k1
read -p "ENTER HERE THE ALIAS OF Kibana Node ->: " a1
read -p "ENTER HERE YOUR DOMAIN like mynet.com ->: " domain
read -p "ENTER TEMPORARY ROOT PW FOR ALL HOSTS ->: " tmppw


sleep 2

cat <<EOF > host.ref
dns1=$dns1
dns2=$dns2
ipn1=$ipn1
ipn2=$ipn2
ipn3=$ipn3
ipk1=$ipk1
n1=$n1
n2=$n2
n3=$n3
k1=$k1
a1=$a1
domain=$domain
tmppw=$tmppw
EOF

echo -e "$GREEN"

cat host.ref

echo -e "$RED"
echo "DO YOU WANT TO CONTINUE WITH THIS SET OF HOSTS? PRESS space TO CONTINUE OR ABORT WITH strg + c "
echo -e "$NORMAL"
read -r -s -d ' '

echo -e "$GREEN PREPAIR --> SSH KEYS"
echo -e "$NORMAL"
sudo yum -y install sshpass | $debug
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -q -N ""
sleep 3


sleep 2
sudo sshpass -p "$tmppw" ssh-copy-id $n1.$domain -o StrictHostKeyChecking=no &>> ~/debug.tmp
sudo sshpass -p "$tmppw" ssh-copy-id $n2.$domain -o StrictHostKeyChecking=no &>> ~/debug.tmp
sudo sshpass -p "$tmppw" ssh-copy-id $n3.$domain -o StrictHostKeyChecking=no &>> ~/debug.tmp
sudo sshpass -p "$tmppw" ssh-copy-id $k1.$domain -o StrictHostKeyChecking=no &>> ~/debug.tmp

sudo cat <<EOF >> /etc/ansible/hosts
[elkhosts]
$n1.$domain
$n2.$domain
$n3.$domain
$k1.$domain
[kibana]
$k1.$domain
[nodes]
$n1.$domain
$n2.$domain
$n3.$domain
EOF
echo -e "$GREEN CHECK PING--> ALL HOSTS"
ansible -m ping elkhosts | grep '|'

cat <<EOF > oos.sh
#!/bin/bash

sed -i '26i dns=none' /etc/NetworkManager/NetworkManager.conf

echo nameserver $dns1 >> /etc/resolv.conf
echo nameserver $dns2 >> /etc/resolv.conf


echo $ipn1 $n1.$domain $n1 >> /etc/hosts
echo $ipn2 $n2.$domain $n2 >> /etc/hosts
echo $ipn3 $n3.$domain $n3 >> /etc/hosts
echo $ipk1 $k1.$domain $k1 >> /etc/hosts


sed -i 's|#base|base|g' /etc/yum.repos.d/*.repo
sed -i 's|mirror|#mirror|g' /etc/yum.repos.d/*.repo
sed -i 's|baseurl=http|baseurl=https|g' /etc/yum.repos.d/Rocky-*.repo
yum clean all
yum makecache
yum -y update
yum -y install epel-release nano net-tools sudo chrony openssh-server ca-certificates firewalld curl wget rsyslog unzip jq tar sudo

service firewalld stop
systemctl disable firewalld

sed -i s/^SELINUX=.*$/SELINUX=permissive/ /etc/selinux/config
setenforce 0
getenforce

timedatectl set-timezone Europe/Berlin

systemctl enable --now chronyd
sed -i 's/pool/#pool/g' /etc/chrony.conf
echo server $dns1 >> /etc/chrony.conf
echo server $dns2 >> /etc/chrony.conf
systemctl restart chronyd

EOF

echo -e "$GREEN CREATE --> ANSIBLE PLAYBOOKS"

#######ansible playbook copy and execute script

cat <<EOF > oos-copy.yml
- name: Copy OS Install Script
  hosts: elkhosts
  become: true

  tasks:

  - name: Copy Job
    ansible.builtin.copy:
      src: /root/oos.sh
      dest: /root/oos.sh
      owner: root
      group: root
      mode: '0644'
EOF

cat <<EOF > os-inst.yml
- name: Run oos.sh on each host
  hosts: elkhosts
  become: true
  tasks:
  - name: Run OS Install Script
    command: sh /root/oos.sh

EOF
echo -e "$NORMAL"
echo -e "$GREEN RUN COPY JOB --> ANSIBLE PLAYBOOKS"
echo -e "$NORMAL"
ansible-playbook oos-copy.yml

sleep 3
echo -e "$NORMAL"
echo -e "$GREEN RUN OS INSTALL"
echo -e "$NORMAL"
sleep 3
ansible-playbook os-inst.yml

echo -e "$NORMAL"
echo -e "$GREEN RESTART ALL HOSTS"
echo -e "$NORMAL"
sleep 10

ansible -b --become-method=sudo -m shell -a 'yum -y update' elkhosts | grep "|"

ansible -b --become-method=sudo -m shell -a 'reboot' elkhosts | grep "|"

echo -e "$GREEN ... FIN"
echo -e "$NORMAL"