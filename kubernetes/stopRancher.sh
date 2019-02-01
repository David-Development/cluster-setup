
SYSTEM_TOOLS_VERSION=v0.1.0

curl -L -o system-tools https://github.com/rancher/system-tools/releases/download/${SYSTEM_TOOLS_VERSION}/system-tools_linux-amd64

chmod +x ./system-tools

./system-tools remove --kubeconfig ./kubeconfig --namespace fraunhofer
