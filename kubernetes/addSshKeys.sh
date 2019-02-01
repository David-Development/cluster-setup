#!/bin/bash

if test "$BASH" != "/bin/bash"; then
    echo "Make sure you run this script with 'bash addSshKeys.sh' in order to measure the time!"
    exit
fi

if [[ -z "$@" ]]; then
  echo -e "Error: Invalid argument. At least one hostname needs to be specified.\n\nbash addSshKeys.sh <node-name>"
  exit 1;
fi;

cat ../signatures/signature-kubernetes.txt

REMOTE_HOSTNAMES=( "$@" )


if [ ! -f ~/.ssh/cluster_id_rsa ]; then
    echo "Generating key-pair"
    # Generate a key-pair without a passphrase
    ssh-keygen -t rsa -b 4096 -f ~/.ssh/cluster_id_rsa -N ''
fi

# Iterate over all hosts and push ssh keys
for REMOTE_HOSTNAME in "${REMOTE_HOSTNAMES[@]}"; do
    echo "Pushing SSH config to ${REMOTE_HOSTNAME}. Info: You need to login twice."
    ssh ${REMOTE_HOSTNAME} mkdir -p ~/.ssh/
    cat ~/.ssh/cluster_id_rsa.pub | ssh ${REMOTE_HOSTNAME} 'cat >> .ssh/authorized_keys'
done


# add keys to bash (otherwise it won't use the certificate)
echo "Adding keys to bash"
ssh-agent bash
ssh-add ~/.ssh/cluster_id_rsa
