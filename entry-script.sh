#!/bin/bash
sudo yum update -y && sudo yum install -y docker
sudo systemctl start docker 
sudo usermod -aG docker ec2-user

# we need to restart docker to apply above change in user group
sudo systemctl restart docker

docker run -p 8080:80 nginx

# use bash comands
# update soft then install docker
# add 'e2-user' user to 'docker' group to perform docker comands without sudo
# run nginx container on port 8080 of server, open port 80 of container
