#!/bin/bash

##############################################
# Input Parameters
##############################################
TRAIN_DATASET_URL=$1
echo "TRAIN_DATASET_URL="$TRAIN_DATASET_URL &>> /home/ai/deploy.log

AZURE_STORAGE_CONNECTION_STRING=$2
echo "AZURE_STORAGE_CONNECTION_STRING="$AZURE_STORAGE_CONNECTION_STRING &>> /home/ai/deploy.log

AZURE_STORAGE_ACCOUNT_NAME=$3
echo "AZURE_STORAGE_ACCOUNT_NAME="$AZURE_STORAGE_ACCOUNT_NAME &>> /home/ai/deploy.log

AZURE_STORAGE_ACCOUNT_KEY=$4
echo "AZURE_STORAGE_ACCOUNT_KEY="$AZURE_STORAGE_ACCOUNT_KEY &>> /home/ai/deploy.log

SLACK_URL=$5
echo "SLACK_URL="$SLACK_URL &>> /home/ai/deploy.log

JOB_ID=$6
echo "JOB_ID="$JOB_ID &>> /home/ai/deploy.log

CLASSES=$7
echo "CLASSES="$CLASSES &>> /home/ai/deploy.log

EPOCHS=$8
echo "EPOCHS="$EPOCHS &>> /home/ai/deploy.log

DL_TYPE=$9
echo "DL_TYPE="$DL_TYPE &>> /home/ai/deploy.log

MODEL_TYPE=${10}
echo "MODEL_TYPE="$MODEL_TYPE &>> /home/ai/deploy.log

REFERED_JOB_ID=${11}
echo "REFERED_JOB_ID="$REFERED_JOB_ID &>> /home/ai/deploy.log

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
sudo mount -t cifs //${AZURE_STORAGE_ACCOUNT_NAME}.file.core.windows.net/logs /mnt/logs -o vers=3.0,credentials=/etc/smbcredentials/${AZURE_STORAGE_ACCOUNT_NAME}.cred,dir_mode=0777,file_mode=0777,serverino &>> /home/ai/deploy.log


# Mount Azure Files for training data
sudo mkdir /mnt/train
TEXT="//${AZURE_STORAGE_ACCOUNT_NAME}.file.core.windows.net/train /mnt/train cifs nofail,vers=3.0,credentials=/etc/smbcredentials/${AZURE_STORAGE_ACCOUNT_NAME}.cred,dir_mode=0777,file_mode=0777,serverino"
#sudo echo "//${AZURE_STORAGE_ACCOUNT_NAME}.file.core.windows.net/train /mnt/train cifs nofail,vers=3.0,credentials=/etc/smbcredentials/${AZURE_STORAGE_ACCOUNT_NAME}.cred,dir_mode=0777,file_mode=0777,serverino" >> /etc/fstab
sudo bash -c "echo ""$TEXT"" >> /etc/fstab"
sudo mount -t cifs //${AZURE_STORAGE_ACCOUNT_NAME}.file.core.windows.net/train /mnt/train -o vers=3.0,credentials=/etc/smbcredentials/${AZURE_STORAGE_ACCOUNT_NAME}.cred,dir_mode=0777,file_mode=0777,serverino &>> /home/ai/deploy.log

JOB_ID_DIR=/mnt/logs/"$JOB_ID"
mkdir $JOB_ID_DIR

##############################################
# Download training data from Azure BLOB
##############################################
mkdir /home/ai/data &>> $JOB_ID_DIR/train.log
chmod 777 /home/ai/data &>> $JOB_ID_DIR/train.log
cd /home/ai/data &>> $JOB_ID_DIR/train.log
sudo apt-get update -y &>> $JOB_ID_DIR/train.log
sudo apt-get install wget unzip -y &>> $JOB_ID_DIR/train.log
cp /mnt/train/"$TRAIN_DATASET_URL" train.zip &>> $JOB_ID_DIR/train.log
mkdir train &>> $JOB_ID_DIR/train.log
unzip train.zip -d train &>> $JOB_ID_DIR/train.log

CONTINUOUS_TRAINING=false
if [ $REFERED_JOB_ID != "nothing" ]; then
    if [ -d /mnt/logs/$REFERED_JOB_ID ]; then
        if [ -e /mnt/logs/$REFERED_JOB_ID/latest.pth ]; then
		    echo "cp /mnt/logs/$REFERED_JOB_ID/latest.pth start.pth" &>> $JOB_ID_DIR/train.log
            cp /mnt/logs/$REFERED_JOB_ID/latest.pth start.pth &>> $JOB_ID_DIR/train.log
			echo "CONTINUOUS_TRAINING=true" &>> $JOB_ID_DIR/train.log
            CONTINUOUS_TRAINING=true
	    fi
    fi
fi

##############################################
# Install Docker
##############################################
sudo apt-get update -y &>> $JOB_ID_DIR/train.log
sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common &>> $JOB_ID_DIR/train.log
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add - &>> $JOB_ID_DIR/train.log
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu bionic stable" &>> $JOB_ID_DIR/train.log
sudo apt-get update &>> $JOB_ID_DIR/train.log
apt-cache policy docker-ce &>> $JOB_ID_DIR/train.log
sudo apt-get install -y docker-ce &>> $JOB_ID_DIR/train.log
echo "Docker Installed" &>> $JOB_ID_DIR/train.log

###########################################################
# Special Proc. GetIP address of ubuntu mirror in Japan
###########################################################
APT_IP=`nslookup jp.archive.ubuntu.com | grep Address |  tail -n +2 | cut -f2 -d ' '`
echo $APT_IP &>> $JOB_ID_DIR/train.log

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
    /bin/bash -c 'apt-get update && apt-get install wget -y && wget ${SCRIPT_URL} -O script.sh && source script.sh &>> /logs/train.log'

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
	-e CONTINUOUS_TRAINING=$CONTINUOUS_TRAINING \
    --shm-size=10g \
    -u 0 \
    --add-host="archive.ubuntu.com:${APT_IP}" \
    hiouchiy/ote:2021.3 \
    /bin/bash -c 'apt-get update && apt-get install wget -y && wget ${SCRIPT_URL} -O script.sh && source script.sh &>> /logs/train.log'
