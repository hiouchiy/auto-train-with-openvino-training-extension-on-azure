#!/bin/bash

echo "------------------------------All Parameters------------------------------"
RESOURCE_GROUP=$1
echo "RESOURCE_GROUP=$RESOURCE_GROUP"

LOCATION=japaneast
echo "LOCATION=$LOCATION"

ARM_TEMPLATE_FILE=azuredeploy.json
echo "ARM_TEMPLATE_FILE=$ARM_TEMPLATE_FILE"

AZURE_STORAGE_CONNECTION_STRING=$2
echo "AZURE_STORAGE_CONNECTION_STRING=$AZURE_STORAGE_CONNECTION_STRING"

TRAIN_DATA_URL=$3
echo "TRAIN_DATA_URL=$TRAIN_DATA_URL"

AZURE_STORAGE_ACCOUNT_NAME=$4
echo "AZURE_STORAGE_ACCOUNT_NAME=$AZURE_STORAGE_ACCOUNT_NAME"

AZURE_STORAGE_ACCOUNT_KEY=$5
echo "AZURE_STORAGE_ACCOUNT_KEY=$AZURE_STORAGE_ACCOUNT_KEY"

SLACK_URL=$6
echo "SLACK_URL=$SLACK_URL"

VM_SIZE=$7
echo "VM_SIZE=$VM_SIZE"

VM_NAME="single-vm"
echo "VM_NAME=$VM_NAME"

JOB_ID=$8
echo "JOB_ID=$JOB_ID"

CLASSES=$9
echo "CLASSES=$CLASSES"

EPOCHS=$10
echo "EPOCHS=$EPOCHS"

DL_TYPE=$11
echo "DL_TYPE=$DL_TYPE"

MODEL_TYPE=$12
echo "MODEL_TYPE=$MODEL_TYPE"

CUSTOM_SCRIPT_URL=$13
echo "CUSTOM_SCRIPT_URL=$CUSTOM_SCRIPT_URL"
echo "------------------------------------------------------------------------"

echo "Creating RESOURCE_GROUP [$RESOURCE_GROUP]"
az group create --name $RESOURCE_GROUP --location $LOCATION

function deploy_vm () {
    DEPLOYMENT_NAME="Deployment_$JOB_ID"
    az deployment group create \
        --name $DEPLOYMENT_NAME \
        --resource-group $RESOURCE_GROUP \
        --template-file $ARM_TEMPLATE_FILE \
        --parameters adminUsername=ai adminPasswordOrKey=Passw0rd1234 vmSize=$VM_SIZE authenticationType=password customScriptCommandToExecute="sh CUSTOM_SCRIPT_start_train.sh \"$TRAIN_DATA_URL\" \"${AZURE_STORAGE_CONNECTION_STRING}\" ${AZURE_STORAGE_ACCOUNT_NAME} ${AZURE_STORAGE_ACCOUNT_KEY} ${SLACK_URL} $JOB_ID $CLASSES $EPOCHS $DL_TYPE $MODEL_TYPE" vmName=$VM_NAME customScriptURL=$CUSTOM_SCRIPT_URL
}

echo "Creating VM [$VM_NAME]"
deploy_vm 0


echo "[info] -----------------------------"
echo "[info] finished all background proc."

echo "[info] SUCCESSFULLY_DONE"