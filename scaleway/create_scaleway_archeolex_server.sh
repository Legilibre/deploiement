#!/bin/sh

# The following variables must be set in a secrets.sh file.
TOKEN="" # key found in Credentials > TOKEN (possibly you have to "Create new token")
ORGANIZATION="" # key found in Credentials > access key
DATACENTER="par1" # par1 or ams1
TYPE="C2S" # commercial type
GITLAB_HOST="" # https://gitlab.example
GITLAB_TOKEN="" # found in Gitlab > Settings > Access Tokens
GITLAB_GROUP="" # group where are located the texts in Gitlab
GIT_SERVER="" # gituser@gitlab.example

# Should contains the variables TOKEN and ORGANIZATION at least
if [ -x secrets.sh ]
then
	. ./secrets.sh
else
	echo 'There should be a secrets.sh in this directory.'
	exit 1
fi
if [ ! -f ssh_key ]
then
	echo 'There should be a ssh_key in this directory.'
	exit 1
fi

# Create a Debian Stretch 9.0 server
ID=`curl https://cp-$DATACENTER.scaleway.com/servers \
-H "X-Auth-Token: $TOKEN" \
-H "Content-Type: application/json" \
-d '{ "name": "archeolex-worker", "image": "a869957c-6e1a-4b99-bc07-0748aa42c616", "commercial_type": "'$TYPE'", "tags": ["archeolex", "temporary"], "organization": "'$ORGANIZATION'" }'|jq -r .server.id`

if [ "$ID" = "null" ]
then
	exit 1
fi

curl https://cp-$DATACENTER.scaleway.com/servers/$ID/action \
-H "X-Auth-Token: $TOKEN" \
-H "Content-Type: application/json" \
-d '{"action": "poweron"}'

wget https://raw.githubusercontent.com/Legilibre/deploiement/master/scaleway/deploy_archeolex.sh

IP='null'
while [ "$IP" = "null" ]
do
	IP=`curl https://cp-$DATACENTER.scaleway.com/servers/$ID \
	-H "X-Auth-Token: $TOKEN" \
	-H "Content-Type: application/json"|jq -r .server.public_ip.address`
done

echo '#!/bin/sh
chmod +x deploy_archeolex.sh
nohup ./deploy_archeolex.sh &
' >launch_deploy_archeolex.sh

scp -p launch_deploy_archeolex.sh root@$IP:.
scp -p deploy_archeolex.sh root@$IP:.
scp -p ssh_key root@$IP:.

ssh root@$IP 'chmod +x launch_deploy_archeolex.sh; ./launch_deploy_archeolex.sh &'
