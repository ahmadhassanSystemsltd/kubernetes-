#!/bin/bash

echo "Updating Yum...."
#sudo yum -y update && sudo systemctl reboot

echo "Installing Kubelet, Kubeadm and Kubectl......"
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-\$basearch
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
exclude=kubelet kubeadm kubectl
EOF

sudo yum -y install epel-release vim git curl wget kubelet kubeadm kubectl --disableexcludes=kubernetes
#sudo yum -y install epel-release vim git curl wget kubelet-1.23.2 kubeadm-1.23.2-0 kubectl-1.23.2 --disableexcludes=kubernetes

echo "Your Kubeadm version is......"
sudo kubeadm version

echo "Disabling SE Linux and Swap for you :)"
sudo setenforce 0
sudo sed -i 's/^SELINUX=.*/SELINUX=permissive/g' /etc/selinux/config

sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
sudo swapoff -a

echo "Configuring sysctl...."
sudo modprobe overlay
sudo modprobe br_netfilter
sudo tee /etc/sysctl.d/kubernetes.conf<<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
sudo sysctl --system

echo "Install required packages"
sudo yum install -y yum-utils device-mapper-persistent-data lvm2

echo "Add Docker repo"
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

echo "Install containerd"
sudo yum update -y && yum install -y containerd.io

echo "Configure containerd and start service"
sudo mkdir -p /etc/containerd
sudo containerd config default > /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd

echo "Disabling Firewall if enabled"
sudo systemctl disable --now firewalld

echo "Now your worker node is setting up :)"
lsmod | grep br_netfilter
sudo systemctl enable kubelet
