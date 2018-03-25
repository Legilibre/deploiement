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

service exim4 stop

# Create dedicated directory
mkdir -p $location/legilibre
cd $location/legilibre

# Create directories
mkdir -p code divers secrets tarballs sqlite textes cache

[ -f /root/secrets.sh ] && mv /root/secrets.sh secrets
[ -f /root/ssh_key_legi ] && mv /root/ssh_key_legi secrets
[ -f /root/ssh_key_legi_py ] && mv /root/ssh_key_legi_py secrets
[ -f /root/ssh_key_list ] && mv /root/ssh_key_list secrets
[ -f /root/ssh_key_git ] && mv /root/ssh_key_git secrets
[ -f /root/textes ] && mv /root/textes divers/textes

[ -x secrets/secrets.sh ] && . ./secrets/secrets.sh

# Copy code for legi.py and Archéo Lex
cd code
git clone https://github.com/Legilibre/legi.py.git
git clone https://github.com/Legilibre/Archeo-Lex.git
cd legi.py
pip install -r requirements.txt
cd ../Archeo-Lex
pip install -r requirements.txt


# Download tarballs

cd ../../tarballs

if [ "$LEGI_SERVER" != "" -a -f /root/legilibre/secrets/ssh_key_legi ]
then
	rsync -az -e "ssh -i /root/legilibre/secrets/ssh_key_legi -o 'StrictHostKeyChecking no'" $LEGI_SERVER/ /root/legilibre/tarballs
fi

wget -c -N --no-remove-listing -nH -P . 'ftp://echanges.dila.gouv.fr/LEGI/*legi_*'

if [ "$LEGI_SERVER" != "" -a -f /root/legilibre/secrets/ssh_key_legi ]
then
	rsync -az -e "ssh -i /root/legilibre/secrets/ssh_key_legi" /root/legilibre/tarballs/ $LEGI_SERVER
fi


### legi.py

cd ../code/legi.py

if [ "$LEGI_PY_SERVER" != "" -a -f /root/legilibre/secrets/ssh_key_legi_py ]
then
	rsync -az -e "ssh -i /root/legilibre/secrets/ssh_key_legi_py -o 'StrictHostKeyChecking no'" $LEGI_PY_SERVER/legi.sqlite /root/legilibre/sql/legi.sqlite
fi

# Compute database
python -m legi.tar2sqlite ../../sqlite/legi.sqlite ../../tarballs

if [ "$LEGI_PY_SERVER" != "" -a -f /root/legilibre/secrets/ssh_key_legi_py ]
then
	rsync -az -e "ssh -i /root/legilibre/secrets/ssh_key_legi_py" /root/legilibre/sql/legi.sqlite $LEGI_PY_SERVER/legi.sqlite
fi


### Archéo Lex

cd ../Archeo-Lex

# Launch Archéo Lex on 3000 random texts

if [ -f /root/legilibre/divers/textes ]
then
	TEXTES=/root/legilibre/divers/textes
fi

if [ "$LIST_SERVER" != "" -a -f /root/legilibre/secrets/ssh_key_list ]
then
	rsync -az -e "ssh -i /root/legilibre/secrets/ssh_key_list -o 'StrictHostKeyChecking no'" $LIST_SERVER/calcules /root/legilibre/divers/calcules
fi

if [ "$GITLAB_HOST" = "" ]
then
	./archeo-lex --textes=$TEXTES --bddlegi=/root/legilibre/sqlite/legi.sqlite --dossier=/root/legilibre/textes --cache=/root/legilibre/cache --calcules=/root/legilibre/divers/calcules
else
	./archeo-lex --textes=$TEXTES --bddlegi=/root/legilibre/sqlite/legi.sqlite --dossier=/root/legilibre/textes --cache=/root/legilibre/cache --gitlab-host=$GITLAB_HOST --gitlab-token=$GITLAB_TOKEN --gitlab-group=$GITLAB_GROUP --git-server=$GIT_SERVER --git-key=/root/legilibre/secrets/ssh_key_git --calcules=/root/legilibre/divers/calcules
fi

if [ "$LIST_SERVER" != "" -a -f /root/legilibre/secrets/ssh_key_list ]
then
	rsync -az -e "ssh -i /root/legilibre/secrets/ssh_key_list" /root/legilibre/divers/calcules $LIST_SERVER/calcules
fi

# Tidy
rm -f /root/deploy_legilibre.sh

# Shut down and delete
curl https://cp-$DATACENTER.scaleway.com/servers/$ID/action \
-H "X-Auth-Token: $TOKEN" \
-H "Content-Type: application/json" \
-d '{"action": "terminate"}'
