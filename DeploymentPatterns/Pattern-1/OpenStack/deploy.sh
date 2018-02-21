#!/bin/bash
# ------------------------------------------------------------------------
#
# Copyright 2017 WSO2, Inc. (http://wso2.com)
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License

# ------------------------------------------------------------------------

export KUBERNETES_MASTER=$1

# Log Message should be parsed $1
log(){
 TIME=`date`
 #echo "$TIME : $1" >> "$LOG_FILE_LOCATION"
 echo "$TIME : $1"
 return
}

dir=$(cd -P -- "$(dirname -- "$0")" && pwd -P)
cd $dir


while [ "$1" != "" ]; do
    PARAM=`echo $1 | awk -F= '{print $1}'`
    VALUE=`echo $1 | awk -F= '{print $2}'`
    case $PARAM in
        -h | --help)
            usage
            exit
            ;;
        --kubernetes-master | -km )
            KUBERNETES_MASTER=$VALUE
            echo $KUBERNETES_MASTER
            ;;
        --docker-username | -du )
            USERNAME=$VALUE
            echo $USERNAME
            ;;
        --docker-password | -dp )
            PASSWORD=$VALUE
            echo $PASSWORD
            ;;    
        --network-drive | -nfs )
            NFS=$VALUE
            echo $NFS
            ;;    
        --output-dir | -o )
            OUTPUT=$VALUE
            echo $OUTPUT
            ;;             
        *)
            echo "ERROR: unknown parameter \"$PARAM\""
            usage
            exit 1
            ;;
    esac
    shift
done


# temp=${1#*//}
# Master_IP=${temp%:*}
prgdir=$(dirname "$0")
script_path=$(cd "$prgdir"; pwd)
common_scripts_folder=$(cd "${script_path}/common/scripts/"; pwd)

export KUBERNETES_MASTER="$KUBERNETES_MASTER"


#create kubeconfig file
kubectl config --kubeconfig=config set-cluster scratch --server=$KUBERNETES_MASTER --insecure-skip-tls-verify
kubectl config --kubeconfig=config set-credentials experimenter --username=exp --password=exp
kubectl config --kubeconfig=config set-context exp-scratch --cluster=scratch --namespace=default --user=experimenter
kubectl config --kubeconfig=config use-context exp-scratch
mv config ~/.kube/

source "${common_scripts_folder}/base.sh"

# while getopts :h FLAG; do
#     case $FLAG in
#         h)
#             showUsageAndExitDefault
#             ;;
#         \?)
#             showUsageAndExitDefault
#             ;;
#     esac
# done

#kubectl create secret docker-registry registrykey --docker-server=$2 --docker-username=$3 --docker-password=$4 --docker-email=$5

validateKubeCtlConfig

# download APIm 2.1.0 docker images
nodes=$(kubectl get nodes --output=jsonpath='{ $.items[*].status.addresses[?(@.type=="LegacyHostIP")].address }')
delete=($Master_IP)
nodes=( "${nodes[@]/$delete}" )
for node in $nodes; do
    LOGIN_MSG=$(ssh core@$node "docker login docker.wso2.com -u $USERNAME -p $PASSWORD")
	if [[ ${LOGIN_MSG} != *"Login Succeeded"* ]]; then
		log "Docker login Error."
		exit 1
	fi
	log "Docker login succeeded"
    log "pulling image to $node"
    ssh core@$node 'bash -s' < docker-download.sh 
    ssh core@$node "docker pull docker.wso2.com/sshd-kubernetes:1.0.0 &&
		docker pull docker.wso2.com/rsync-kubernetes:1.0.0 &&
		docker pull docker.wso2.com/wso2am-analytics-kubernetes:2.1.0 &&
		docker pull docker.wso2.com/wso2am-kubernetes:2.1.0 &&
		docker pull docker.wso2.com/apim-rdbms-kubernetes:2.1.0"
done

#clone APIM kubernetes artifacts repo
# env -i git clone https://github.com/wso2/kubernetes-apim.git
# env -i git checkout tags/v2.1.0.2
env -i git clone --branch v2.1.0.2 https://github.com/wso2/kubernetes-apim.git

#Add the NFS server ip to the config
sed -i "s/server: [0-9.]*/server: $NFS/g" kubernetes-apim/pattern-1/artifacts/volumes/persistent-volumes.yaml 

#create a namespace
kubectl create namespace wso2
#create a service account
kubectl create serviceaccount wso2svcacct -n wso2

cd kubernetes-apim/pattern-1/artifacts
#deploy artifacts
source deploy-kubernetes.sh

sleep 30

ingress=$(kubectl get ingress --output=jsonpath='{ $.items[*].metadata.name}')
for item in $ingress; do
    address=$(kubectl get ingress $item --output=jsonpath='{ $.status.loadBalancer.ingress[*].ip}')
    hosts=$(kubectl get ingress $item --output=jsonpath='{$.spec.rules[*].host}')
    str=$address" "$hosts
    sudo sed -i "/The following lines are desirable for IPv6 capable hosts/i\\$str" /etc/hosts
done

bash "${common_scripts_folder}/wait-until-server-starts.sh" "default" "${KUBERNETES_MASTER}"

#create deployment.json
json='{ "hosts" : ['
ingress=$(kubectl get ingress --output=jsonpath={.items[*].spec.rules[*].host})
for item in $ingress; do
         json+='{"ip" :"'$item'", "label" :"'$item'", "ports" :['
            json+='{'
            json+='"protocol" : "servlet-http",  "portNumber" :"80"},{'
            json+='"protocol" : "servlet-https",  "portNumber" :"443"'
            json+="}"
         json+="]},"
done
json=${json:0:${#json}-1}

json+="]}"
echo $json;

cat > $OUTPUT/deployment.json << EOF1
$json
EOF1
