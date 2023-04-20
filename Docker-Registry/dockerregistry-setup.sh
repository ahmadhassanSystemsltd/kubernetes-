#!/bin/bash

echo "Updating Yum...."
sudo yum -y update
echo "update openssl version to 1.1.1"
yum -y install make gcc perl pcre-devel zlib-devel
yum install wget
wget https://ftp.openssl.org/source/old/1.1.1/openssl-1.1.1.tar.gz
tar xvf openssl-1.1.1.tar.gz
cd openssl-1.1.1/
./config --prefix=/usr --openssldir=/etc/ssl --libdir=lib no-shared zlib-dynamic
make
make test
make install 
export LD_LIBRARY_PATH=/usr/local/lib:/usr/local/lib64
echo "export LD_LIBRARY_PATH=/usr/local/lib:/usr/local/lib64" >> ~/.bashrc
echo "open version"
openssl version

docker run -d -p 5000:5000 --restart=always -v /reg:/var/lib/registry --name registry registry:2
cat <<EOF | sudo tee /etc/docker/daemon.json
{
"insecure-registries" : ["your_ip_address"]
}
EOF
systemctl restart docker
mkdir -p /registry && cd "$_"
mkdir -p docker_reg_certs
openssl req  -newkey rsa:4096 -nodes -sha256 -keyout docker_reg_certs/domain.key -x509 -days 365 -out docker_reg_certs/domain.crt
mkdir docker_reg_auth && cd "$_"
htpasswd -Bc registry.password username
docker run -d -p 5000:5000 --restart=always --name registry -v $PWD/docker_reg_certs:/certs -v $PWD/docker_reg_auth:/auth -v /reg:/var/lib/registry -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/domain.crt -e REGISTRY_HTTP_TLS_KEY=/certs/domain.key -e "REGISTRY_AUTH_HTPASSWD_REALM=Registry Realm" -e REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd -e REGISTRY_AUTH=htpasswd registry:2
docker ps
echo "please use docker login command with username & password"
echo "docker login -u user -p password ip:5000"
