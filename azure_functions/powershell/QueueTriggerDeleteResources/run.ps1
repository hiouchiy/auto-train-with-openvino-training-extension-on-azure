# Input bindings are passed in via param block.
param([string] $QueueItem, $TriggerMetadata)

try{
    Write-Host "Starting to remove $env:ACI_RESOURCE_GROUP_NAME..."
    Remove-AzResourceGroup -Name $env:ACI_RESOURCE_GROUP_NAME -Force

    Write-Host "Starting to remove $env:TRAIN_VM_RESOURCE_GROUP..."
    Remove-AzResourceGroup -Name $env:TRAIN_VM_RESOURCE_GROUP -Force
    $body = "Successfully done."
}
catch [Microsoft.Rest.Azure.CloudException] {
    $body = 'Error message is ' + $_.Exception.Message
}

# Write out the queue message and insertion time to the information log.
Write-Host "PowerShell queue trigger function processed work item: $QueueItem"
Write-Host "Queue item insertion time: $($TriggerMetadata.InsertionTime)"
