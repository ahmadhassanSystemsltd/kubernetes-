#!/bin/bash

echo "Set up required sysctl params"
sudo tee /etc/sysctl.d/kubernetes.conf<<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

echo "Reload sysctl"
sudo sysctl --system

echo "add CRI-O repo"
OS=CentOS_7
VERSION=1.26
curl -L -o /etc/yum.repos.d/devel:kubic:libcontainers:stable.repo https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$OS/devel:kubic:libcontainers:stable.repo
curl -L -o /etc/yum.repos.d/devel:kubic:libcontainers:stable:cri-o:$VERSION.repo https://download.opensuse.org/repositories/devel:kubic:libcontainers:stable:cri-o:$VERSION/$OS/devel:kubic:libcontainers:stable:cri-o:$VERSION.repo

echo "Install CRI-O"
sudo yum remove docker-ce docker-ce-cli containerd.io
sudo yum install cri-o

echo "Update CRI-O Subnet"
sudo sed -i 's/10.85.0.0/192.168.0.0/g' /etc/cni/net.d/100-crio-bridge.conf
sudo sed -i 's/10.85.0.0/192.168.0.0/g' /etc/cni/net.d/100-crio-bridge.conflist

sudo systemctl daemon-reload
sudo systemctl start crio
sudo systemctl enable crio

echo "ports to be enabled Master Server" 
sudo firewall-cmd --add-port={6443,2379-2380,10250,10251,10252,5473,179,5473}/tcp --permanent
sudo firewall-cmd --add-port={4789,8285,8472}/udp --permanent
sudo firewall-cmd --reload

echo "Disabling Firewall if enabled"
sudo systemctl disable --now firewalld

echo "Checking Netfilter Availability"
lsmod | grep br_netfilter

echo "Enabling Kubelet"
sudo systemctl enable kubelet
sudo kubeadm config images pull

echo "Kubeadm Intialzing Advertising the Public IP on This Master Node"
sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --upload-certs --control-plane-endpoint=$YOUR_IP

echo "Creating Folders and giveing permissions to run Kubectl Commands"
sudo mkdir -p $HOME/.kube
sudo cp /etc/kubernetes/admin.conf $HOME/
sudo chown $(id -u):$(id -g) $HOME/admin.conf
export KUBECONFIG=$HOME/admin.conf

#Fix the Error – The connection to the server localhost:8080 was refused
export KUBECONFIG=/etc/kubernetes/admin.conf

echo "Bootstrapping Kubectl Commands"
echo 'export KUBECONFIG=$HOME/admin.conf' >> $HOME/.bashrc

echo "Checking Status of Nodes"
kubectl get nodes

echo "Installing Flannel Cli"
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
echo "Checking if Flannel and Core DNS is Installed"
kubectl get pods -n kube-system

echo "Checking Status of Nodes After CNI "
sudo kubectl get nodes
