mkdir -p tools
TOOLS_FOLDER="$(pwd)/tools/"
PATH="$PATH:${TOOLS_FOLDER}"


# Download Kubectl if necessary
if [ ! -f "${TOOLS_FOLDER}kubectl" ]; then
    echo "Kubectl not found.. downloading.."
    curl -L -o "${TOOLS_FOLDER}kubectl" https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
    chmod +x ${TOOLS_FOLDER}kubectl
    echo ""
fi

kubectl delete deployment airflow
kubectl delete service airflow
kubectl delete service postgres-airflow
kubectl delete postgres-airflow
kubectl delete deployment postgres-airflow
kubectl delete configmap airflow-configmap
kubectl delete pvc airflow-logs
kubectl delete pvc airflow-dags
kubectl delete pvc test-volume

kubectl delete pv airflow-dags
kubectl delete pv airflow-logs
kubectl delete pv test-volume

kubectl delete secret airflow-secrets

read -n 1 -s -r -p "Press any key to continue"

#exit

#yes | rm -r ./airflow/
#git clone https://github.com/apache/airflow.git

cd airflow/scripts/ci/kubernetes/

git clean -d -x -f

#sed -i 's?docker run -ti --rm -v ${AIRFLOW_ROOT}:/airflow?docker run -ti --rm -v ${AIRFLOW_ROOT}:/airflow --user $UID?g' build.sh
./docker/build.sh

exit

# Adapt storage path
sed -i 's: /airflow-dags/: /home/dluhmer/development/airflow/airflow-dags/:g' ./kube/volumes.yaml
sed -i 's: /airflow-logs/: /home/dluhmer/development/airflow/airflow-logs/:g' ./kube/volumes.yaml

# use official airflow image
#sed -i 's?AIRFLOW_IMAGE=${IMAGE:-airflow}?AIRFLOW_IMAGE="apache/airflow"?g' ./kube/deploy.sh

sed -i 's?cat \$?# cat \$?g' ./kube/deploy.sh

./kube/deploy.sh -d persistent_mode


