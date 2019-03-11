# Deploying k3s along with Pachyderm

The scripts in this folder will download and run a [k3s](https://github.com/rancher/k3s) kubernetes cluster using `docker-compose` and deploy pachyderm inside that cluster. As a backend storage minio will be used (also inside k3s). You only need to have `docker` and `docker-compose` installed. Everything else will happen inside the docker container. No data will be stored on your local system. If you tear down the container, everything will be deleted. If you messed something up, just run the install script again. It'll delete everything before restarting (be careful if you have important data inside the pachyderm cluster).


In order to start k3s and pachyderm run the following command

```bash 
# Clone repo
git clone https://github.com/David-Development/cluster-setup.git
cd cluster-setup/k3s-pachyderm

# Start k3s and pachyderm
. installPachydermk3s.sh # (use . in order to export the PACHD_ADDRESS automatically)
```

after that you should be able to run all pachctl commands. Example:

```bash
tools/pachctl list-job
```


# Stop cluster

```bash
cd k3s
docker-compose down -v --remove-orphans
```


# Access minio from host

```bash
tools/mc config host add minio http://localhost:9001 minio minio123
tools/mc ls minio
```

# Access kubernetes from host

```bash
tools/kubectl --kubeconfig=./k3s/kubeconfig.yaml get pods -n pachyderm
```
