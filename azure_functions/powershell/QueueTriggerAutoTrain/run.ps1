# Input bindings are passed in via param block.
param([string] $QueueItem, $TriggerMetadata)

#$TRAIN_DATA_URL = $QueueItem
#Write-Host "PowerShell queue trigger function processed work item: $TRAIN_DATA_URL"
$TRAIN_DATA_URL,$JOB_ID,$VM_SIZE,$CLASSES,$EPOCHS,$DL_TYPE,$MODEL_TYPE,$REFERED_JOB_ID = $QueueItem.Split(":")
Write-Host "PowerShell queue trigger function processed work item: $TRAIN_DATA_URL, $JOB_ID, $VM_SIZE, $CLASSES, $EPOCHS, $DL_TYPE, $MODEL_TYPE"


New-AzResourceGroup -Name $env:ACI_RESOURCE_GROUP_NAME -Location japaneast
New-AzContainerGroup -ResourceGroupName $env:ACI_RESOURCE_GROUP_NAME -Name $env:ACI_CONTAINER_GROUP_NAME `
    -Image mcr.microsoft.com/azure-cli -OsType Linux `
    -IpAddressType Public `
    -Command "/bin/bash -c ""cd && az login --service-principal --username $env:AZURE_SP_APP_ID --password $env:AZURE_SP_PASSWORD --tenant $env:AZURE_SP_TENANT && git clone $env:GITHUB_REPO_URL auto-train && cd auto-train/aci/script && source ./deploy_vm.sh $env:TRAIN_VM_RESOURCE_GROUP '$env:AZURE_STORAGE_CONNECTION_STRING' '$TRAIN_DATA_URL' $env:AZURE_STORAGE_ACCOUNT_NAME $env:AZURE_STORAGE_ACCOUNT_KEY $env:SLACK_URL $VM_SIZE $JOB_ID $CLASSES $EPOCHS $DL_TYPE $MODEL_TYPE $env:CUSTOM_SCRIPT_URL $REFERED_JOB_ID && cd""" `
    -RestartPolicy OnFailure

if ($?) {
    $body = "This HTTP triggered function executed successfully. Started container group $env:ACI_CONTAINER_GROUP_NAME"
}
else  {
    $body = "There was a problem starting the container group."
}

# Write out the queue message and insertion time to the information log.
Write-Host "PowerShell queue trigger function processed work item: $QueueItem"
Write-Host "Queue item insertion time: $($TriggerMetadata.InsertionTime)"