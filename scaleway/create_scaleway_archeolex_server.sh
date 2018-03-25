#!/bin/sh

# The following variables must be set in a secrets.sh file.
TOKEN="" # key found in Credentials > TOKEN (possibly you have to "Create new token")
ORGANIZATION="" # key found in Credentials > access key
DATACENTER="par1" # par1 or ams1
TYPE="C2S" # commercial type
GITLAB_HOST="" # https://gitlab.example
GITLAB_TOKEN="" # found in Gitlab > Settings > Access Tokens
GITLAB_GROUP="" # group where are located the texts in Gitlab
GIT_SERVER="" # gituser@gitlab.example or ssh://gituser@gitlab.example:2222
GIT_PRIVATE_KEY="" # file with private key for Git server
LEGI_SERVER="" # cache LEGI server
LEGI_PY_SERVER="" # perennial server where is stored the legi.py SQLite database
LEGI_PRIVATE_KEY="" # SSH private key for cache LEGI server
LEGI_PY_PRIVATE_KEY="" # SSH private key of the perennial server where is stored the legi.py SQLite database
LIST_SERVER="" # server where is located the list of computed files
LIST_PRIVATE_KEY="" # SSH private key of the server where is located the list of computed files
TEXTES="" # list of texts or file containing a list of texts

# Should contains the variables TOKEN and ORGANIZATION at least
if [ -x secrets.sh ]
then
	. ./secrets.sh
else
	echo 'There should be a secrets.sh in this directory.'
	exit 1
fi
if [ ! -f "$GIT_PRIVATE_KEY" ]
then
	echo 'There should be a Git SSH key.'
	exit 1
fi

# Create a Debian Stretch 9.0 server
echo -n '* Create a Debian Stretch 9.0 server… '
ID=`curl -s https://cp-$DATACENTER.scaleway.com/servers \
-H "X-Auth-Token: $TOKEN" \
-H "Content-Type: application/json" \
-d '{ "name": "archeolex-worker", "image": "a869957c-6e1a-4b99-bc07-0748aa42c616", "commercial_type": "'$TYPE'", "tags": ["archeolex", "temporary"], "organization": "'$ORGANIZATION'", "enable_ipv6": true }'|jq -r .server.id`

if [ "$ID" = "null" ]
then
	exit 1
fi
echo 'done.'

echo -n '* Launch the server… '
curl -s https://cp-$DATACENTER.scaleway.com/servers/$ID/action \
-H "X-Auth-Token: $TOKEN" \
-H "Content-Type: application/json" \
-d '{"action": "poweron"}' >/dev/null
echo -n 'instructed… '

[ ! -f deploy_archeolex.sh ] && wget https://raw.githubusercontent.com/Legilibre/deploiement/master/scaleway/deploy_archeolex.sh

IP='null'
sleep 20
while [ "$IP" = "null" -o "$STATE" != "running" ]
do
	result=`curl -s https://cp-$DATACENTER.scaleway.com/servers/$ID \
	-H "X-Auth-Token: $TOKEN" \
	-H "Content-Type: application/json"`
	IP=`echo "$result"|jq -r .server.public_ip.address`
	STATE=`echo "$result"|jq -r .server.state`
	sleep 5
done
echo 'done.'
echo
echo "ssh root@$IP"
echo

echo '#!/bin/sh
chmod +x deploy_archeolex.sh
nohup ./deploy_archeolex.sh &
' >launch_deploy_archeolex.sh

# Upload bootstrap files
echo -n 'Upload bootstrap files… '
ssh-keygen -R $IP >/dev/null 2>&1

sleep 15

scp -p -q -o 'StrictHostKeyChecking no' launch_deploy_archeolex.sh root@$IP:.
scp -p -q deploy_archeolex.sh root@$IP:.
scp -p -q secrets.sh root@$IP:.
scp -p -q $LEGI_PRIVATE_KEY root@$IP:ssh_key_legi
scp -p -q $LEGI_PY_PRIVATE_KEY root@$IP:ssh_key_legi_py
scp -p -q $LIST_PRIVATE_KEY root@$IP:ssh_key_list
scp -p -q $GIT_PRIVATE_KEY root@$IP:ssh_key_git
[ -f "$TEXTES" ] && scp -p -q $TEXTES root@$IP:textes
echo 'done.'

echo -n 'Launch bootstrap file… '
ssh root@$IP 'chmod +x launch_deploy_archeolex.sh; mkdir -p legilibre/logs ./launch_deploy_archeolex.sh `</dev/null` >legilibre/logs/deploy_archeolex.log 2>legilibre/logs/deploy_archeolex.err &'
rm launch_deploy_archeolex.sh
echo 'done.'
