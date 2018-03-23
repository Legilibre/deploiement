#!/bin/sh

location=/root

# Add red PS1 for root
echo >> /root/.bashrc
echo 'export PS1='\''${debian_chroot:+($debian_chroot)}\[\\033[01;31m\]\u@\h\[\\033[01;37m\] \\t \[\\033[1;34m\]\w \$\[\\033[00m\] '\' >> /root/.bashrc

# Update and install some packages
apt-get update
apt-get dist-upgrade -y
apt-get install -y libarchive13 python-pip git htop sqlite3
apt-get install -y python2.7-dev libxml2-dev libxslt1-dev python-setuptools python-wheel

# Create dedicated directory
mkdir -p $location/legilibre
cd $location/legilibre

# Create directories
mkdir -p code secrets tarballs sqlite textes cache

[ -f /root/ssh_key ] && mv /root/ssh_key secrets
[ -f /root/secrets.sh ] && mv /root/secrets.sh secrets

# Copy code for legi.py and Archéo Lex
cd code
git clone https://github.com/Legilibre/legi.py.git
git clone https://github.com/Legilibre/Archeo-Lex.git
cd legi.py
pip install -r requirements.txt
cd ../Archeo-Lex
pip install -r requirements.txt


### legi.py

cd ../legi.py

# Download tarballs
python -m legi.download ../../tarballs

# Compute database
python -m legi.tar2sqlite ../../sqlite/legi.sqlite ../../tarballs


### Archéo Lex

cd ../Archeo-Lex

# Launch Archéo Lex on 3000 random texts

[ -x secrets/secrets.sh ] && . ./secrets/secrets.sh

if [ "$GITLAB_HOST" = "" ]
then
	./archeo-lex --textes=aleatoire-3 --bddlegi=../../sqlite/legi.sqlite --dossier=../../textes --cache=../../cache
else
	./archeo-lex --textes=aleatoire-3 --bddlegi=../../sqlite/legi.sqlite --dossier=../../textes --cache=../../cache --gitlab-host=$GITLAB_HOST --gitlab-token=$GITLAB_TOKEN --gitlab-group=$GITLAB_GROUP --git-server=$GIT_SERVER --git-port=$GIT_PORT --git-key=/root/legilibre/secrets/ssh_key
fi

# Tidy
rm -f /root/deploy_legilibre.sh

# Shut down and delete
curl https://cp-$DATACENTER.scaleway.com/servers/IP/action \
-H "X-Auth-Token: $TOKEN" \
-H "Content-Type: application/json" \
-d '{"action": "poweroff"}'

# TODO loop until server is off, then delete
curl https://cp-$DATACENTER.scaleway.com/servers/$IP \
-H "X-Auth-Token: $TOKEN" \
-H "Content-Type: application/json" \
-X DELETE
