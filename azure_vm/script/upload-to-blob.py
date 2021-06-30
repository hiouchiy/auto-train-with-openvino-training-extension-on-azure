import os, uuid
from azure.storage.blob import BlobServiceClient, BlobClient, ContainerClient, __version__

try:
    print("Azure Blob Storage v" + __version__ + " - Python quickstart sample")

    # Quick start code goes here

except Exception as ex:
    print('Exception:')
    print(ex)

# Retrieve the connection string for use with the application. The storage
# connection string is stored in an environment variable on the machine
# running the application called AZURE_STORAGE_CONNECTION_STRING. If the environment variable is
# created after the application is launched in a console or with Visual Studio,
# the shell or application needs to be closed and reloaded to take the
# environment variable into account.
connect_str = os.getenv('AZURE_STORAGE_CONNECTION_STRING')

# Create the BlobServiceClient object which will be used to create a container client
blob_service_client = BlobServiceClient.from_connection_string(connect_str)

# Create a unique name for the container
container_name = "model"

# Create a file in the local data directory to upload and download
local_xml_file_name = "model.xml"
local_bin_file_name = "model.bin"

# Create a blob client using the local file name as the name for the blob
blob_client = blob_service_client.get_blob_client(container=container_name, blob=local_xml_file_name)

print("\nUploading to Azure Storage as blob:\n\t" + local_xml_file_name)

# Upload the created file
with open(local_xml_file_name, "rb") as data:
    blob_client.upload_blob(data, overwrite=True)


# Create a blob client using the local file name as the name for the blob
blob_client = blob_service_client.get_blob_client(container=container_name, blob=local_bin_file_name)

print("\nUploading to Azure Storage as blob:\n\t" + local_bin_file_name)

# Upload the created file
with open(local_bin_file_name, "rb") as data:
    blob_client.upload_blob(data, overwrite=True)
    