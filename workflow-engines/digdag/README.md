# DigDag

curl -o digdag -L "https://dl.digdag.io/digdag-latest"

## Deploy locally

```bash
docker-compose up --build
```


### Deploy on Docker-Swarm
- **WARNING:** Adjust `digdag-server.conf` and `digdag-client.conf` accordingly!!
- https://docs.docker.com/engine/reference/commandline/stack_deploy/#description

```bash
# Kubernetes geht nur auf Mac (https://docs.docker.com/v17.09/docker-for-mac/kubernetes/)
# docker stack deploy --kubeconfig ~/.kube/config --compose-file docker-compose.yaml --namespace digdag

# change version number of digdag image
docker-compose build digdag # copy digdag-server.conf into container
docker-compose push digdag

docker stack rm digdag
docker stack deploy --with-registry-auth --compose-file docker-compose.yaml digdag
xdg-open http://localhost:65432
```




## Upload & Run workflow
- In minio, create a bucket called digag
```bash
./digdag delete my-workflow -c digdag-client.conf
./digdag push my-workflow --project workflows -c digdag-client.conf
./digdag start my-workflow workflow --session now -c digdag-client.conf
```


## Setup s3 docker mount
docker login on every node in the cluster
```bash
docker plugin disable rexray/s3fs
docker plugin rm rexray/s3fs
docker plugin install rexray/s3fs S3FS_OPTIONS="allow_other,use_path_request_style,nonempty,url=http://<minio-hostname>:9001" S3FS_ENDPOINT="http://<minio-hostname>:9001" LIBSTORAGE_INTEGRATION_VOLUME_OPERATIONS_MOUNT_ROOTPATH="/" S3FS_ACCESSKEY="minio" S3FS_SECRETKEY="minio123"
```

## check schedule
```
./digdag check --project workflows -c digdag-client-cluster.conf
```
