import os, uuid
from azure.storage.queue import (
        QueueClient,
        TextBase64EncodePolicy,
        TextBase64DecodePolicy
)

# Retrieve the connection string for use with the application. The storage
# connection string is stored in an environment variable on the machine
# running the application called AZURE_STORAGE_CONNECTION_STRING. If the environment variable is
# created after the application is launched in a console or with Visual Studio,
# the shell or application needs to be closed and reloaded to take the
# environment variable into account.
connect_str = os.getenv('AZURE_STORAGE_CONNECTION_STRING')

# Create a unique name for the queue
q_name = "delete-resources"

# Instantiate a QueueClient object which will
# be used to create and manipulate the queue
print("Creating queue: " + q_name)
#queue_client = QueueClient.from_connection_string(connect_str, q_name)

# Setup Base64 encoding and decoding functions
base64_queue_client = QueueClient.from_connection_string(
                        conn_str=connect_str, queue_name=q_name,
                        message_encode_policy = TextBase64EncodePolicy(),
                        message_decode_policy = TextBase64DecodePolicy()
                    )

base64_queue_client.send_message("done")
