<!-- omit in toc -->
# NGC PyTorch Bert 性能复现


此处给出了基于 [NGC PyTorch](https://github.com/NVIDIA/DeepLearningExamples/tree/master/PyTorch/LanguageModeling/BERT) 实现的 Bert Base Pre-Training 任务的详细复现流程，包括执行环境、Paddle版本、环境搭建、复现脚本、测试结果和测试日志。

<!-- omit in toc -->
## 目录
- [一、环境介绍](#一环境介绍)
  - [1.物理机环境](#1物理机环境)
  - [2.Docker 镜像](#2docker-镜像)
- [二、环境搭建](#二环境搭建)
  - [1. 拉取代码](#1-拉取代码)
  - [2. 构建镜像](#2-构建镜像)
  - [3. 准备数据](#3-准备数据)
- [三、测试步骤](#三测试步骤)
- [四、测试结果](#四测试结果)
  - [1.单机（单卡、8卡）测试](#1单机单卡8卡测试)
  - [2.多机（32卡）测试](#2多机32卡测试)
- [五、日志数据](#五日志数据)
  - [1.单机（单卡、8卡）日志](#1单机单卡8卡日志)


## 一、环境介绍

### 1.物理机环境

我们使用了同一个物理机环境，对 [NGC PyTorch](https://github.com/NVIDIA/DeepLearningExamples/tree/master/PyTorch/LanguageModeling/BERT) 的 Bert 模型进行了测试，详细物理机配置，见[Paddle Bert Base 性能测试](../../README.md#1.物理机环境)。

### 2.Docker 镜像

NGC PyTorch 的代码仓库提供了自动构建 Docker 镜像的的 [shell 脚本](https://github.com/NVIDIA/DeepLearningExamples/tree/master/PyTorch/LanguageModeling/BERT/scripts/docker/build.sh)，

- 镜像版本：`nvcr.io/nvidia/pytorch:20.06-py3`

## 二、环境搭建

我们遵循了 NGC PyTorch 官网提供的 [Quick Start Guide](https://github.com/NVIDIA/DeepLearningExamples/tree/master/PyTorch/LanguageModeling/BERT#quick-start-guide) 教程成功搭建了测试环境，主要过程如下：
### 1. 拉取代码

```bash
git clone https://github.com/NVIDIA/DeepLearningExamples
cd DeepLearningExamples/PyTorch/LanguageModeling/BERT
```

### 2. 构建镜像
```bash
bash scripts/docker/build.sh   # 构建镜像
bash scripts/docker/launch.sh  # 启动容器
```

我们将 `launch.sh` 脚本中的 `docker` 命令换为了 `nvidia-docker` 启动的支持 GPU 的容器，其他均保持不变，脚本如下：
```bash
#!/bin/bash

CMD=${1:-/bin/bash}
NV_VISIBLE_DEVICES=${2:-"all"}
DOCKER_BRIDGE=${3:-"host"}

nvidia-docker run --name test_bert_torch -it  \
  --net=$DOCKER_BRIDGE \
  --shm-size=1g \
  --ulimit memlock=-1 \
  --ulimit stack=67108864 \
  -e LD_LIBRARY_PATH='/workspace/install/lib/' \
  -v $PWD:/workspace/bert \
  -v $PWD/results:/results \
  bert $CMD
```

### 3. 准备数据

NGC PyTorch 提供单独的数据下载和预处理脚本 [data/create_datasets_from_start.sh](https://github.com/NVIDIA/DeepLearningExamples/blob/master/PyTorch/LanguageModeling/BERT/data/create_datasets_from_start.sh)。在容器中执行如下命令，可以下载和制作 `wikicorpus_en` 的 hdf5 数据集。

```bash
bash data/create_datasets_from_start.sh wiki_only
```

> TODO(Aurelius84): 确定是否要提供一份处理好的 wikipedia 的 tfrecord 样本数据集链接。

由于数据集比较大，且容易受网速的影响，上述命令执行时间较长。因此，为了更方便复现竞品的性能数据，我们提供了已经处理好的 hdf5 格式[样本数据集]()。

## 三、测试步骤

为了更准确的复现 NGC PyTorch 公布的 [NVIDIA DGX-1 (8x V100 32GB)](https://github.com/NVIDIA/DeepLearningExamples/tree/master/PyTorch/LanguageModeling/BERT#training-performance-nvidia-dgx-1-8x-v100-32g) 性能数据，我们严格按照官方提供的模型代码配置、启动脚本，进行了的性能测试。

官方提供的 [scripts/run_pretraining.sh](https://github.com/NVIDIA/DeepLearningExamples/blob/master/PyTorch/LanguageModeling/BERT/scripts/run_pretraining.sh) 执行脚本中，默认配置的是两阶段训练。我们此处统一仅执行 **第一阶段训练**，并根据日志中的输出的数据计算吞吐。

**重要的配置参数：**

- **train_batch_size**: 用于第一阶段的单卡总 batch_size, 单卡每步有效 batch_size = train_batch_size / gradient_accumulation_steps
- **precision**: 用于指定精度训练模式，fp32 或 fp16
- **use_xla**: 是否开启 XLA 加速，我们统一开启此选项
- **num_gpus**: 用于指定 GPU 卡数
- **gradient_accumulation_steps**: 每次执行optimizer前的梯度累加步数
- **BERT_CONFIG:** 用于指定 base 或 large 模型的参数配置文件 (line:49)
- **--bert_model:** 用于指定模型类型，默认为`bert-large-uncased`

由于官方默认给出的是支持两阶段训练的**Bert Large**模型的训练配置，若要测**Bert Base**模型，需要对 `run_pretraining.sh` 进行如下改动：

- 在 `bert` 项目根目录新建一个 `bert_config_base.json` 配置文件，内容如下：
  ```
  {
  "attention_probs_dropout_prob": 0.1,
  "hidden_act": "gelu",
  "hidden_dropout_prob": 0.1,
  "hidden_size": 768,
  "initializer_range": 0.02,
  "intermediate_size": 3072,
  "max_position_embeddings": 512,
  "num_attention_heads": 12,
  "num_hidden_layers": 12,
  "type_vocab_size": 2,
  "vocab_size": 30522
  }
  ```
- 修改 `run_pretraining.sh`的第39行内容为：
  ```bash
  BERT_CONFIG=bert_config_base.json
  ```
- 修改 `run_pretraining.sh`的第110行内容为：
  ```bash
  CMD+=" --bert_model=bert-base-uncased"
  ```
- 由于不需要执行第二阶段训练，故需要注释 `run_pretraining.sh` 的第154行到最后，即：
  ```bash
  #Start Phase2

  # PREC=""
  # if [ "$precision" = "fp16" ] ; then
  #    PREC="--fp16"

  # ......(此处省略中间部分)

  # echo "finished phase2"
  ```

同时，为了更方便地测试不同 batch_size、num_gpus、precision组合下的 Pre-Training 性能，我们单独编写了 `run_benchmark.sh` 脚本，并放在`scripts`目录下。

shell 脚本内容如下：
```bash
#!/bin/bash

set -x

batch_size=$1  # batch size per gpu
num_gpus=$2    # number of gpu
precision=$3   # fp32 | fp16
gradient_accumulation_steps=$(expr 65536 \/ $batch_size \/ $num_gpus)
train_batch_size=$(expr 65536 \/ $num_gpus)   # total batch_size per gpu
train_steps=${4:-250}    # max train steps

# run pre-training
bash scripts/run_pretraining.sh $train_batch_size 6e-3 $precision $num_gpus 0.2843 $train_steps 200 false true true $gradient_accumulation_steps
```

## 四、测试结果
### 1.单机（单卡、8卡）测试

**单卡启动脚本：**

若测试单机单卡 batch_size=32、FP32 的训练性能，执行如下命令：

```bash
bash scripts/run_benchmark.sh 32 1 fp32
```

**8卡启动脚本：**

若测试单机8卡 batch_size=64、FP16 的训练性能，执行如下命令：

```bash
bash scripts/run_benchmark.sh 64 8 fp16
```

> 单位： sentences/s

|卡数 | FP32(BS=32) | FP32(BS=64) | AMP(BS=64) | AMP(BS=128)|
|-----|-----|-----|-----|-----|
|1 | 125.59 | 127.02 | 488.47 | 527.38|
|8 | - | - | - | -|

### 2.多机（32卡）测试

## 五、日志数据
### 1.单机（单卡、8卡）日志

- [单卡 bs=32、FP32](./logs/bert_base_lamb_pretraining.pyt_bert_pretraining_phase1_fp32_bs32_gpu1_gbs65536.log)
```
DLL 2020-12-07 22:44:09.988873 -  e2e_train_time : 10446.27070569992  training_sequences_per_second : 125.59499598892388  final_loss : 8.561482429504395  raw_train_time : 10436.084572315216
```

- [单卡 bs=64、FP32](./logs/bert_base_lamb_pretraining.pyt_bert_pretraining_phase1_fp32_bs64_gpu1_gbs65536.log)
```
DLL 2020-12-07 18:57:58.661625 -  e2e_train_time : 25807.294572353363  training_sequences_per_second : 127.02065199967637  final_loss : 7.978199005126953  raw_train_time : 25797.37978363037
```

- [单卡 bs=64、FP16](./logs/bert_base_lamb_pretraining.pyt_bert_pretraining_phase1_fp16_bs64_gpu1_gbs65536.log)
```
DLL 2020-12-07 23:40:17.655191 -  e2e_train_time : 3363.891343355179  training_sequences_per_second : 488.4692734715151  final_loss : 8.557624816894531  raw_train_time : 3354.1516098976135
```

- [单卡 bs=128、FP16](./logs/bert_base_lamb_pretraining.pyt_bert_pretraining_phase1_fp16_bs128_gpu1_gbs65536.log)
```
DLL 2020-12-07 19:49:59.849225 -  e2e_train_time : 3117.3372247219086  training_sequences_per_second : 527.3885210665798  final_loss : 8.557418823242188  raw_train_time : 3106.6281015872955
```
