# Minio Store

There are tree options to run a local minio storage (standalone; using docker). You can either run Minio using an auto-generated docker volume, mount your data into the container or use a ramfs. (Ref: https://docs.minio.io/docs/minio-docker-quickstart-guide)


# Standalone Storage

```bash
# using temporary volume
docker run --name minio -d -p 9001:9000 -e "MINIO_ACCESS_KEY=minio" -e "MINIO_SECRET_KEY=minio123" minio/minio:RELEASE.2018-10-18T00-28-58Z server /data

# using hdd/sdd (edit volume mount point)
docker run --name minio -d -p 9001:9000 -v ~/storage/minio/:/data/ -e "MINIO_ACCESS_KEY=minio" -e "MINIO_SECRET_KEY=minio123" minio/minio:RELEASE.2018-10-18T00-28-58Z server /data

# using ram fs (90gb limit)
docker run --name minio -d -p 9001:9000 -e "MINIO_ACCESS_KEY=minio" -e "MINIO_SECRET_KEY=minio123" --tmpfs /storage/:rw,noexec,nosuid,size=94371840k minio/minio server /storage/
```


## Setup distributed minio storage

- In order to setup a distributed mino storage, you'll need to have at least 4 nodes available (the number of nodes has to be even).
- This script will label all of your nodes in your swarm from 0-N (e.g. "minio0=true").
- Make sure to adapt the `docker-compose-minio.yaml` before running this script to match your cluster.
  - Configure the `placement: -> constraints: -> node.labels.minio0==true` accordingly for each node
  - Note: It's configured to run 4 minio instances on three nodes. We only had 3 nodes in our cluster - Node 0 is running two instances (minio0 and minio3).


```bash
cd cluster-setup/swarm/
bash startDistributedMinioCluster.sh
```

- Access minio using: http://node1:9001 (login using minio/minio123)


