#!/bin/bash

apt-get update -y
apt-get install python3-pip virtualenv wget vim git -y
apt-get install libsm6 libxrender1 libxext-dev -y

cd
git clone --recursive https://github.com/openvinotoolkit/training_extensions.git
export OTE_DIR="`pwd`/training_extensions"

git clone https://github.com/openvinotoolkit/open_model_zoo --branch develop
export OMZ_DIR="`pwd`/open_model_zoo"

cd training_extensions

pip3 install -e ote/
pip3 install torch==1.8.1+cpu torchvision==0.9.1+cpu torchaudio==0.8.1 -f https://download.pytorch.org/whl/torch_stable.html
#pip3 install pycocotools

cd models/object_detection
export MODEL_TEMPLATE="`realpath ./model_templates/custom-object-detection/mobilenet_v2-2s_ssd-256x256/template.yaml`"
export WORK_DIR="/tmp/my_model"

python3 ../../tools/instantiate_template.py ${MODEL_TEMPLATE} ${WORK_DIR}

export OBJ_DET_DIR=`pwd`

cd
cp -r training_extensions/external/ .
cd external/mmdetection/
pip3 install -r requirements/build.txt
pip3 install "git+https://github.com/open-mmlab/cocoapi.git#subdirectory=pycocotools"
pip3 install -v -e .
#pip3 install future tensorboard
pip3 install future tensorboard==1.15.0

cd ${WORK_DIR}
mkdir outputs
cp /data/start.pth ${WORK_DIR}/outputs

python3 train.py \
    --load-weights ${WORK_DIR}/outputs/start.pth \
    --train-ann-files ${TRAIN_ANN_FILE} \
    --train-data-roots ${TRAIN_IMG_ROOT} \
    --val-ann-files ${VAL_ANN_FILE} \
    --val-data-roots ${VAL_IMG_ROOT} \
    --save-checkpoints-to ${WORK_DIR}/outputs \
    --classes ${CLASSES} \
    --epochs 1 >> /logs/train.log

python3 eval.py \
    --load-weights ${WORK_DIR}/outputs/latest.pth \
    --test-ann-files ${VAL_ANN_FILE} \
    --test-data-roots ${VAL_IMG_ROOT} \
    --save-metrics-to ${WORK_DIR}/metrics.yaml \
    --classes ${CLASSES} >> /logs/train.log

cp -f ${WORK_DIR}/outputs/latest.pth /logs

#source /opt/intel/openvino_2021/bin/setupvars.sh
source /opt/intel/openvino/bin/setupvars.sh
pip3 install networkx defusedxml

python3 export.py \
    --load-weights ${WORK_DIR}/outputs/latest.pth \
    --save-model-to ${WORK_DIR}/export >> /logs/train.log

cd ${WORK_DIR}/export/alt_ssd_export
pip3 install azure-storage-blob azure-storage-queue slackweb >> /logs/train.log
wget https://raw.githubusercontent.com/hiouchiy/auto-train-with-openvino-training-extension-on-azure/main/upload-to-blob.py >> /logs/train.log
wget https://raw.githubusercontent.com/hiouchiy/auto-train-with-openvino-training-extension-on-azure/main/enqueue.py >> /logs/train.log
wget https://raw.githubusercontent.com/hiouchiy/auto-train-with-openvino-training-extension-on-azure/main/post-to-slack.py >> /logs/train.log
python3 upload-to-blob.py >> /logs/train.log
python3 post-to-slack.py --slack_url ${SLACK_URL} --message "Training is done" >> /logs/train.log
python3 enqueue.py >> /logs/train.log
