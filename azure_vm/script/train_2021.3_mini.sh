#!/bin/bash

# Send a starting message to the Slack
if [ -n ${SLACK_URL} ]; then
    pip3 install slackweb
    wget https://raw.githubusercontent.com/hiouchiy/auto-train-with-openvino-training-extension-on-azure/main/azure_vm/script/post-to-slack.py
    python3 post-to-slack.py --slack_url ${SLACK_URL} --message "Training started"
fi

# Create workspace for training
if [ ${DL_TYPE} = "1" ]; then
    export DL_TYPE_FOLDER1="image_classification"
    export DL_TYPE_FOLDER2="custom-classification"
    if [ ${MODEL_TYPE} = "1" ]; then
        export DL_TYPE_FOLDER3="efficientnet_b0"
    elif [ ${MODEL_TYPE} = "2" ]; then
        export DL_TYPE_FOLDER3="mobilenet_v3_small"
    elif [ ${MODEL_TYPE} = "2" ]; then
        export DL_TYPE_FOLDER3="mobilenet_v3_large_075"
    else
        export DL_TYPE_FOLDER3="mobilenet_v3_large_1"
    fi
elif [ ${DL_TYPE} = "2" ]; then
    export DL_TYPE_FOLDER1="object_detection"
    export DL_TYPE_FOLDER2="custom-object-detection"
    if [ ${MODEL_TYPE} = "1" ]; then
        export DL_TYPE_FOLDER3="mobilenet_v2-2s_ssd-256x256"
    elif [ ${MODEL_TYPE} = "2" ]; then
        export DL_TYPE_FOLDER3="mobilenet_v2-2s_ssd-384x384"
    else
        export DL_TYPE_FOLDER3="mobilenet_v2-2s_ssd-512x512"
    fi
elif [ ${DL_TYPE} = "3" ]; then
    export DL_TYPE_FOLDER1="instance_segmentation"
    export DL_TYPE_FOLDER2="custom-instance-segmentation"
    if [ ${MODEL_TYPE} = "1" ]; then
        export DL_TYPE_FOLDER3="efficientnet_b2b-mask_rcnn-480x480"
    else
        export DL_TYPE_FOLDER3="efficientnet_b2b-mask_rcnn-576x576"
    fi
else
    echo "not equal"
fi
cd
cd training_extensions/models/${DL_TYPE_FOLDER1}
export MODEL_TEMPLATE="`realpath ./model_templates/${DL_TYPE_FOLDER2}/${DL_TYPE_FOLDER3}/template.yaml`"
export WORK_DIR="/tmp/my_model"
python3 ../../tools/instantiate_template.py ${MODEL_TEMPLATE} ${WORK_DIR}

export OBJ_DET_DIR=`pwd`

# Copy latest mdoel file(.pth) from shared drive to workspace here 
cd ${WORK_DIR}
mkdir outputs
cp /data/start.pth ${WORK_DIR}/outputs

# Start training
python3 train.py \
    --load-weights ${WORK_DIR}/outputs/start.pth \
    --train-ann-files ${TRAIN_ANN_FILE} \
    --train-data-roots ${TRAIN_IMG_ROOT} \
    --val-ann-files ${VAL_ANN_FILE} \
    --val-data-roots ${VAL_IMG_ROOT} \
    --save-checkpoints-to ${WORK_DIR}/outputs \
    --classes ${CLASSES} \
    --epochs ${EPOCHS}

# Start evaluation and save the trained model to shared drive for future use 
python3 eval.py \
    --load-weights ${WORK_DIR}/outputs/latest.pth \
    --test-ann-files ${VAL_ANN_FILE} \
    --test-data-roots ${VAL_IMG_ROOT} \
    --save-metrics-to ${WORK_DIR}/metrics.yaml \
    --classes ${CLASSES}

cp -f ${WORK_DIR}/outputs/latest.pth /logs

# Start exporting the trained model file to the OepnVINO IR format
source /opt/intel/openvino_2021/bin/setupvars.sh
python3 export.py \
    --load-weights ${WORK_DIR}/outputs/latest.pth \
    --save-model-to ${WORK_DIR}/export

# Store the IR model to the object storageto share with follower function
cd ${WORK_DIR}/export/alt_ssd_export
pip3 install azure-storage-blob azure-storage-queue
wget https://raw.githubusercontent.com/hiouchiy/auto-train-with-openvino-training-extension-on-azure/main/azure_vm/script/upload-to-blob.py
python3 upload-to-blob.py

# Send a end message to the Slack
if [ -n ${SLACK_URL} ]; then
    wget https://raw.githubusercontent.com/hiouchiy/auto-train-with-openvino-training-extension-on-azure/main/azure_vm/script/post-to-slack.py
    python3 post-to-slack.py --slack_url ${SLACK_URL} --message "Training is done"
fi

# Enqueue to notify to removing this VM
wget https://raw.githubusercontent.com/hiouchiy/auto-train-with-openvino-training-extension-on-azure/main/azure_vm/script/enqueue.py
python3 enqueue.py
