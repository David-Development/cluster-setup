#!/bin/bash

if test "$BASH" != "/bin/bash"; then
    echo "Make sure you run this script with 'bash startCluster' in order to measure the time!"
    exit
fi

######################################
# Edit those config parameters

PROJECT_NAME="argo"
NAMESPACE="argo"

CLUSTER_NAME="test-cluster"

ARGO_CLI_VERSION="v2.2.1"
ARGO_WEB_VERSION="v2.2.1"
RANCHER_CLI_VERSION=v2.0.4
RANCHER_VERSION=v2.0.8

######################################




MINIO_ADDRESS="minio-service:9000" # kubernetes cluster

# export path variable to include "tools" (kubectl / rancher / ...)
TOOLS_FOLDER="$(pwd)/tools/"
PATH="$PATH:${TOOLS_FOLDER}"
mkdir -p "${TOOLS_FOLDER}"

KC=~/.rancher/kubeconfig


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

# Download Argo if necessary
if [ ! -f "${TOOLS_FOLDER}argo" ]; then
    echo "Argo not found.. downloading.."
    curl -L -o "${TOOLS_FOLDER}argo" https://github.com/argoproj/argo/releases/download/${ARGO_CLI_VERSION}/argo-linux-amd64
    chmod +x ${TOOLS_FOLDER}argo
    echo ""
fi


if rancher projects | grep "argo"; then
    echo "Project already found.. Emergeny exit! Please remove the existing project ${PROJECT_NAME} before trying to create it again";
    exit
fi



###############################################################################
# Deployment of Argo and Minio
###############################################################################

echo "Create argo project"
rancher projects create ${PROJECT_NAME}
echo "Create argo namespace"
rancher namespaces create ${NAMESPACE}

#${ARGO_CLI} install --enable-web-console -n argo # api v2.1
echo "Install Argo Services.."
rancher kubectl apply -n ${NAMESPACE} -f https://raw.githubusercontent.com/argoproj/argo/${ARGO_WEB_VERSION}/manifests/install.yaml

echo ""
echo ""
rancher projects
echo ""
#echo "Paste argo project id:"
#read ARGO_PROJ_ID
ARGO_PROJ_ID=$(rancher projects | grep "${PROJECT_NAME}" | awk '{print $1;}')
echo "Associate argo namespace to project.. (${ARGO_PROJ_ID})"
rancher namespace associate "${NAMESPACE}" "${ARGO_PROJ_ID}"

echo "Done!"
echo "waiting for cluster .. hang in there.. "

sleep 15

# make UI accessible from the outside
#rancher kubectl patch svc argo-ui -n ${NAMESPACE} -p '{"spec": {"type": "LoadBalancer"}}' # this does not work on-premise!
#rancher kubectl port-forward $(kubectl get pods -n kube-system -l app=argo-ui -o jsonpath="{.items[0].metadata.name}") -n kube-system 8001:8001 &
#sleep 3
#xdg-open http://127.0.0.1:8001/workflows
#rancher kubectl create -f persistent-volume-minio.yaml
# https://github.com/kubernetes/examples/tree/master/staging/storage/minio/
#rancher kubectl create -f persistent-volume-minio.yaml


echo "Deploy minio persistent volume.."
rancher kubectl create -f minio-standalone-pv.yaml

echo "Deploy minio persistent volume claim.."
rancher kubectl create -f minio-standalone-pvc.yaml
#rancher kubectl create -f https://raw.githubusercontent.com/kubernetes/examples/master/staging/storage/minio/minio-standalone-pvc.yaml

echo "Deploy minio.."
rancher kubectl create -f minio-standalone-deployment.yaml
#rancher kubectl create -f https://raw.githubusercontent.com/kubernetes/examples/master/staging/storage/minio/minio-standalone-deployment.yaml

echo "Deploy minio service.."
rancher kubectl create -f minio-standalone-service.yaml
#rancher kubectl create -f https://github.com/kubernetes/examples/raw/master/staging/storage/minio/minio-standalone-service.yaml

#rancher  kubectl expose deployment/minio-deployment
#rancher  kubectl get svc minio-deployment

echo "wait.."

sleep 5

MINIO_NODE=$(rancher kubectl get pods --selector=app=minio -o jsonpath='{.items[*].spec.nodeName}')
MINIO_NODE=($MINIO_NODE)
MINIO_NODE=${MINIO_NODE[0]}
MINIO_NODE_URL="http://${MINIO_NODE}:9001"
echo "${MINIO_NODE_URL}"
xdg-open "${MINIO_NODE_URL}"




###############################################################################
# Configuration of services
###############################################################################

echo "Create rolebinding for argo to save outputs (check status of bug here: https://github.com/argoproj/argo/issues/983#issuecomment-423226278)"
#rancher kubectl create clusterrolebinding default-admin --clusterrole cluster-admin --serviceaccount=default:default
rancher kubectl create rolebinding default-admin --clusterrole=admin --serviceaccount=default:default




echo ""
echo "Upload minio config.."
rancher kubectl patch configmap workflow-controller-configmap -n ${NAMESPACE} --type merge --patch "$(cat minio-config.yaml)"

echo "wait..."
sleep 5

echo "Getting kube-config (required for argo)"
rancher kubectl config view --raw --cluster="${CLUSTER_NAME}" > $KC

echo ""
echo "Upload dummy workflows"
argo --kubeconfig=$KC submit https://raw.githubusercontent.com/argoproj/argo/master/examples/artifact-passing.yaml
argo --kubeconfig=$KC submit https://raw.githubusercontent.com/argoproj/argo/master/examples/loops-param-result.yaml

echo ""
#echo "Forwarding Argo-UI Port now.. (this call is blocking therefore this script won't exit)"
#rancher kubectl -n argo port-forward deployment/argo-ui 8001:8001

rancher kubectl patch deployment argo-ui -n argo --type='json' -p='[{"op": "add", "path": "/spec/template/spec/containers/0/ports", "value": [{"hostPort": 8001, "containerPort": 8001}]}]'

rancher kubectl get deployment argo-ui -n argo -o wide

echo "wait..."
sleep 3

#rancher kubectl get pods -n argo --selector=app=argo-ui -o wide
ARGO_UI_NODE=$(rancher kubectl get pods -n argo --selector=app=argo-ui -o jsonpath='{.items[*].spec.nodeName}')
ARGO_UI_NODE=($ARGO_UI_NODE)
ARGO_UI_NODE=${ARGO_UI_NODE[0]}
ARGO_UI_URL="http://${ARGO_UI_NODE}:8001/workflows"

echo "${ARGO_UI_URL}"

echo "wait..."
sleep 10

xdg-open "${ARGO_UI_URL}"

# Kill port-forwards after this script exists!
#trap 'kill $(jobs -p)' EXIT
#wait

#rancher kubectl get svc argo-ui -n ${NAMESPACE}


###############################################################################
# Install Weave Scope Monitor
###############################################################################

# Install Weave Scope
#rancher kubectl apply -f "https://cloud.weave.works/k8s/scope.yaml?k8s-version=$(rancher kubectl version | base64 | tr -d '\n')"
#sleep 10
#rancher kubectl port-forward -n weave "$(rancher kubectl get -n weave pod --selector=weave-scope-component=app -o jsonpath='{.items..metadata.name}')" 4040



# Submit language model training
# argo --kubeconfig=$KC submit ./speech-training.yaml



