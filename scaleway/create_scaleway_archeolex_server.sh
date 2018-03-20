#!/bin/sh

TOKEN="" # key found in Credentials > TOKEN (possibly you have to "Create new token")
ORGANIZATION="" # key found in Credentials > access key
DATACENTER="par1" # par1 or ams1
TYPE="C2S" # commercial type

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

# Wait until it is created
# …
# TODO

IP=`curl https://cp-$DATACENTER.scaleway.com/servers/$ID \
-H "X-Auth-Token: $TOKEN" \
-H "Content-Type: application/json"|jq -r .server.public_ip.address`

wget https://raw.githubusercontent.com/Legilibre/deploiement/master/scaleway/deploy_archeolex.sh
scp -p deploy_archeolex.sh root@$IP:.
# TODO execute script on server


# Send secrets (Gitlab token, SSH private key to send to Gitlab, optionally SSH public keys for humans)
# TODO

# Éteindre et détruire
# curl https://cp-$DATACENTER.scaleway.com/servers/IP/action \
# -H "X-Auth-Token: $TOKEN" \
# -H "Content-Type: application/json" \
# -d '{"action": "poweroff"}'
# curl https://cp-$DATACENTER.scaleway.com/servers/$IP \
# -H "X-Auth-Token: $TOKEN" \
# -H "Content-Type: application/json" \
# -X DELETE
