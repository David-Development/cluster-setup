#!/bin/bash

if test "$BASH" != "/bin/bash"; then
    echo "Make sure you run this script with 'bash startCluster' in order to measure the time!"
    exit
fi

cat ../signatures/signature-swarm.txt

#WORKER_NODES=($(docker node ls | grep "Ready" | tr '*' ' ' | awk '{print $2}'))
WORKER_NODES=($(docker node ls | grep "Ready" | awk '{print $1}'))


# If you want to use another name for access_key, you'll have to use a special mapping
# See: https://github.com/minio/minio/blob/master/docs/docker/README.md#minio-custom-access-and-secret-key-files

echo "minio" | docker secret create access_key -
echo "minio123" | docker secret create secret_key -

for i in "${!WORKER_NODES[@]}"; do
  echo "docker node update --label-add minio$i=true ${WORKER_NODES[$i]}"
  docker node update --label-add minio$i=true ${WORKER_NODES[$i]}
done

#curl -o docker-compose.yaml https://github.com/minio/minio/blob/master/docs/orchestration/docker-swarm/docker-compose-secrets.yaml?raw=true


#docker stack rm minio_stack
docker stack deploy --compose-file=docker-compose-minio.yaml minio_stack
