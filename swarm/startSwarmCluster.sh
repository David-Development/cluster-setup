#!/bin/bash

if test "$BASH" != "/bin/bash"; then
    echo "Make sure you run this script with 'bash startCluster' in order to measure the time!"
    exit
fi

#if [[ -z "$@" ]]; then
#  echo -e "Error: Invalid argument. At least one hostname needs to be specified.\n\nbash startSwarmCluster.sh <node-name>"
#  exit 1;
#fi;

WORKER_NODES=( "$@" )

#for WORKER_NODE in "${WORKER_NODES[@]}"; do
#  echo "Worker-Node: $WORKER_NODE"
#done

cat ../signatures/signature-swarm.txt


###############################################################################
# check cluster config
###############################################################################

bold_font=$(tput bold)
normal_font=$(tput sgr0)

while true; do
    echo "${bold_font}Configuration:${normal_font}"
    echo "Worker Nodes:${bold_font} ${WORKER_NODES[@]} ${normal_font}"
    echo " "
    read -p "Is this configuration correct? (y/n): " yn
    case $yn in
        [Yy]* ) break;;
        [Nn]* ) exit;;
        * ) echo "Please answer yes or no.";;
    esac
done


###############################################################################
# init swarm
###############################################################################

#docker swarm leave --force
docker swarm init

#DOCKER_SWARM_RESULT="docker swarm join --token SWMTKN-1-5849h92rd5t04kfga2qyrdfhxldrgle292uac3yd8jufmoeir5-9daj36xf83es9brlfahlkp1oy 129.26.72.49:2377"
DOCKER_SWARM_RESULT=$(docker swarm join-token worker)
#echo "${DOCKER_SWARM_RESULT}"

DOCKER_SWARM_JOIN_COMMAND=$(echo ${DOCKER_SWARM_RESULT} | grep -oP "(docker swarm join --token .* ?:\d{4})")
echo "$DOCKER_SWARM_JOIN_COMMAND"

if [ -z "$DOCKER_SWARM_JOIN_COMMAND" ]; then
    echo "${bold_font}Swarm join command is empty.. something went wrong!${normal_font}"
    exit
fi


###############################################################################
# add workers to swarm cluster
###############################################################################

# Add worker nodes
for WORKER_NODE in "${WORKER_NODES[@]}"
do
    echo -e "Done!\n\nAdd node ${WORKER_NODE} to swarm.."
    ssh ${WORKER_NODE} $DOCKER_SWARM_JOIN_COMMAND
done



###############################################################################
# deploy portainer onto nodes
###############################################################################

curl -L https://portainer.io/download/portainer-agent-stack.yml -o portainer-agent-stack.yml
docker stack deploy --compose-file=portainer-agent-stack.yml portainer
