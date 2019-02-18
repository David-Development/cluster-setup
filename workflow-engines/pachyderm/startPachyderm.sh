#!/bin/bash

set -e

if test "$BASH" != "/bin/bash"; then
    echo "Make sure you run this script with 'bash startCluster' in order to measure the time!"
    exit
fi



################################################################

S3_STORAGE_HOST=<host-name>:9001
S3_STORAGE_USERNAME=minio
S3_STORAGE_PASSWORD=minio123
S3_STORAGE_BUCKET=audio-mining

ETCD_STORAGE="/home/dluhmer/development/persistent-storage/pachyderm-etcd"
NUM_ETCD_NODES=1

PROJECT_NAME="pachyderm"
NAMESPACE="pachyderm"

CLUSTER_NAME="test-cluster"

# enable custom registry
DOCKER_REGISTRY_ENABLED=false
DOCKER_REGISTRY_SERVER=<hostname>
DOCKER_REGISTRY_USERNAME=<username>
DOCKER_REGISTRY_PASSWORD=<password>
DOCKER_REGISTRY_EMAIL=<email>

PACHD_HOST=<hostname>

RANCHER_CLI_VERSION=v2.0.6

PACHCTL_VERSION=1.8.4

################################################################

# export path variable to include "tools" (kubectl / rancher / ...)
TOOLS_FOLDER="$(pwd)/tools/"
PATH="$PATH:${TOOLS_FOLDER}"
mkdir -p "${TOOLS_FOLDER}"

KC=~/.rancher/kubeconfig

bold_font=$(tput bold)
normal_font=$(tput sgr0)


while true; do
    echo "${bold_font}Configuration:${normal_font}"
    echo "ETCD_STORAGE:        ${bold_font} ${ETCD_STORAGE} ${normal_font}"
    echo "NUM_ETCD_NODES:      ${bold_font} ${NUM_ETCD_NODES} ${normal_font}"
    echo "S3_STORAGE_HOST:     ${bold_font} ${S3_STORAGE_HOST} ${normal_font}"
    echo "S3_STORAGE_USERNAME: ${bold_font} ${S3_STORAGE_USERNAME} ${normal_font}"
    echo "S3_STORAGE_PASSWORD: ${bold_font} ${S3_STORAGE_PASSWORD} ${normal_font}"
    echo "S3_STORAGE_BUCKET:  ${bold_font} ${S3_STORAGE_BUCKET} ${normal_font}"
    echo "DOCKER_REGISTRY_ENABLED: ${bold_font} ${DOCKER_REGISTRY_ENABLED} ${normal_font}"
    echo "DOCKER_REGISTRY_SERVER:  ${bold_font} ${DOCKER_REGISTRY_SERVER} ${normal_font}"
    echo "DOCKER_REGISTRY_USERNAME:${bold_font} ${DOCKER_REGISTRY_USERNAME} ${normal_font}"
    echo "DOCKER_REGISTRY_PASSWORD:${bold_font} ${DOCKER_REGISTRY_PASSWORD} ${normal_font}"
    echo "DOCKER_REGISTRY_EMAIL:   ${bold_font} ${DOCKER_REGISTRY_EMAIL} ${normal_font}"
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


# Download Rancher if necessary
if [ ! -f "${TOOLS_FOLDER}rancher" ]; then
    echo "Rancher not found.. downloading.."
    curl -L https://github.com/rancher/cli/releases/download/${RANCHER_CLI_VERSION}/rancher-linux-amd64-${RANCHER_CLI_VERSION}.tar.gz | tar xz -C $TOOLS_FOLDER
    mv $TOOLS_FOLDER/rancher-${RANCHER_CLI_VERSION}/rancher $TOOLS_FOLDER/rancher
    rm -r $TOOLS_FOLDER/rancher-${RANCHER_CLI_VERSION}/
    chmod +x ${TOOLS_FOLDER}rancher
    echo ""
fi

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


if rancher projects | grep ${PROJECT_NAME}; then
    echo "Project already found.. Emergeny exit! Please remove the existing project ${PROJECT_NAME} before trying to create it again";
    exit
fi



###############################################################################
# Deployment of Pachyderm
###############################################################################


echo "Create project: ${PROJECT_NAME}"
rancher projects create ${PROJECT_NAME}
echo "Create namespace: ${NAMESPACE}"
rancher namespaces create ${NAMESPACE}


echo "Waiting for project and namespace to be created.."
sleep 10

echo ""
echo "Projects:"
rancher projects
echo ""
echo "Namespaces:"
rancher namespaces
echo ""
#echo "Paste pachyderm project id:"
#read PACHYDERM_PROJ_ID
PACHYDERM_PROJ_ID=$(rancher projects | grep "pachyderm" | awk '{print $1;}')
echo "Associate namespace \"${NAMESPACE}\" to project: ${PACHYDERM_PROJ_ID}"
rancher namespace move "${NAMESPACE}" "${PACHYDERM_PROJ_ID}";

echo "Done!";

echo "Wait..";
sleep 15;

if [ "$DOCKER_REGISTRY_ENABLED" = true ] ; then
	echo "Creating docker secret for namespace: ${NAMESPACE}"
	rancher kubectl create secret docker-registry docker-registry-pachyderm --namespace=pachyderm --docker-server="${DOCKER_REGISTRY_SERVER}" --docker-username="${DOCKER_REGISTRY_USERNAME}" --docker-password="${DOCKER_REGISTRY_PASSWORD}" --docker-email="${DOCKER_REGISTRY_EMAIL}"
	echo "Done!"
fi




echo "Deploying S3 connection"
# pachctl deploy custom --persistent-disk google --object-store s3 <persistent disk name> <persistent disk size> <object store bucket> <object store id> <object store secret> <object store endpoint> --static-etcd-volume=${STORAGE_NAME} --dry-run > deployment.json
pachctl deploy custom --namespace ${NAMESPACE} --dynamic-etcd-nodes $NUM_ETCD_NODES --block-cache-size 50G --persistent-disk google --object-store s3 pachyderm-s3 10 ${S3_STORAGE_BUCKET} ${S3_STORAGE_USERNAME} ${S3_STORAGE_PASSWORD} ${S3_STORAGE_HOST} --dry-run > deployment.json
echo -e "Done..\n"


echo "Deploying pachyderm"
#rancher kubectl create -n ${NAMESPACE} -f etcd-pv.yaml
for i in $(seq 1 $NUM_ETCD_NODES); do
    echo "Creating PV for pachyderm: $i"
    sed "s#PATH-TO-ETCD#${ETCD_STORAGE}-$i/#" etcd-pv.yaml > etcd-pv-adjusted.yaml
    sed -i "s#pachyderm-etcd-pv#pachyderm-etcd-pv-$i#" etcd-pv-adjusted.yaml
    rancher kubectl create -n ${NAMESPACE} -f etcd-pv-adjusted.yaml
done


rancher kubectl create -n ${NAMESPACE} -f deployment.json
echo -e "Done..\n"


sleep 60

# todo automate this!!!
export PACHD_ADDRESS=${PACHD_HOST}:30650
pachctl version

: '
docker run -v /home/dluhmer/development/persistent-storage:/home/dluhmer/development/persistent-storage ubuntu:16.04 /bin/bash -c "rm -rf /home/dluhmer/development/persistent-storage"
'
