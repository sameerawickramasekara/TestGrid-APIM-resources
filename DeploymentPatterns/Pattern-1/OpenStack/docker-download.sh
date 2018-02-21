#!/bin/bash
current_loc=$(pwd)
nodes=('apim-rdbms-kubernetes' 'rsync-kubernetes' 'sshd-kubernetes' 'wso2am-analytics-kubernetes' 'wso2am-kubernetes');

sudo mkdir mount
sudo mount 192.168.89.206:/exports/apipm-docker $current_loc/mount
sudo mkdir $current_loc/docker_images
#cd docker_images
for i in "${nodes[@]}"
do
        sudo curl -o $current_loc/docker_images/$i file://$current_loc/mount/$i
        docker load -i $current_loc/docker_images/$i
done

