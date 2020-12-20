#!/bin/bash

# This is a placeholder script, you can move your setup script here to install some custom deployment on the VM
# The parent directory of this script will be transferred with its content to the VM under /tmp/setup path
# (i.e: useful for copying configs, scripts, systemd units, etc..)  

set -e
sudo usermod -aG docker ubuntu

# install rancher
sudo docker run -d --restart=unless-stopped \
  -p 8080:80 -p 8443:443 \
  --privileged \
  rancher/rancher:latest
echo "Done installing rancher"

# install kubectl helm
curl -LO "https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x ./kubectl
sudo mv ./kubectl /usr/local/bin/kubectl
echo "Done installing kubectl"

curl https://baltocdn.com/helm/signing.asc | sudo apt-key add -
echo "deb https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install helm -y
echo "Done installing helm"
# create cluster
# Check if server is alive
# -----------------------
STATUS=`curl 'https://localhost:8443/ping' 2>/dev/null --insecure`
echo $STATUS
if [ "$STATUS" != "pong" ]
then
      echo "Rancher is not running. Aborting..."
      exit 1
fi

SERVER_NAME=172.17.0.1
CLUSTER_NAME=glasswall-proxy1
ADMIN_PASSWORD=changepassword
# Get auth token
# -----------------------

# Login
LOGINRESPONSE=`curl -s 'https://127.0.0.1:8443/v3-public/localProviders/local?action=login' -H 'content-type: application/json' --data-binary '{"username":"admin","password":"admin"}' --insecure`
# LOGINRESPONSE=`curl -s 'https://127.0.0.1:8443/v3-public/localProviders/local?action=login' -H 'content-type: application/json' --data-binary '{"username":"admin","password":"changepassword"}' --insecure`
LOGINTOKEN=`echo $LOGINRESPONSE | jq -r .token`
echo $LOGINTOKEN

# Change admin Password
# ----------------------
curl -s 'https://127.0.0.1:8443/v3/users?action=changepassword' -H 'content-type: application/json' -H "Authorization: Bearer $LOGINTOKEN" --data-binary "{\"currentPassword\":\"admin\",\"newPassword\":\"$ADMIN_PASSWORD\"}" --insecure

# Create API key
# ----------------------
APIRESPONSE=`curl -s 'https://127.0.0.1:8443/v3/token' -H 'content-type: application/json' -H "Authorization: Bearer $LOGINTOKEN" --data-binary '{"type":"token","description":"automation"}' --insecure`

# Extract and store token
# ----------------------
APITOKEN=`echo $APIRESPONSE | jq -r .token`

# Configure server-url
# ----------------------
RANCHER_SERVER="https://$SERVER_NAME:8443"
curl -s 'https://127.0.0.1:8443/v3/settings/server-url' -H 'content-type: application/json' -H "Authorization: Bearer $APITOKEN" -X PUT --data-binary "{\"name\":\"server-url\",\"value\":\"$SERVER_NAME\"}" --insecure

# Create cluster
# ----------------------
CLUSTERRESPONSE=`curl -s 'https://127.0.0.1:8443/v3/cluster' -H 'content-type: application/json' -H "Authorization: Bearer $APITOKEN" --data-binary "{\"type\":\"cluster\",\"nodes\":[],\"rancherKubernetesEngineConfig\":{\"ignoreDockerVersion\":true},\"name\":\"$CLUSTER_NAME\"}" --insecure`

# Extract clusterid to use for generating the docker run command
# ----------------------
CLUSTERID=`echo $CLUSTERRESPONSE | jq -r .id`
# Get nodeCommand to add Master nodes
# -------------------------------------

# TODO: Try to quit the sed, and get the right server name

# Specify role flags to use
ROLEFLAGS="--etcd --controlplane --worker --address 172.17.0.1"

# Generate token (clusterRegistrationToken) and extract nodeCommand
AGENTCOMMAND=`curl -s 'https://127.0.0.1:8443/v3/clusterregistrationtoken' -H 'content-type: application/json' -H "Authorization: Bearer $APITOKEN" --data-binary '{"type":"clusterRegistrationToken","clusterId":"'$CLUSTERID'"}' --insecure | jq -r .nodeCommand`

# Show the command
echo "Running command to register node: '${AGENTCOMMAND} ${ROLEFLAGS}'" sed  "s|--server|--server $RANCHER_SERVER|g"

# Show the command
final_agent_command=$(echo "${AGENTCOMMAND} ${ROLEFLAGS}" | sed  "s|--server|--server $RANCHER_SERVER|g")
echo $final_agent_command
eval $final_agent_command

docker ps
docker logs -f e9216d8f3526

# create kubeconfig file

