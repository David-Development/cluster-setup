#!/bin/bash

if test "$BASH" != "/bin/bash"; then
    echo "Make sure you run this script with 'bash startCluster' in order to measure the time!"
    exit
fi

################################################################

PROJECT_NAME="pachyderm"
NAMESPACE="pachyderm"

CLUSTER_NAME="test-cluster"

S3_STORAGE_HOST="ip/hostname:9001"
S3_STORAGE_USERNAME=minio
S3_STORAGE_PASSWORD=minio123
S3_STORAGE_BUCKET=audio-mining

PACHCTL_HOST="ip/hostname:30650"
# todo filter node out by using node name from: tools/rancher kubectl get pods -o wide -n pachyderm | grep "pachd"

################################################################

KC=~/.rancher/kubeconfig

# export path variable to include "tools" (kubectl / rancher / ...)
TOOLS_FOLDER="$(pwd)/tools/"
PATH="$PATH:${TOOLS_FOLDER}"
mkdir -p "${TOOLS_FOLDER}"


if [ -f ./etcd-pv-adjusted.yaml ]; then
    ETCD_PATH=$(grep "path" ./etcd-pv-adjusted.yaml | cut -d'"' -f 2)
fi



bold_font=$(tput bold)
normal_font=$(tput sgr0)

while true; do
    echo "${bold_font}Configuration:${normal_font}"
    echo "PACHCTL_HOST:       ${bold_font} ${PACHCTL_HOST} ${normal_font}"
    echo "S3_STORAGE_HOST:    ${bold_font} ${S3_STORAGE_HOST} ${normal_font}"
    echo "S3_STORAGE_USERNAME:${bold_font} ${S3_STORAGE_USERNAME} ${normal_font}"
    echo "S3_STORAGE_PASSWORD:${bold_font} ${S3_STORAGE_PASSWORD} ${normal_font}"
    echo "S3_STORAGE_BUCKET:  ${bold_font} ${S3_STORAGE_BUCKET} ${normal_font}"
    echo "Project Name:       ${bold_font} ${PROJECT_NAME} ${normal_font}"
    echo "Namespace Name:     ${bold_font} ${NAMESPACE} ${normal_font}"
    echo "ETCD_PATH:          ${bold_font} ${ETCD_PATH} ${normal_font}"
    echo " "
    read -p "Is this configuration correct? (y/n): " yn
    case $yn in
        [Yy]* ) break;;
        [Nn]* ) exit;;
        * ) echo "Please answer yes or no.";;
    esac
done



export PACHD_ADDRESS=$PACHCTL_HOST

echo ""
# warning! this deletes everything
echo "Deleting everything in pachyderm.."
#pachctl delete-all --verbose
yes | pachctl delete-all

echo "Running pachyderm garbage collection.."
#pachctl garbage-collect --verbose
pachctl garbage-collect

# list all projects
rancher projects

echo "Undeploy pachyderm"
# http://docs.pachyderm.io/en/latest/pachctl/pachctl_undeploy.html
rancher kubectl config view --raw > ~/.kube/config
pachctl undeploy --namespace pachyderm --all
echo "Done.. wait"
sleep 10

echo "Manually deleting resources"
rancher kubectl delete service -l suite=pachyderm --namespace pachyderm
rancher kubectl delete deployments -l suite=pachyderm --namespace pachyderm
rancher kubectl delete StatefulSet -l suite=pachyderm --namespace pachyderm

rancher kubectl delete pvc -l suite=pachyderm --namespace pachyderm
#rancher kubectl delete pv pachyderm-etcd-pv
PVs=($(rancher kubectl get pv | grep "pachyderm-etcd-pv" | cut -d " " -f 1))
for PV in "${PVs[@]}"; do
    rancher kubectl delete pv $PV
done


rancher kubectl delete storageclass --namespace pachyderm etcd-storage-class
rancher kubectl delete clusterrolebinding --namespace pachyderm pachyderm
rancher kubectl delete clusterroles --namespace pachyderm pachyderm

rancher kubectl delete replicationcontroller -l suite=pachyderm --namespace pachyderm


echo -e "Done..\n"

read -n 1 -s -r -p "Press any key to continue"

echo ""
echo "Deleting namespace.."
rancher kubectl delete namespace pachyderm

echo "Deleting project.."
rancher projects rm pachyderm

echo "Deleting leftovers in s3 storage.."
docker run minio/mc bash -c "mc config host add minio http://${S3_STORAGE_HOST} \"minio\" \"minio123\"; mc config host ls; mc rm --recursive --force minio/${S3_STORAGE_BUCKET}/pach/"


# TODO ADJUST !!!!!!
COMMAND="docker run -v /home/dluhmer/development/:/data-dir ubuntu:16.04 /bin/bash -c \"rm -r /data-dir/minio-distributed/*\""
echo "ssh <host> '$COMMAND'"


if [ ! -z $ETCD_PATH ]; then
    echo "ETCD_PATH is set!"
    echo "Removing etcd storage: $ETCD_PATH"
    echo "Run the following command to clear the etcd cache"

    DIR_ETCD_PATH=$(dirname ${ETCD_PATH})
    FOLDER_ETCD_PATH=$(basename ${ETCD_PATH})
    COMMAND="docker run -v $DIR_ETCD_PATH:/data-dir ubuntu:16.04 /bin/bash -c \"rm -r /data-dir/$FOLDER_ETCD_PATH\""
    echo "ssh <host> '$COMMAND'"
    #read -n 1 -s -r -p "Press any key to continue"
    #$COMMAND
fi

echo "Done"
