# Introduction

These scripts create an argo deployment in kubernetes. Minio will be deployed as a storage backend. A new namespace called argo will be created. After the deployment was started successfully the webinterface will be available on `http://<nodename>:8001`. Make sure to set the variables in `startArgo.sh` and `stopArgo.sh` accordingly.
Also set the `path` in the `minio-standalone-pv.yaml` to where you want the data to be stored at.


# Start Argo 

```bash
bash startArgo.sh
```

# Stop/Remove Argo

```bash
bash stopArgo.sh
```


