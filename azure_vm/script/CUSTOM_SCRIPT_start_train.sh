#!/bin/bash

##############################################
# Input Parameters
##############################################
TRAIN_DATASET_URL=$1
AZURE_STORAGE_CONNECTION_STRING=$2
AZURE_STORAGE_ACCOUNT_NAME=$3
AZURE_STORAGE_ACCOUNT_KEY=$4
SLACK_URL=$5
JOB_ID=$6
CLASSES=$7
EPOCHS=$8
DL_TYPE=$9
MODEL_TYPE=$10

##############################################
# Mount Azure Files for logging
##############################################
sudo mkdir /mnt/logs
if [ ! -d "/etc/smbcredentials" ]; then
sudo mkdir /etc/smbcredentials
fi
if [ ! -f "/etc/smbcredentials/${AZURE_STORAGE_ACCOUNT_NAME}.cred" ]; then
    echo "username=${AZURE_STORAGE_ACCOUNT_NAME}" >> ${AZURE_STORAGE_ACCOUNT_NAME}.cred
    echo "password=${AZURE_STORAGE_ACCOUNT_KEY}" >> ${AZURE_STORAGE_ACCOUNT_NAME}.cred
    sudo mv ${AZURE_STORAGE_ACCOUNT_NAME}.cred /etc/smbcredentials
    #sudo bash -c 'echo "username=${AZURE_STORAGE_ACCOUNT_NAME}" >> /etc/smbcredentials/${AZURE_STORAGE_ACCOUNT_NAME}.cred'
    #sudo bash -c 'echo "password=${AZURE_STORAGE_ACCOUNT_KEY}" >> /etc/smbcredentials/${AZURE_STORAGE_ACCOUNT_NAME}.cred'
fi
sudo chmod 600 /etc/smbcredentials/${AZURE_STORAGE_ACCOUNT_NAME}.cred

TEXT="//${AZURE_STORAGE_ACCOUNT_NAME}.file.core.windows.net/logs /mnt/logs cifs nofail,vers=3.0,credentials=/etc/smbcredentials/${AZURE_STORAGE_ACCOUNT_NAME}.cred,dir_mode=0777,file_mode=0777,serverino"
#sudo echo "//${AZURE_STORAGE_ACCOUNT_NAME}.file.core.windows.net/logs /mnt/logs cifs nofail,vers=3.0,credentials=/etc/smbcredentials/${AZURE_STORAGE_ACCOUNT_NAME}.cred,dir_mode=0777,file_mode=0777,serverino" >> /etc/fstab
sudo bash -c "echo ""$TEXT"" >> /etc/fstab"
sudo mount -t cifs //${AZURE_STORAGE_ACCOUNT_NAME}.file.core.windows.net/logs /mnt/logs -o vers=3.0,credentials=/etc/smbcredentials/${AZURE_STORAGE_ACCOUNT_NAME}.cred,dir_mode=0777,file_mode=0777,serverino


# Mount Azure Files for training data
sudo mkdir /mnt/train
TEXT="//${AZURE_STORAGE_ACCOUNT_NAME}.file.core.windows.net/train /mnt/train cifs nofail,vers=3.0,credentials=/etc/smbcredentials/${AZURE_STORAGE_ACCOUNT_NAME}.cred,dir_mode=0777,file_mode=0777,serverino"
#sudo echo "//${AZURE_STORAGE_ACCOUNT_NAME}.file.core.windows.net/train /mnt/train cifs nofail,vers=3.0,credentials=/etc/smbcredentials/${AZURE_STORAGE_ACCOUNT_NAME}.cred,dir_mode=0777,file_mode=0777,serverino" >> /etc/fstab
sudo bash -c "echo ""$TEXT"" >> /etc/fstab"
sudo mount -t cifs //${AZURE_STORAGE_ACCOUNT_NAME}.file.core.windows.net/train /mnt/train -o vers=3.0,credentials=/etc/smbcredentials/${AZURE_STORAGE_ACCOUNT_NAME}.cred,dir_mode=0777,file_mode=0777,serverino

##############################################
# Download training data from Azure BLOB
##############################################
mkdir /home/ai/data
chmod 777 /home/ai/data
cd /home/ai/data
sudo apt install wget unzip -y 
cp /mnt/train/"$TRAIN_DATASET_URL" train.zip
mkdir train
unzip train.zip -d train
cp /mnt/logs/latest.pth start.pth
JOB_ID_DIR=/mnt/logs/"$JOB_ID"
mkdir $JOB_ID_DIR

##############################################
# Install Docker
##############################################
sudo apt update -y
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu bionic stable"
sudo apt update
apt-cache policy docker-ce
sudo apt install -y docker-ce
echo "Docker Installed" &>> /logs/train.log

###########################################################
# Special Proc. GetIP address of ubuntu mirror in Japan
###########################################################
APT_IP=`nslookup jp.archive.ubuntu.com | grep Address |  tail -n +2 | cut -f2 -d ' '`
echo $APT_IP

##############################################
# Data transformation
##############################################
sudo docker run \
    --rm \
    -v /home/ai/data:/data \
    -v $JOB_ID_DIR:/logs \
    -e SCRIPT_URL="https://raw.githubusercontent.com/hiouchiy/auto-train-with-openvino-training-extension-on-azure/main/azure_vm/script/transform.sh" \
    --shm-size=10g \
    -u 0 \
    --add-host="archive.ubuntu.com:${APT_IP}" \
    hiouchiy/ote:2021.3 \
    /bin/bash -c 'apt update && apt install wget -y && wget ${SCRIPT_URL} -O script.sh && source script.sh &>> /logs/train.log'

##############################################
# Run training
##############################################
sudo docker run \
    -v /home/ai/data:/data \
    -v $JOB_ID_DIR:/logs \
    -e TRAIN_ANN_FILE="/data/train-coco/annotations/instances_train.json" \
    -e TRAIN_IMG_ROOT="/data/train/images" \
    -e VAL_ANN_FILE="/data/train-coco/annotations/instances_test.json" \
    -e VAL_IMG_ROOT="/data/train/images" \
    -e CLASSES=$CLASSES \
    -e AZURE_STORAGE_CONNECTION_STRING=$AZURE_STORAGE_CONNECTION_STRING \
    -e WORK_DIR=/tmp/my_model \
    -e SCRIPT_URL="https://raw.githubusercontent.com/hiouchiy/auto-train-with-openvino-training-extension-on-azure/main/azure_vm/script/train_2021.3_mini.sh" \
    -e SLACK_URL=$SLACK_URL \
    -e EPOCHS=$EPOCHS \
    -e DL_TYPE=$DL_TYPE \
    -e MODEL_TYPE=$MODEL_TYPE \
    --shm-size=10g \
    -u 0 \
    --add-host="archive.ubuntu.com:${APT_IP}" \
    hiouchiy/ote:2021.3 \
    /bin/bash -c 'apt update && apt install wget -y && wget ${SCRIPT_URL} -O script.sh && source script.sh &>> /logs/train.log'