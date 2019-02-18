#!/bin/bash

if test "$BASH" != "/bin/bash"; then
    echo "Make sure you run this script with 'bash startCluster' in order to measure the time!"
    exit
fi

# export path variable to include "tools" (kubectl / rancher / ...)
TOOLS_FOLDER="$(pwd)/tools/"
PATH="$PATH:${TOOLS_FOLDER}"
mkdir -p "${TOOLS_FOLDER}"

PROJECT_NAME="argo"
NAMESPACE="argo"


rancher projects delete ${PROJECT_NAME}

rancher kubectl delete service minio-service
rancher kubectl delete deployment minio-deployment
rancher kubectl delete pvc minio-pv-claim
rancher kubectl delete pv minio-pv

rancher kubectl delete pv minio-persistent-volume

rancher kubectl delete ingress minio-service-ingress


# Delete Service Account for Argo
rancher kubectl delete rolebinding default-admin