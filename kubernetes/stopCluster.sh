#!/bin/bash

if test "$BASH" != "/bin/bash"; then
    echo "Make sure you run this script with 'bash startCluster' in order to measure the time!"
    exit
fi

#WORKER_NODES=( "" "nm-tantalos" )
#WORKER_NODES=( "" "nm-smt02" "nm-smt03" )

if [[ -z "$@" ]]; then
  echo -e "Error: Invalid argument. At least one hostname needs to be specified.\n\nbash stopCluster.sh <node-name>"
  exit 1;
fi;

WORKER_NODES=( "" "$@" )

#for WORKER_NODE in "${WORKER_NODES[@]}"; do
#  echo "Worker-Node: $WORKER_NODE"
#done



FILES_TO_DELETE="/etc/ceph/* \
      /etc/cni/* \
      /etc/kubernetes/* \
      /opt/cni/* \
      /opt/rke/* \
      /run/secrets/kubernetes.io/* \
      /run/calico/* \
      /run/flannel/* \
      /var/lib/calico/* \
      /var/lib/etcd/* \
      /var/lib/cni/* \
      /var/lib/kubelet/* \
      /var/lib/rancher/* \
      /var/log/containers/* \
      /var/log/pods/* \
      /var/run/calico/*"
# FILES_TO_DELETE="/etc/ceph/*"

#DELETE_COMMAND="docker run ubuntu:16.04 /bin/bash -c \"rm -r ${FILES_TO_DELETE}\""
DELETE_COMMAND="docker run \
-v /etc/ceph:/etc/ceph \
-v /etc/cni:/etc/cni \
-v /etc/kubernetes:/etc/kubernetes \
-v /opt/cni:/opt/cni \
-v /opt/rke:/opt/rke \
-v /run/secrets/kubernetes.io:/run/secrets/kubernetes.io \
-v /run/calico:/run/calico \
-v /run/flannel:/run/flannel \
-v /var/lib/calico:/var/lib/calico \
-v /var/lib/etcd:/var/lib/etcd \
-v /var/lib/cni:/var/lib/cni \
-v /var/lib/kubelet:/var/lib/kubelet \
-v /var/lib/rancher:/var/lib/rancher \
-v /var/log/containers:/var/log/containers \
-v /var/log/pods:/var/log/pods \
-v /var/run/calico:/var/run/calico \
ubuntu:16.04 /bin/bash -c \"rm -rf ${FILES_TO_DELETE}\""
# ubuntu:16.04 /bin/bash -c \"ls -la /var/lib/\""


#echo "${DELETE_COMMAND}"
#exit

cat ../signatures/signature-kubernetes.txt

###############################################################################
# ask user if everything is correct
###############################################################################

bold_font=$(tput bold)
normal_font=$(tput sgr0)

while true; do
    echo "${bold_font}Configuration:${normal_font}"
    echo "Folders to delete: ${bold_font} ${FILES_TO_DELETE} ${normal_font}"
    echo "Worker Nodes:      ${bold_font} ${WORKER_NODES[@]} ${normal_font}"
    echo " "
    read -p "Is this configuration correct? (y/n): " yn
    case $yn in
        [Yy]* ) break;;
        [Nn]* ) exit;;
        * ) echo "Please answer yes or no.";;
    esac
done

# export path variable to include "tools" (kubectl / rancher / ...)
TOOLS_FOLDER="$(pwd)/tools/"
PATH="$PATH:${TOOLS_FOLDER}"


# Remove Minio
#helm del --purge argo-artifacts

# Uninstall Argo
#argo uninstall

# Delete Persistent Volumes / -Claims for pachyderm
rancher kubectl delete pvc etcd-storage
rancher kubectl delete pv pachyderm-etcd-pv


# Delete deployments
rancher kubectl delete deployment --all

# Delete Services
rancher kubectl delete services --all

# Delete ingresses
rancher kubectl delete ingresses --all

# Delete all nodes
rancher kubectl delete node --all


KUBE_DELETE_SERVICES=true
KUBE_DELETE_INGRESS=true
KUBE_DELETE_SERVICES=true
KUBE_DELETE_SERVICES=true

# Delete Pachyderm namespace
rancher kubectl delete namespaces pachyderm

# Delete Argo namespace
rancher kubectl delete namespaces argo

# Delete reana namespace
rancher kubectl delete namespaces reana

# Delete Secrets (you won't be able to login after!)
rancher kubectl delete secrets reana-ssl-secrets
rancher kubectl delete secrets --all


delete_docker_on_host () {
    echo -e "\n\n\n#####################\nWorking on Host: $1"
    # Remove Rancher Container
    CMD=""
    if [ -n "$1" ]; then
        CMD="ssh $1"
    fi
    echo "Remove rancher containers on host: ${1}"
    for ID in $(${CMD} docker ps |grep "rancher/" | awk '{print $1}'); do
        echo "Removing container with ID: $ID"
        #${CMD} docker kill ${ID}
        ${CMD} docker rm -f ${ID}
    done
    #echo "Stopping rancher containers"
    #${CMD} docker kill $(${CMD} docker ps -q --filter name=rancher)
    echo "Removing rancher containers"
    ${CMD} docker rm -f $(${CMD} docker ps -aq --filter name=rancher)

    # Delete all Kubernetes Containers
    #echo "Stopping kubernetes containers"
    #${CMD} docker kill $(${CMD} docker ps -q --filter name=k8s)
    echo "Removing kubernetes containers"
    ${CMD} docker rm -f $(${CMD} docker ps -aq --filter name=k8s)

    echo "Remove share-mnt container"
    ${CMD} docker rm -f share-mnt

    echo "Remove service-sidekick container"
    ${CMD} docker rm -f service-sidekick

    #echo "remove other rancher containers"
    #${CMD} docker rm -f kube-proxy
    #${CMD} docker rm -f kubelet
    #${CMD} docker rm -f kube-scheduler
    #${CMD} docker rm -f kube-controller-manager
    #${CMD} docker rm -f kube-apiserver
    #${CMD} docker rm -f etcd
    #${CMD} docker rm -f nginx-proxy

    echo "Delete all stopped containers"
    ${CMD} docker rm $(${CMD} docker ps -a -q)

    #echo "Delete all unused images"
    #${CMD} docker rmi $(${CMD} docker images -q)



    # Cleanup rke data
    # https://rancher.com/docs/rancher/v2.x/en/faq/cleaning-cluster-nodes/

    # Mounts (can't do this since we don't have the permission..)
    #for mount in $(${CMD} mount | grep tmpfs | grep '/var/lib/kubelet' | awk '{ print $3 }') /var/lib/kubelet /var/lib/rancher; do
    #    echo "umount $mount";
    #done

    echo "###################"
    if [ -z "$CMD" ]; then
        echo "Deleting files on this machine!"
        eval ${DELETE_COMMAND}
    else
        echo "Deleting remote files!"
        eval ${CMD} "'${DELETE_COMMAND}'"
    fi
    echo "###################"
}

for WORKER_NODE in "${WORKER_NODES[@]}"
do
    delete_docker_on_host ${WORKER_NODE}
done



echo "Remove config on localhost"
rm -r ~/.helm/
rm -r ~/.kube/cache/
rm -r ~/.kube/http-cache/
