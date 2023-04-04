#!/bin/bash

yum update
sudo tee /etc/yum.repos.d/kubernetes.repo<<EOF
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF

yum clean all && yum -y makecache
yum -y install epel-release vim git curl wget kubelet kubeadm kubectl --disableexcludes=kubernetes
kubeadm  version

echo "Disable SELinux and Swap"
sudo setenforce 0
sudo sed -i 's/^SELINUX=.*/SELINUX=permissive/g' /etc/selinux/config
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
swapoff -a

echo "Install Container runtime CRI-O"

echo "Ensure you load modules"
sudo modprobe overlay
sudo modprobe br_netfilter

echo "Set up required sysctl params"
sudo tee /etc/sysctl.d/kubernetes.conf<<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

echo "Reload sysctl"
sudo sysctl --system

echo "Add CRI-O repo"
OS=CentOS_7
VERSION=1.26
curl -L -o /etc/yum.repos.d/devel:kubic:libcontainers:stable.repo https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$OS/devel:kubic:libcontainers:stable.repo
curl -L -o /etc/yum.repos.d/devel:kubic:libcontainers:stable:cri-o:$VERSION.repo https://download.opensuse.org/repositories/devel:kubic:libcontainers:stable:cri-o:$VERSION/$OS/devel:kubic:libcontainers:stable:cri-o:$VERSION.repo

echo "Installing CRI-O"
sudo yum remove docker-ce docker-ce-cli containerd.io
sudo yum install cri-o


echo "Update CRI-O Subnet"
sudo sed -i 's/10.85.0.0/192.168.0.0/g' /etc/cni/net.d/100-crio-bridge.conf
sudo sed -i 's/10.85.0.0/192.168.0.0/g' /etc/cni/net.d/100-crio-bridge.conflist

echo "Start and enable Service"
sudo systemctl daemon-reload
sudo systemctl start crio
sudo systemctl enable crio

sudo firewall-cmd --add-port={10250,30000-32767,5473,179,5473}/tcp --permanent
sudo firewall-cmd --add-port={4789,8285,8472}/udp --permanent
sudo firewall-cmd --reload

echo "Disabling Firewall if enabled"
sudo systemctl disable --now firewalld

echo "Now your worker node is setting up :)"
lsmod | grep br_netfilter
sudo systemctl enable kubelet
