#!/bin/bash

#set -e

if test "$BASH" != "/bin/bash"; then
    echo "Make sure you run this script with 'bash startCluster' in order to measure the time!"
    exit
fi



################################################################

HOST_IP=$(hostname -I | awk '{print $1}')

S3_STORAGE_HOST="minio-service:9000"
S3_STORAGE_USERNAME=minio
S3_STORAGE_PASSWORD=minio123
S3_STORAGE_BUCKET=pachyderm

ETCD_STORAGE="/home/david/persistent-storage/pachyderm-etcd"
NUM_ETCD_NODES=1

PROJECT_NAME="pachyderm"
NAMESPACE="pachyderm"

CLUSTER_NAME="test-cluster"

# enable custom registry
DOCKER_REGISTRY_ENABLED=false
DOCKER_REGISTRY_SERVER="hostname"
DOCKER_REGISTRY_USERNAME="username"
DOCKER_REGISTRY_PASSWORD="password"
DOCKER_REGISTRY_EMAIL="email"

# Size of pachd's in-memory cache for PFS files. Size is specified in bytes, with allowed SI suffixes (M, K, G, Mi, Ki, Gi, etc).
PACH_BLOCK_CACHE_SIZE=1G 
PACHD_HOST="node"


PACHCTL_VERSION=1.8.5

################################################################

# export path variable to include "tools" (kubectl / rancher / ...)
TOOLS_FOLDER="$(pwd)/tools/"
PATH="$PATH:${TOOLS_FOLDER}"
mkdir -p "${TOOLS_FOLDER}"

KC=./k3s/kubeconfig.yaml

CURRENT_DIR=$(pwd)

bold_font=$(tput bold)
normal_font=$(tput sgr0)


while true; do
    echo "${bold_font}Configuration:${normal_font}"
    echo "ETCD_STORAGE:            ${bold_font} ${ETCD_STORAGE} ${normal_font}"
    echo "NUM_ETCD_NODES:          ${bold_font} ${NUM_ETCD_NODES} ${normal_font}"
    echo "S3_STORAGE_HOST:         ${bold_font} ${S3_STORAGE_HOST} ${normal_font}"
    echo "S3_STORAGE_USERNAME:     ${bold_font} ${S3_STORAGE_USERNAME} ${normal_font}"
    echo "S3_STORAGE_PASSWORD:     ${bold_font} ${S3_STORAGE_PASSWORD} ${normal_font}"
    echo "S3_STORAGE_BUCKET:       ${bold_font} ${S3_STORAGE_BUCKET} ${normal_font}"
    if [ "$DOCKER_REGISTRY_ENABLED" = true ] ; then
      echo "DOCKER_REGISTRY_ENABLED: ${bold_font} ${DOCKER_REGISTRY_ENABLED} ${normal_font}"
      echo "DOCKER_REGISTRY_SERVER:  ${bold_font} ${DOCKER_REGISTRY_SERVER} ${normal_font}"
      echo "DOCKER_REGISTRY_USERNAME:${bold_font} ${DOCKER_REGISTRY_USERNAME} ${normal_font}"
      echo "DOCKER_REGISTRY_PASSWORD:${bold_font} ${DOCKER_REGISTRY_PASSWORD} ${normal_font}"
      echo "DOCKER_REGISTRY_EMAIL:   ${bold_font} ${DOCKER_REGISTRY_EMAIL} ${normal_font}"
    fi

    echo "PACH_BLOCK_CACHE_SIZE:   ${bold_font} ${PACH_BLOCK_CACHE_SIZE} ${normal_font}"
    echo "KUBE_CONFIG:             ${bold_font} ${KC} ${normal_font}"
    echo "PACHD_HOST:              ${bold_font} ${PACHD_HOST} ${normal_font}"
    echo "Tools Folder:            ${bold_font} ${TOOLS_FOLDER} ${normal_font}"
    echo " "
    read -p "Is this configuration correct? (y/n): " yn
    case $yn in
        [Yy]* ) break;;
        [Nn]* ) exit;;
        * ) echo "Please answer yes or no.";;
    esac
done


# Download Kubectl if necessary
if [ ! -f "${TOOLS_FOLDER}kubectl" ]; then
    echo "Kubectl not found.. downloading.."
    curl -L -o "${TOOLS_FOLDER}kubectl" https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
    chmod +x ${TOOLS_FOLDER}kubectl
    echo ""
fi

# Download pachctl if necessary
if [ ! -f "${TOOLS_FOLDER}pachctl" ]; then
    echo "pachctl not found.. downloading.."
    curl -L https://github.com/pachyderm/pachyderm/releases/download/v${PACHCTL_VERSION}/pachctl_${PACHCTL_VERSION}_linux_amd64.tar.gz | tar -xzv
    mv pachctl_${PACHCTL_VERSION}_linux_amd64/pachctl ${TOOLS_FOLDER}pachctl
    rm -r pachctl_${PACHCTL_VERSION}_linux_amd64
    echo ""
fi



###############################################################################
# Deployment of K3s
###############################################################################

git clone https://github.com/rancher/k3s.git
cd k3s

echo "Stop any running instances of k3s"
git reset HEAD --hard
docker-compose down -v --remove-orphans
cd $CURRENT_DIR

echo "Publish port"
sed -i "s#ports:#ports:\n    - \"30080:30080\"\n    - \"30650:30650\"\n    - \"30651:30651\"\n    - \"30652:30652\"\n    - \"30654:30654\"\n    - \"30999:30999\"#" k3s/docker-compose.yml
cd k3s
docker-compose up -d --scale node=1
cd $CURRENT_DIR


echo "K3s deployed.."






###############################################################################
# Deployment of Pachyderm
###############################################################################



until kubectl --kubeconfig=$KC cluster-info
do
  echo "Waiting for cluster to come online"
  sleep 1
done
sleep 20
kubectl --kubeconfig=$KC cluster-info


echo "#####################################"
echo "Cleanup - Manually deleting resources"
kubectl --kubeconfig=$KC delete service -l suite=pachyderm --namespace pachyderm
kubectl --kubeconfig=$KC delete deployments -l suite=pachyderm --namespace pachyderm
kubectl --kubeconfig=$KC delete StatefulSet -l suite=pachyderm --namespace pachyderm

kubectl --kubeconfig=$KC delete pvc -l suite=pachyderm --namespace pachyderm
PVs=($(kubectl --kubeconfig=$KC get pv | grep "pachyderm-etcd-pv" | cut -d " " -f 1))
for PV in "${PVs[@]}"; do
    kubectl --kubeconfig=$KC delete pv $PV
done


kubectl --kubeconfig=$KC delete storageclass --namespace pachyderm etcd-storage-class
kubectl --kubeconfig=$KC delete clusterrolebinding --namespace pachyderm pachyderm
kubectl --kubeconfig=$KC delete clusterroles --namespace pachyderm pachyderm

kubectl --kubeconfig=$KC delete replicationcontroller -l suite=pachyderm --namespace pachyderm

kubectl --kubeconfig=$KC delete namespace ${NAMESPACE}




echo "#####################################"
echo "Create namespace: ${NAMESPACE}"
kubectl --kubeconfig=$KC create namespace ${NAMESPACE}


echo "Waiting for namespace to be created.."
sleep 5

echo ""
echo "Namespaces:"
kubectl --kubeconfig=$KC get namespaces
echo ""

echo "Wait..";
sleep 5;

if [ "$DOCKER_REGISTRY_ENABLED" = true ] ; then
	echo "Creating docker secret for namespace: ${NAMESPACE}"
	kubectl --kubeconfig=$KC create secret docker-registry docker-registry-pachyderm --namespace=pachyderm --docker-server="${DOCKER_REGISTRY_SERVER}" --docker-username="${DOCKER_REGISTRY_USERNAME}" --docker-password="${DOCKER_REGISTRY_PASSWORD}" --docker-email="${DOCKER_REGISTRY_EMAIL}"
	echo "Done!"
fi



echo "Deploying Minio"
kubectl --kubeconfig=$KC create -n pachyderm -f minio-pv.yaml
kubectl --kubeconfig=$KC create -n pachyderm -f minio-deployment.yaml
kubectl --kubeconfig=$KC wait --timeout=400s --for condition=ready -n pachyderm pod -l=app=minio



echo "Deploying Pachyderm connection"
# pachctl deploy custom --persistent-disk google --object-store s3 <persistent disk name> <persistent disk size> <object store bucket> <object store id> <object store secret> <object store endpoint> --static-etcd-volume=${STORAGE_NAME} --dry-run > deployment.json
pachctl deploy custom --namespace ${NAMESPACE} --dynamic-etcd-nodes $NUM_ETCD_NODES --block-cache-size ${PACH_BLOCK_CACHE_SIZE} --persistent-disk google --object-store s3 pachyderm-s3 10 ${S3_STORAGE_BUCKET} ${S3_STORAGE_USERNAME} ${S3_STORAGE_PASSWORD} ${S3_STORAGE_HOST} --dry-run > deployment.json
echo -e "Done..\n"


echo "Deploying pachyderm"
#kubectl create -n ${NAMESPACE} -f etcd-pv.yaml
for i in $(seq 1 $NUM_ETCD_NODES); do
    echo "Creating PV for pachyderm: $i"
    sed "s#PATH-TO-ETCD#${ETCD_STORAGE}-$i/#" ../workflow-engines/pachyderm/etcd-pv.yaml > etcd-pv-adjusted.yaml
    sed -i "s#pachyderm-etcd-pv#pachyderm-etcd-pv-$i#" etcd-pv-adjusted.yaml
    kubectl --kubeconfig=$KC create -n ${NAMESPACE} -f etcd-pv-adjusted.yaml
done


kubectl --kubeconfig=$KC create -n ${NAMESPACE} -f deployment.json
echo -e "Done..\n"

echo "Deployment successful.. please standy by.. this might take some time.."
echo "Waiting for pachd"
kubectl --kubeconfig=$KC wait --timeout=400s --for condition=ready -n pachyderm pod -l=app=pachd
kubectl --kubeconfig=$KC wait --timeout=400s --for condition=ready -n pachyderm pod -l=app=etcd

# todo automate this!!!
export PACHD_ADDRESS=${PACHD_HOST}:30650
pachctl version

tools/kubectl --kubeconfig=./k3s/kubeconfig.yaml get services -n pachyderm
tools/kubectl --kubeconfig=./k3s/kubeconfig.yaml get pods -n pachyderm

#tools/kubectl --kubeconfig=./k3s/kubeconfig.yaml logs -n pachyderm 

tools/kubectl --kubeconfig=./k3s/kubeconfig.yaml describe pods -n pachyderm

: '
docker run -v /home/dluhmer/development/persistent-storage:/home/dluhmer/development/persistent-storage ubuntu:16.04 /bin/bash -c "rm -rf /home/dluhmer/development/persistent-storage"
'
