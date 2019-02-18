#!/bin/bash

if test "$BASH" != "/bin/bash"; then
    echo "Make sure you run this script with 'bash startCluster' in order to measure the time!"
    exit
fi

if [ -z $1 ]; then
      echo "No cluster name given! Run script like this: bash startCluster.sh <clustername>"
      exit 1
fi

RANCHER_USERNAME="admin"
RANCHER_PASSWORD="admin"
CLUSTER_NAME="$1"
DEPLOY_KUBERNETES_DASHBOARD=true # true/false

HOST_IP=$(hostname -I | awk '{print $1}')

# export path variable to include "tools" (kubectl / rancher / ...)
TOOLS_FOLDER="$(pwd)/tools/"
PATH="${TOOLS_FOLDER}:$PATH"


cat ../signatures/signature-kubernetes.txt

###############################################################################
# check cluster config
###############################################################################

bold_font=$(tput bold)
normal_font=$(tput sgr0)

while true; do
    echo "${bold_font}Configuration:${normal_font}"
    echo "Rancher Username:${bold_font} ${RANCHER_USERNAME} ${normal_font}"
    echo "Rancher Password:${bold_font} ${RANCHER_PASSWORD} ${normal_font}"
    echo "Cluster Name:    ${bold_font} ${CLUSTER_NAME} ${normal_font}"
    echo "Rancher-IP:      ${bold_font} ${HOST_IP} ${normal_font}"
    echo "Kube Dashboard:  ${bold_font} ${DEPLOY_KUBERNETES_DASHBOARD} ${normal_font}"
    echo "Tools Folder:    ${bold_font} ${TOOLS_FOLDER} ${normal_font}"
    echo " "
    read -p "Is this configuration correct? (y/n): " yn
    case $yn in
        [Yy]* ) break;;
        [Nn]* ) exit;;
        * ) echo "Please answer yes or no.";;
    esac
done


###############################################################################
# Download required tools if necessary
###############################################################################

#RANCHER_CLI_VERSION=v2.0.4
#RANCHER_VERSION=v2.0.8
RANCHER_CLI_VERSION=v2.2.0-rc5
RANCHER_VERSION=v2.1.6

mkdir -p ${TOOLS_FOLDER}

# Download Rancher if necessary
if [ ! -f "${TOOLS_FOLDER}rancher" ]; then
    echo "Rancher not found.. downloading.."
    curl -L https://github.com/rancher/cli/releases/download/${RANCHER_CLI_VERSION}/rancher-linux-amd64-${RANCHER_CLI_VERSION}.tar.gz | tar xz -C ${TOOLS_FOLDER}
    mv ${TOOLS_FOLDER}/rancher-${RANCHER_CLI_VERSION}/rancher ${TOOLS_FOLDER}/rancher
    rm -r ${TOOLS_FOLDER}/rancher-${RANCHER_CLI_VERSION}/
    echo ""
fi

# Download Kubectl if necessary
if [ ! -f "${TOOLS_FOLDER}kubectl" ]; then
    echo "Kubectl not found.. downloading.."
    curl -L -o "${TOOLS_FOLDER}kubectl" https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
    chmod +x ${TOOLS_FOLDER}kubectl
    echo ""
fi

###############################################################################
# start cluster
###############################################################################

echo "Start Cluster"
# Start rancher ui container locally
docker run -d --name=rancher --restart=unless-stopped -p 8080:80 -p 8443:443 rancher/rancher:${RANCHER_VERSION}

echo "Waiting for Rancher to start"
# Wait for Rancher to be online (API needs to return http-status-code 200)
while [[ "$(curl -L --insecure -s -o /dev/null -w ''%{http_code}'' https://${HOST_IP}:8443)" != "200" ]]; do
    sleep 1;
done
sleep 5;

###############################################################################
# automate login/registration for rancher-ui
###############################################################################


echo "Request Login.."
curl --insecure -c cookies.txt \
    -H 'Accept: application/json' \
    -H 'content-type: application/json' \
    --data "{\"username\":\"${RANCHER_USERNAME}\",\"password\":\"${RANCHER_PASSWORD}\",\"description\":\"UI Session\",\"responseType\":\"cookie\",\"labels\":{\"ui-session\":\"true\"}}" \
    https://${HOST_IP}:8443/v3-public/localProviders/local?action=login

echo "Set login data.."
curl --insecure -b cookies.txt -X POST \
    -H 'Accept: application/json' \
    -H 'content-type: application/json' \
    --data "{\"currentPassword\":\"${RANCHER_USERNAME}\",\"newPassword\":\"${RANCHER_PASSWORD}\"}" \
    https://${HOST_IP}:8443/v3/users?action=changepassword

echo "Set Server URL to ${HOST_IP}"
curl --insecure -b cookies.txt -X PUT \
      -H 'Accept: application/json' \
      -H 'content-type: application/json' \
      --data "{\"baseType\":\"setting\",\"customized\":false,\"id\":\"server-url\",\"name\":\"server-url\",\"type\":\"setting\",\"value\":\"https://${HOST_IP}:8443\"}" \
      https://${HOST_IP}:8443/v3/settings/server-url

echo "Request Token.."
TOKEN_RESPONSE=$(curl --insecure -b cookies.txt \
    -H 'Accept: application/json' \
    -H 'content-type: application/json' \
    --data '{"expired":false,"isDerived":false,"ttl":0,"type":"token","description":"rancher-ui"}' \
    "https://${HOST_IP}:8443/v3/token")


# delete cookie file
rm cookies.txt

echo "Parse Token.."
# extract token from json response
BEARER_TOKEN=$(echo $TOKEN_RESPONSE | grep -Po '\"token\":\"([^\"]*)')
BEARER_TOKEN=${BEARER_TOKEN:9}
echo "Using Token: $BEARER_TOKEN"

echo "$BEARER_TOKEN" > rancher-login-token.txt

###############################################################################
# use rancher-cli to create cluster
###############################################################################


CLUSTER_STATE=$(rancher cluster)
if [[ $CLUSTER_STATE == *${CLUSTER_NAME}* ]]; then
  echo "Cluster is still active! Emergency Exit!"
  exit;
fi

# clear cache
rm ~/.rancher/cli2.json

# Login to rancher using the token we just received (Automatically accept signature)
echo "yes" | rancher login https://${HOST_IP}:8443 --token ${BEARER_TOKEN}
echo -e "\n"

echo -e "Done!\n\nCreate Cluster.."
# create cluster in rancher
rancher cluster create --rke-config cluster-config.yaml ${CLUSTER_NAME}
echo -e "Done!\n\nLogin again to get rid of warning.."

# Login again (to select default cluster..) (Automatically accept signature)
#echo -e "yes\n1\n" | rancher login https://${HOST_IP}:8443 --token ${BEARER_TOKEN}
rancher login https://${HOST_IP}:8443 --token ${BEARER_TOKEN}

# Open Rancher UI in Browser
xdg-open "http://${HOST_IP}:8080"


echo -e "Done!\n\nAdd master node to it.. (etcd / management / worker)"
ADD_NODE_COMMAND=$(rancher clusters add-node --etcd --controlplane --worker ${CLUSTER_NAME})
ADD_NODE_DOCKER_COMMAND=$(echo "$ADD_NODE_COMMAND" | grep -o "docker.*")
$ADD_NODE_DOCKER_COMMAND
echo -e "Done!\n\n"


###############################################################################
# wait for cluster
###############################################################################


echo "$(date) Waiting for cluster to come online!"
echo " "
STATUS=""
until [[ $STATUS == "${CLUSTER_NAME} active" ]]; do
    echo -e "$STATUS"
    sleep 5
    STATUS=$(rancher clusters ls --format "{{.Cluster.Name}} {{.Cluster.State}}" | grep "${CLUSTER_NAME}")
done
echo "$(date) Cluster is online!"



# copy config to local dir
echo "Copying kube config to local system (~/.kube/config)"
mkdir ~/.kube/
rancher kubectl config view --raw ${CLUSTER_NAME} > ~/.kube/config

: '
###############################################################################
# adjust local kubectl config files
###############################################################################

mkdir ~/.kube/

# Replace local kube-config file to connect to cluster
echo "Replacing kubernetes config file"
cp ~/.kube/config ~/.kube/config.bak

# use raw flag below to include ssl certificate information - otherwise the certificate will be REDACTED
# (https://github.com/kubernetes/kubernetes/issues/61573#issuecomment-375512405)
rancher kubectl config view --raw ${CLUSTER_NAME} > ~/.kube/config
cp ~/.kube/config ./kubeconfig

'

: '
# install minio
./tools/helm init
./tools/helm del --purge argo-artifacts
./tools/helm install stable/minio --name argo-artifacts --set persistence.enabled=false

sleep 5

echo "Forwarding minio port now!"
kubectl port-forward $(kubectl get pods -l app=minio -o jsonpath="{.items[0].metadata.name}") 9001:9000 &

sleep 3

#xdg-open "http://${HOST_IP}:9001"
xdg-open "http://127.0.0.1:9001"

echo "AccessKey: AKIAIOSFODNN7EXAMPLE"
echo "SecretKey: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
echo "Create a bucket named audio-mining from the Minio UI."
echo " "
read -p "Configure bucket, then press enter"


# Configure Minio
kubectl patch configmap workflow-controller-configmap -n kube-system --type merge --patch "$(cat MiniKube/minio_config.yaml)"

#./tools/argo submit https://raw.githubusercontent.com/argoproj/argo/master/examples/artifact-passing.yaml
./tools/argo submit https://raw.githubusercontent.com/argoproj/argo/master/examples/loops-param-result.yaml


echo "Forward port on localhost.."
ssh -N -L 0.0.0.0:9002:localhost:9001 dluhmer@nm-xxx
'

# Configure the use of minio
# echo -n 'minio' | base64
# echo -n 'minio123' | base64
# rancher kubectl create -f minio-secret.yaml


###############################################################################
# configure S3 storage
###############################################################################

rancher kubectl apply -f minio-secret.yaml


###############################################################################
# add kubernetes dashboard to cluster
# https://gist.github.com/superseb/3a9c0d2e4a60afa3689badb1297e2a44
###############################################################################

if [ "$DEPLOY_KUBERNETES_DASHBOARD" = true ] ; then
    echo "Deploy Kubernetes Dashboard"

    # Deploy kubernetes dashboard
    #rancher kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/master/src/deploy/recommended/kubernetes-dashboard.yaml
    rancher kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v1.10.1/src/deploy/recommended/kubernetes-dashboard.yaml
    rancher kubectl rollout status deploy/kubernetes-dashboard -n kube-system

    # Change Service Type to NodePort
    rancher kubectl get svc/kubernetes-dashboard  -n kube-system  -o yaml | sed 's/ClusterIP/NodePort/g' | rancher kubectl apply -f -

    # Create ServiceAccount and token to login
    rancher kubectl create -f dashboard.yml

    # publish on host-port 8444
    rancher kubectl patch deployment kubernetes-dashboard  -n kube-system --type='json' -p='[{"op": "add", "path": "/spec/template/spec/containers/0/ports/0/hostPort", "value": 8444}]'

    # Get Token
    # kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | grep admin-user | awk '{print $1}')
    KUBE_DASHBOARD_TOKEN=$(rancher kubectl -n kube-system describe secret $(rancher kubectl -n kube-system get secret | grep admin-user | awk '{print $1}') | grep "token:")
    KUBE_DASHBOARD_TOKEN=${KUBE_DASHBOARD_TOKEN:12}
    echo TOKEN:
    echo "${KUBE_DASHBOARD_TOKEN}"
    echo "${KUBE_DASHBOARD_TOKEN}" > kube-dashboard-token.txt

    # Find URL and launch Dashboard in Browser
    NODEPORT=`rancher kubectl get services/kubernetes-dashboard -n kube-system  -o jsonpath="{.spec.ports[0].nodePort}"`
    for NODE in `rancher kubectl get no -o jsonpath='{range.items[*].status.addresses[?(@.type=="InternalIP")]}{"https://"}{.address}{"\n"}{end}'`; do
        echo $NODE:$NODEPORT
        echo "$NODE:$NODEPORT" > kube-dashboard-url.txt
        xdg-open "$NODE:$NODEPORT"
        break;
    done
fi

#https://github.com/nginxinc/kubernetes-ingress/tree/master/examples/customization
