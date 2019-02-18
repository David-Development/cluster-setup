#!/bin/bash

######################################
# Edit those config parameters

CLUSTER_NAME="test-cluster"

######################################

KC=rancher-kubeconfig # filename for rancher-kubeconfig

if test "$BASH" != "/bin/bash"; then
    echo "Make sure you run this script with 'bash' in order to measure the time!"
    exit
fi

PATH="$(pwd)/tools:$PATH"

echo "Starting training "`date '+%Y-%m-%d %H:%M:%S'`

# Count duration (https://stackoverflow.com/a/8903280)
SECONDS=0


rancher kubectl config view --raw ${CLUSTER_NAME} > $KC

OUTPUT=$(argo --kubeconfig="${KC}" submit speech-training.yaml)
JOB_NAME=$(echo $OUTPUT | awk '{ print $2 }')
#argo get $JOB_NAME
watch --color -n 5 argo --kubeconfig="${KC}" get $JOB_NAME
#argo wait $JOB_NAME

echo "Done training "`date '+%Y-%m-%d %H:%M:%S'`

duration=$SECONDS
date -u -d @"$duration" +'%-Mm %-Ss'
