## Minio Store

There are tree options to run a local minio storage (standalone; using docker). You can either run Minio using an auto-generated docker volume, mount your data into the container or use a ramfs. (Ref: https://docs.minio.io/docs/minio-docker-quickstart-guide)

```bash
# using temporary volume
docker run --name minio -d -p 9001:9000 -e "MINIO_ACCESS_KEY=minio" -e "MINIO_SECRET_KEY=minio123" minio/minio:RELEASE.2018-10-18T00-28-58Z server /data

# using hdd/sdd (edit volume mount point)
docker run --name minio -d -p 9001:9000 -v ~/storage/minio/:/data/ -e "MINIO_ACCESS_KEY=minio" -e "MINIO_SECRET_KEY=minio123" minio/minio:RELEASE.2018-10-18T00-28-58Z server /data

# using ram fs (90gb limit)
docker run --name minio -d -p 9001:9000 -e "MINIO_ACCESS_KEY=minio" -e "MINIO_SECRET_KEY=minio123" --tmpfs /storage/:rw,noexec,nosuid,size=94371840k minio/minio server /storage/
```
