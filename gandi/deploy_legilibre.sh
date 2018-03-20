#!/bin/sh

# Add red PS1 for root
echo >> /root/.bashrc
echo 'export PS1='\''${debian_chroot:+($debian_chroot)}\[\\033[01;31m\]\u@\h\[\\033[01;37m\] \\t \[\\033[1;34m\]\w \$\[\\033[00m\] '\' >> /root/.bashrc

# Unused directory?
rmdir init.disabled

# Avoid locale warning
echo '\nen_US.UTF-8\nfr_FR.UTF-8\n' >> /etc/locale.gen
locale-gen --purge
echo 'LANG=C.UTF-8\n' > /etc/default/locale
export LANG=C.UTF-8

# Update and install some packages
apt-get update
apt-get dist-upgrade
apt-get install -y libarchive13 python-pip git htop sqlite3
apt-get install -y python2.7-dev libxml2-dev libxslt1-dev python-setuptools python-wheel

# If data disk, use it
location=/root
if [ -e /dev/xvdb ]; then
	label=`e2label /dev/xvdb`
	if [ "$?" = 0 ]; then
		# On Debian 9 (on Gandi VMs), data disk are mounted but not activated until requested
		ls /srv/$label >/dev/null 2>/dev/null
		location=/srv/$label
	fi
fi

# Create dedicated directory
mkdir -p $location/legilibre
cd $location/legilibre

# Create directories
mkdir -p code tarballs sqlite textes cache

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

# Install cron
# TBD

# Download tarballs
python -m legi.download ../../tarballs

# Compute database
python -m legi.tar2sqlite ../../sqlite/legi.sqlite ../../tarballs


### Archéo Lex

cd ../Archeo-Lex

# Launch Archéo Lex on 3000 random texts

./archeo-lex --textes=aleatoire-3000 --bddlegi=../../sqlite/legi.sqlite --dossier=../../textes --cache=../../cache


# Tidy
rm -f /root/deploy_legilibre.sh
