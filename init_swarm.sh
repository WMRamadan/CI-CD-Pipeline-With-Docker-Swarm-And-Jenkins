#!/bin/bash

docker-machine create -d virtualbox swarm-1
docker-machine create -d virtualbox swarm-2
docker-machine create -d virtualbox swarm-3

eval $(docker-machine env swarm-1)

docker run --name visualizer -d \
 -p 8083:8083 \
 -e HOST=$(docker-machine ip swarm-1) \
 -e PORT=8083 \
 -v /var/run/docker.sock:/var/run/docker.sock \
 dockersamples/visualizer

# open Visualizer
open http://$(docker-machine ip swarm-1):8083

# initialize cluster with first node
docker swarm init --advertise-addr $(docker-machine ip swarm-1)

# token for joining the cluster
TOKEN=$(docker swarm join-token -q manager)

for i in 2 3; do
 eval $(docker-machine env swarm-$i)
 docker swarm join --token $TOKEN \
  --advertise-addr $(docker-machine ip swarm-$i) \
  $(docker-machine ip swarm-1):2377
done

eval $(docker-machine env swarm-1)

docker service create --name registry -p 5000:5000 \
 --mount "type=bind,source=$PWD,target=/var/lib/registry" \
 --reserve-memory 100m registry

docker network create --driver overlay proxy

docker network create --driver overlay go-demo

docker service create --name go-demo-db --network go-demo mongo

docker service create --name go-demo -e DB=go-demo-db \
 --network go-demo --network proxy vfarcic/go-demo

docker service create --name proxy \
 -p 80:80 -p 443:443 -p 8080:8080 --network proxy \
 -e MODE=swarm vfarcic/docker-flow-proxy

curl "$(docker-machine ip swarm-1):80/v1/docker-flow-proxy/reconfigure?serviceName-goapp&servicePath=/demo&port-80"

curl -i $(docker-machine ip swarm-1)/demo/hello

eval $(docker-machine env swarm-1)

mkdir -p docker/jenkins

docker service create --name jenkins --reserve-memory 300m \
 -p 8082:8080 -p 50000:50000 -e JENKINS_OPTS="--prefix=/jenkins" \
 --mount "type=bind,source=$PWD/docker/jenkins,target=/var/jenkins_home" \
 jenkins:alpine

open http://$(docker-machine ip swarm-1):8082/jenkins

cat docker/jenkins/secrets/initialAdminPassword