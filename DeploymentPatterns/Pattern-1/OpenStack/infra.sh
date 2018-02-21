#!/bin/bash
LOG_FILE_LOCATION="/home/$USER/terraform/ballerina/logs"

# Log Message should be parsed $1
log(){
 TIME=`date`
 #echo "$TIME : $1" >> "$LOG_FILE_LOCATION"
 echo "$TIME : $1"
 return
}

#Check for terraform.tfvars file
# if [ ! -f terraform.tfvars ]; then
#     echo $PWD
#     echo "terraform.tfvars file not found! Please create the file and execute again !"
#     exit 1
# fi

function usage()
{
    echo "if this was a real script you would see something useful here"
    echo ""
    echo "./simple_args_parsing.sh"
    echo "\t-h --help"
    echo "\t--environment=$ENVIRONMENT"
    echo "\t--db-path=$DB_PATH"
    echo ""
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
        --node-count | -nc )
            NODE_COUNT=$VALUE
            echo $NODE_COUNT
            ;;
        --network | -net )
            NETWORK=$VALUE
            echo $NETWORK
            ;;
        --image-name | -img )
            IMAGE=$VALUE
            echo $IMAGE
            ;;    
        --image-flavor | -img-fl )
            FLAVOR=$VALUE
            echo $FLAVOR
            ;;    
        --key-pair | -k )
            KEYPAIR=$VALUE
            echo $KEYPAIR
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

#edit terraform.tfvars to arguments
sed -i "s/node-count=\"[0-9]*\"/node-count=\"$NODE_COUNT\"/g" terraform.tfvars
sed -i "s/internal-ip-pool=\"[a-z_A-Z]*\"/internal-ip-pool=\"$NETWORK\"/g" terraform.tfvars
sed -i "s/image-name=\".*\"/image-name=\"$IMAGE\"/g" terraform.tfvars
sed -i "s/image-flavor=\".*\"/image-flavor=\"$FLAVOR\"/g" terraform.tfvars
sed -i "s/key-pair=\".*\"/key-pair=\"$KEYPAIR\"/g" terraform.tfvars
#Replace the output path of output file
sed -i "s|k8s.properties|$OUTPUT\/k8s.properties|g" 01-create-inventory.tf

#set environment varibale for openstack
export OS_AUTH_URL=http://203.94.95.131:5000/v2.0

# With the addition of Keystone we have standardized on the term **tenant**
# as the entity that owns the resources.
export OS_TENANT_ID=testgrid
export OS_TENANT_NAME="testgrid"

# In addition to the owning entity (tenant), openstack stores the entity
# performing the action as the **user**.
export OS_USERNAME="testgrid"

# With Keystone you pass the keystone password.
#echo "Please enter your OpenStack Password: "
#read -sr OS_PASSWORD_INPUT
export OS_PASSWORD="Pw5dnlqpn/nLsdfrh4ni"

# If your configuration has multiple regions, we set that information here.
# OS_REGION_NAME is optional and only valid in certain environments.
export OS_REGION_NAME="RegionOne"
# Don't leave a blank variable, unset it if it was empty
if [ -z "$OS_REGION_NAME" ]; then unset OS_REGION_NAME; fi

prgdir=$(dirname "$0")
script_path=$(cd "$prgdir"; pwd)

log "===The Jenkins Main Script Logs===="
log "Checking the Environment variables;"
if [ -z $OS_TENANT_ID ]; then
 log "OS_TENANT_ID is not set as a environment variable"
 exit 1;
fi

if [ -z $OS_TENANT_NAME ]; then
 log "OS_TENANT_ID is not set as a environment variable"
 exit 1;
fi

if [ -z $OS_USERNAME ]; then
 log "OS_TENANT_ID is not set as a environment variable"
 exit 1;
fi

if [ -z $OS_PASSWORD ]; then
 log "OS_TENANT_ID is not set	 as a environment variable"
 exit 1;
fi

# Seems Jenkins is not picking the Path variables from the system, hence as a workaroubd setting the path
TERRA_HOME=/etc/terraform
export PATH=$TERRA_HOME:$PATH

# Trigering the Ansible Scripts to do the kubernetes cluster
source $script_path/cluster-create.sh
# echo "--kubernetes-master=http://192.168.89.117:8080" >> $OUTPUT/k8s.properties

# Check the cluster health
#if [ -z $KUBERNETES_MASTER ]; then
# log "KUBERNETES_MASTER is not set as a environment variable"
# exit 1;
#fi

#STRING_TO_TEST="k8s-master   Ready"
#OUTPUT=$(kubectl get nodes)
#if [[ $OUTPUT != *"${STRING_TO_TEST}"* ]]; then
#  log "Seems Kubenetes cluster is not setup properly, Hence Exiting"
#  exit 1;
#fi	

log "Successfully Finished Execution..."
