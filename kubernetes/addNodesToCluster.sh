#!/bin/bash

if test "$BASH" != "/bin/bash"; then
    echo "Make sure you run this script with 'bash startCluster' in order to measure the time!"
    exit
fi

if [[ -z "${@:2}" ]]; then
  echo -e "Error: Invalid argument. At least one hostname needs to be specified.\n\nbash addNodesToCluster.sh <cluster-name> <node-name>"
  exit 1;
fi;

WORKER_NODES=( "${@:2}" )

#for WORKER_NODE in "${WORKER_NODES[@]}"; do
#  echo "Worker-Node: $WORKER_NODE"
#done

CLUSTER_NAME="$1"
HOST_IP=$(hostname -I | awk '{print $1}')

RANCHER_CLI="./tools/rancher"
RANCHER_TOKEN_FILE="rancher-login-token.txt"

if [ ! -f "$RANCHER_TOKEN_FILE" ]; then
    echo "Token file not found!"
    exit;
fi

BEARER_TOKEN=$(cat $RANCHER_TOKEN_FILE)

cat ../signatures/signature-kubernetes.txt


###############################################################################
# check cluster config
###############################################################################

bold_font=$(tput bold)
normal_font=$(tput sgr0)

while true; do
    echo "${bold_font}Configuration:${normal_font}"
    echo "Worker Nodes: ${bold_font} ${WORKER_NODES[@]} ${normal_font}"
    echo "Cluster Name: ${bold_font} ${CLUSTER_NAME} ${normal_font}"
    echo "Rancher-IP:   ${bold_font} ${HOST_IP} ${normal_font}"
    echo "Rancher Token: ${BEARER_TOKEN}"

    echo " "
    read -p "Is this configuration correct? (y/n): " yn
    case $yn in
        [Yy]* ) break;;
        [Nn]* ) exit;;
        * ) echo "Please answer yes or no.";;
    esac
done


###############################################################################
# add nodes to cluster
###############################################################################

${RANCHER_CLI} login https://${HOST_IP}:8443 --token ${BEARER_TOKEN}

# Add worker nodes
for WORKER_NODE in "${WORKER_NODES[@]}"
do
    echo -e "Done!\n\nAdd worker node ${WORKER_NODE} to it.."
    ADD_NODE_COMMAND=$(${RANCHER_CLI} clusters add-node --worker ${CLUSTER_NAME})
    ADD_NODE_DOCKER_COMMAND=$(echo "$ADD_NODE_COMMAND" | grep -o "docker.*")
    ssh ${WORKER_NODE} $ADD_NODE_DOCKER_COMMAND
done
echo -e "Done!\n\n"
