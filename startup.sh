#!/bin/bash

set -e

if [ ! ${nopull} ] ; then
  echo 'Pulling all images needed, just to be sure'
  docker pull busybox
  docker pull wouterd/zookeeper
  docker pull wouterd/kafka
fi

# Need a volume to read the config from
conf_container=zoo1

# Start the zookeeper containers
for i in {1..5} ; do
  if [ "${i}" == "1" ] ; then
    docker run -d -v /zoo/conf --name "zoo${i}" -e ZOO_ID=${i} wouterd/zookeeper
  else
    docker run -d --volumes-from ${conf_container} --name "zoo${i}" -e ZOO_ID=${i} wouterd/zookeeper
  fi
done

config=$(cat zoo.cfg.initial)

# Look up the zookeeper instance IPs and create the config file
for i in {1..5} ; do
  container_name=zoo${i}
  container_ip=$(docker inspect --format '{{.NetworkSettings.IPAddress}}' ${container_name})
  line="server.${i}=${container_ip}:2888:3888"
  config="${config}"$'\n'"${line}"
done

# Write the config to the config container
echo "${config}" | docker run -i --rm --volumes-from ${conf_container} busybox sh -c 'cat > /zoo/conf/zoo.cfg'

zoo_links='--link zoo1:zoo1 --link zoo2:zoo2 --link zoo3:zoo3 --link zoo4:zoo4 --link zoo5:zoo5'
zoo_connect='zoo1:2181,zoo2:2181,zoo3:2181,zoo4:2181,zoo5:2181'

# Start 4 Kafka's
# for i in {1..4} ; do
#   docker run -d ${zoo_links} -e BROKER_ID=${i} -e ZOO=${zoo_connect} --name kafka${i} -h kafka${i} wouterd/kafka
# done

# Start 5 apis
for i in {1..5} ; do
  docker run -d ${zoo_links} -e ZOO=${zoo_connect} --name api${i} my-little-api 
done
