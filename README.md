# On-Premises Docker Swarm and Kubernetes Setup

These instructions describe how to set up an On-Premises cluster using Docker Swarm and Kubernetes. You can specify on the fly how many worker you have/need.

For monitoring and storage purposes we use Docker-Swarm (Grafana and Minio S3).


# Prerequisites:

## Operating System
Ubuntu / CentOS / .. (anything that supports Docker)


## Static IP address
For the nodes in the cluster to be able to communicate with each other, it is necessary that every node has it's own static ip address.


# Required Software:

## Install instructions for Docker on Ubuntu ([Link]((https://docs.docker.com/install/linux/docker-ce/ubuntu/)))

```sh
sudo apt-get update

# Install packages to allow apt to use a repository over HTTPS:
sudo apt-get install \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common

# Add Docker’s official GPG key:
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -


# set up the stable repository
sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"

# Update the apt package index
sudo apt-get update

# Install the latest version of Docker CE
sudo apt-get install -y docker-ce


# Add user to docker group
sudo groupadd docker
sudo usermod -aG docker $USER
```

## Install Docker-Compose ([Link](https://docs.docker.com/compose/install/))

```sh
# download docker-compose (check latest version number: https://github.com/docker/compose/releases)
sudo curl -L https://github.com/docker/compose/releases/download/1.22.0/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose

# Apply executable permissions to the binary
sudo chmod +x /usr/local/bin/docker-compose

# Test the installation
docker-compose --version
```


## Install Git

```sh
sudo apt-get update
sudo apt-get install git
```

# Download Required Setup files

```bash
git clone https://github.com/David-Development/cluster-setup.git
```

# Setup Swarm Cluster

- **IMPORTANT:** Run the following commands **ONLY** on the master node
- Assume we have three nodes (nm-smt01, nm-smt02, nm-smt03; nm-smt01 is master)

```bash
cd lm-cluster-setup/swarm
bash startSwarmCluster.sh nm-smt02 nm-smt03
```

- After that you'll be able to access Portainer using: http://nm-smt01:9000 (login using admin/admin)


# Setup Monitoring and Minio Storage

## Setup Monitoring

```bash
cd lm-cluster-setup/swarm/cluster-monitoring
docker stack deploy --with-registry-auth --compose-file docker-compose.yml cluster-monitor
```

- For more information about the monitoring solution, please take a look into the GitHub Repository ([Link](https://github.com/David-Development/collectd-influxdb-grafana-docker)).
- Then you can open grafana using http://nm-smt01:3000 (login with admin/admin)


## Setup distributed minio storage

- In order to setup a distributed mino storage, you'll need to have at least 4 nodes available (the number of nodes has to be even).
- This script will label all of your nodes in your swarm from 0-N (e.g. "minio0=true").
- Make sure to adapt the `docker-compose-minio.yaml` before running this script to match your cluster.
  - Configure the `placement: -> constraints: -> node.labels.minio0==true` accordingly for each node
  - Note: It's configured to run 4 minio instances on three nodes. We only had 3 nodes in our cluster - Node 0 is running two instances (minio0 and minio3).


```bash
cd lm-cluster-setup/swarm/
bash startDistributedMinioCluster.sh
```

- Access minio using: http://nm-smt01:9001 (login using minio/minio123)



# Setup Kubernetes

- **IMPORTANT:** Run the following commands **ONLY** on the master node
- Assume we have three nodes (nm-smt01, nm-smt02, nm-smt03; nm-smt01 is master)

## Setup SSH on all nodes:

- the addSshKeys script generates a ssh key.
- the public key is send to the worker-nodes in order to allow a password-less login

```bash
cd lm-cluster-setup/
bash kubernetes/addSshKeys.sh nm-smt02 nm-smt03
```

## Setup Kubernetes/Rancher Cluster

```bash
cd lm-cluster-setup/kubernetes
export CLUSTER_NAME=<cluster-name>
bash startCluster.sh ${CLUSTER_NAME}
bash addNodesToCluster.sh ${CLUSTER_NAME} nm-smt02 nm-smt03
```


## Configure Docker Registry (Optional)

```bash
tools/rancher kubectl create secret docker-registry <registry-name> --docker-server=<registry.myhost.de> --docker-username=<my-username> --docker-password="<my-password>" --docker-email=<email>
```

## Destroy Cluster

```bash
cd lm-cluster-setup/kubernetes
# bash stopCluster.sh <worker-nodes>
bash stopCluster.sh nm-smt02 nm-smt03
```
