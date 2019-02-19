# DigDag

Download binaries in order to submit workflows to digdag

```bash
curl -o digdag -L "https://dl.digdag.io/digdag-latest"
chmod +x digdag

# Info: you need java to run digdag. On ubuntu you can install it using: sudo apt install default-jre
```

## Deploy Digdag locally

```bash
docker-compose up --build
```


### Deploy Digdag on Docker-Swarm
- **WARNING:** Adjust `digdag-server.conf` and `digdag-client.conf` accordingly!!
- https://docs.docker.com/engine/reference/commandline/stack_deploy/#description

```bash
# docker-compose build digdag
# docker-compose push digdag
docker stack rm digdag
docker stack deploy --with-registry-auth --compose-file docker-compose.yaml digdag
xdg-open http://localhost:65432

# monitor stack (wait until everything is started)
watch docker stack ps digdag

# create bucket called digdag
docker run --network host --entrypoint "sh" minio/mc -c "mc config host add minio http://localhost:9001 \"minio\" \"minio123\"; mc mb minio/digdag"
```




## Upload & Run workflow
- In minio, create a bucket called digag
```bash
./digdag delete my-workflow -c digdag-client.conf
./digdag push my-workflow --project workflows -c digdag-client.conf
./digdag start my-workflow workflow --session now -c digdag-client.conf
```


## Additional Tweaks (Optional)

### Setup s3 docker mount

docker login on every node in the cluster
```bash
docker plugin disable rexray/s3fs
docker plugin rm rexray/s3fs
docker plugin install rexray/s3fs S3FS_OPTIONS="allow_other,use_path_request_style,nonempty,url=http://<minio-hostname>:9001" S3FS_ENDPOINT="http://<minio-hostname>:9001" LIBSTORAGE_INTEGRATION_VOLUME_OPERATIONS_MOUNT_ROOTPATH="/" S3FS_ACCESSKEY="minio" S3FS_SECRETKEY="minio123"
```

### check schedule
```
./digdag check --project workflows -c digdag-client-cluster.conf
```
