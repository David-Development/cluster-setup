# Deploying k3s along with Pachyderm

The scripts in this folder will download k3s, run it using docker-compose and deploy pachyderm in the k3s server. As a backend storage minio will be used (also inside k3s). You only need to have docker and docker-compose installed. Everything else will happen inside the docker container. No data will be stored on your local system. If you tear down the container, everything will be deleted. If you messed something up, just run the install script again. It'll clean everything up before restarting.


In order to start k3s and pachyderm run the following command

```bash 
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


