# OpenVINO™ Training Extensions の使い方

OpenVINOには隠れた便利機能がたくさんありまして、このTraining Extensions（以降、OTE）もその一つになります。これはその名の通り学習処理を行うための機能で、OpenVINOが提供している事前学習済みモデルの一部をベースモデルとして転移学習を簡易的に行えるのが特徴です。
ここではOTEのインストール方法から、もっとも汎用性が高いと思われる物体検出モデル（MobileNet-SSD）の学習の仕方までを記載します。

## 前提
- Linux
- Docker

## 公式Repo
- https://github.com/openvinotoolkit/training_extensions

## インストール方法

### ホストOSにDockerインストール
```bash
sudo apt update -y
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu bionic stable"
sudo apt update
apt-cache policy docker-ce
sudo apt install -y docker-ce
```

### Dockerコンテナ起動
```bash
sudo docker run \
    -it \
    openvino/ubuntu18_dev:2021.3 \
    /bin/bash
```

### コンテナ内でソフトウェアインストール
```bash
# 必要なライブラリをインストール
apt-get update -y
apt-get install python3-pip virtualenv wget vim git -y

# Python系ライブラリもインストール
pip3 install networkx defusedxml azure-storage-blob azure-storage-queue slackweb

# Open Model Zooのリポジトリをクローン
cd
git clone https://github.com/openvinotoolkit/open_model_zoo --branch develop
export OMZ_DIR="`pwd`/open_model_zoo"

# OTEのリポジトリをクローン
cd
git clone --recursive https://github.com/openvinotoolkit/training_extensions.git
export OTE_DIR="`pwd`/training_extensions"

# OTEをインストール
cd training_extensions
pip3 install -e ote/

# MMDetectionをインストール（公式手順書には記載無し）
cd
cp -r training_extensions/external/ .
cd external/mmdetection/
pip3 install -r requirements/build.txt
pip3 install "git+https://github.com/open-mmlab/cocoapi.git#subdirectory=pycocotools"
pip3 install -v -e .
pip3 install future tensorboard
```

ここまでインストールしたものを以下のイメージ名でDockerHubにアップロードしています。

- hiouchiy/ote:2021.3

ここまでの作業が面倒な方はこのDockerイメージを活用ください。

※ [MMDetection](https://github.com/openvinotoolkit/mmdetection)とは、OTEがベースにしている学習用ソフトウェアモジュールです。

## 学習～評価～IR変換
では、作業を続けます。

```bash
# 学習用ワークスペースを作成
cd
cd training_extensions/models/object_detection
export MODEL_TEMPLATE="`realpath ./model_templates/custom-object-detection/mobilenet_v2-2s_ssd-256x256/template.yaml`"
export WORK_DIR="/tmp/my_model"
python3 ../../tools/instantiate_template.py ${MODEL_TEMPLATE} ${WORK_DIR}

# 学習用サンプル画像のパスを環境変数へ登録
export OBJ_DET_DIR=`pwd`
export TRAIN_ANN_FILE="${OBJ_DET_DIR}/../../data/airport/annotation_example_train.json"
export TRAIN_IMG_ROOT="${OBJ_DET_DIR}/../../data/airport/train"
export VAL_ANN_FILE="${OBJ_DET_DIR}/../../data/airport/annotation_example_val.json"
export VAL_IMG_ROOT="${OBJ_DET_DIR}/../../data/airport/val"

# 分類クラスを環境変数へ登録
export CLASSES="vehicle,person,non-vehicle"

# 学習開始（テストなのでEPOCHは 1 で）
cd ${WORK_DIR}
python3 train.py \
    --load-weights ${WORK_DIR}/outputs/start.pth \
    --train-ann-files ${TRAIN_ANN_FILE} \
    --train-data-roots ${TRAIN_IMG_ROOT} \
    --val-ann-files ${VAL_ANN_FILE} \
    --val-data-roots ${VAL_IMG_ROOT} \
    --save-checkpoints-to ${WORK_DIR}/outputs \
    --classes ${CLASSES} \
    --epochs 1

# モデルの評価
python3 eval.py \
    --load-weights ${WORK_DIR}/outputs/latest.pth \
    --test-ann-files ${VAL_ANN_FILE} \
    --test-data-roots ${VAL_IMG_ROOT} \
    --save-metrics-to ${WORK_DIR}/metrics.yaml \
    --classes ${CLASSES}

# モデル（.pth）をOpenVINOのIRに変換
source /opt/intel/openvino_2021/bin/setupvars.sh
python3 export.py \
    --load-weights ${WORK_DIR}/outputs/latest.pth \
    --save-model-to ${WORK_DIR}/export
```
以上です。
