# On-Premises Docker Swarm and Kubernetes Setup

These instructions describe how to set up an On-Premises cluster using Docker Swarm and Kubernetes. You can specify on the fly how many workers you want to create.

For monitoring purposes Docker-Swarm is used (Grafana / Telegraf).

As many workflow-engines support S3 Storages, Minio will be used in most cases as a storage.


# Prerequisites:

## Operating System
Ubuntu / CentOS / anything that supports Docker


## Static IP address
For the nodes in the cluster to be able to communicate with each other, it is necessary that every node has it's own static ip address.


# Required Software:

## Install instructions for Docker on Ubuntu ([Link](https://docs.docker.com/install/linux/docker-ce/ubuntu/))

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
sudo apt-get install -y docker-ce docker-ce-cli containerd.io


# Add user to docker group
sudo groupadd docker
sudo usermod -aG docker $USER
```

## Install Docker-Compose ([Link](https://docs.docker.com/compose/install/))

```sh
# download docker-compose (check latest version number: https://github.com/docker/compose/releases)
sudo curl -L https://github.com/docker/compose/releases/download/1.23.2/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose

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

- IMPORTANT: Run the following commands *ONLY* on the master node
- Assume we have three nodes (node1, node2, node3; node1 is master)

```bash
cd cluster-setup/swarm

# for swarm cluster (multiple nodes)
bash startSwarmCluster.sh node2 node3

# for standalone (single node swarm)
bash startSwarmCluster.sh
```

- After that you'll be able to access Portainer using: http://node1:9000 (login using admin/admin)


# Setup Monitoring and Minio Storage

## Setup Monitoring

```bash
cd cluster-setup/swarm/cluster-monitoring
docker stack deploy --with-registry-auth --compose-file docker-compose.yml cluster-monitor
```

- For more information about the monitoring solution, please take a look into the GitHub Repository ([Link](https://github.com/David-Development/collectd-influxdb-grafana-docker)).
- Then you can open grafana using http://node1:3000 (login with admin/admin)




# Setup Kubernetes

- **IMPORTANT:** Run the following commands **ONLY** on the master node
- Assume we have three nodes (node1, node2, node3; node1 is the master node)

## Setup SSH on all nodes:

- the addSshKeys script generates a ssh key.
- the public key is send to the worker-nodes in order to allow a password-less login

```bash
cd cluster-setup/
bash kubernetes/addSshKeys.sh node2 node3
```

## Setup Kubernetes/Rancher Cluster

```bash
cd cluster-setup/kubernetes
export CLUSTER_NAME=<cluster-name>

# create single node cluster
bash startCluster.sh ${CLUSTER_NAME} 

# add nodes to cluster it 
bash addNodesToCluster.sh ${CLUSTER_NAME} node2 node3 
```

- The Rancher UI will be available under: https://node1:8443 (login admin/admin)
- The Kubernetes Dashboard will be available under: https://node1:8444 (login using token - see below)
- In the directory `cluster-setup/kubernetes` there will be multiple, generated files such as: `kube-dashboard-token.txt`, `kube-dashboard-url.txt` and `rancher-login-token.txt`. 
- In order to connect your rancher cli from a remote host to your rancher setup, run the following command: `rancher login https://node1:8443 --token XXX` (use the token from the file `rancher-login-token.txt`)
  - After that you'll be able to run rancher and kubectl commands such as `rancher <command>` and `rancher kubectl <command>`


## Configure Docker Registry (Optional)

```bash
tools/rancher kubectl create secret docker-registry <registry-name> --docker-server=<registry.myhost.de> --docker-username=<my-username> --docker-password="<my-password>" --docker-email=<email>
```

## Destroy Cluster

```bash
cd cluster-setup/kubernetes
# bash stopCluster.sh <worker-nodes>
bash stopCluster.sh node2 node3
```
