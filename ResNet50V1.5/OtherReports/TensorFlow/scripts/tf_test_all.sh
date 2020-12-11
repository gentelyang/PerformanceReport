#!/bin/bash

rm -rf /tmp/result/*

python ./main.py --mode=training_benchmark \
	--use_xla \
	--warmup_steps 200 \
	--num_iter 500 \
	--iter_unit batch \
	--batch_size 128 \
	--data_dir=/data/tfrecords/ \
	--results_dir=/tmp/result/gpu1_fp32_bs128 > /data/tfrecords/log/tf_gpu1_fp32_bs128.txt

python ./main.py --mode=training_benchmark \
	--use_xla \
	--warmup_steps 200 \
	--num_iter 500 \
	--iter_unit batch \
	--batch_size 256 \
	--data_dir=/data/tfrecords/ \
	--results_dir=/tmp/result/gpu1_fp32_bs256 > /data/tfrecords/log/tf_gpu1_fp32_bs256.txt

python ./main.py --mode=training_benchmark \
	--use_xla \
	--warmup_steps 200 \
	--num_iter 500 \
	--iter_unit batch \
	--batch_size 128 \
	--data_dir=/data/tfrecords/ \
	--results_dir=/tmp/result/gpu1_amp_bs128 \
	--use_tf_amp \
	--use_static_loss_scaling \
	--loss_scale=128 > /data/tfrecords/log/tf_gpu1_amp_bs128.txt

python ./main.py --mode=training_benchmark \
	--use_xla \
	--warmup_steps 200 \
	--num_iter 500 \
	--iter_unit batch \
	--batch_size 256 \
	--data_dir=/data/tfrecords/ \
	--results_dir=/tmp/result/gpu1_amp_bs256 \
	--use_tf_amp \
	--use_static_loss_scaling \
	--loss_scale=128 > /data/tfrecords/log/tf_gpu1_amp_bs256.txt

mpiexec --allow-run-as-root --bind-to socket -np 8 python3 main.py --mode=training_benchmark \
	--use_xla \
	--warmup_steps 200 \
	--num_iter 500 \
	--iter_unit batch \
	--batch_size 128 \
	--data_dir=/data/tfrecords/ \
	--results_dir=/tmp/result/gpu8_fp32_bs128 > /data/tfrecords/log/tf_gpu8_fp32_bs128.txt

mpiexec --allow-run-as-root --bind-to socket -np 8 python3 main.py --mode=training_benchmark \
	--use_xla \
	--warmup_steps 200 \
	--num_iter 500 \
	--iter_unit batch \
	--batch_size 256 \
	--data_dir=/data/tfrecords/ \
	--results_dir=/tmp/result/gpu8_fp32_bs256 > /data/tfrecords/log/tf_gpu8_fp32_bs256.txt

mpiexec --allow-run-as-root --bind-to socket -np 8 python3 main.py --mode=training_benchmark \
	--use_xla \
	--warmup_steps 200 \
	--num_iter 500 \
	--iter_unit batch \
	--batch_size 128 \
	--data_dir=/data/tfrecords/ \
	--results_dir=/tmp/result/gpu8_amp_bs128 \
	--use_tf_amp \
	--use_static_loss_scaling \
	--loss_scale=128 > /data/tfrecords/log/tf_gpu8_amp_bs128.txt

mpiexec --allow-run-as-root --bind-to socket -np 8 python3 main.py --mode=training_benchmark \
	--use_xla \
	--warmup_steps 200 \
	--num_iter 500 \
	--iter_unit batch \
	--batch_size 256 \
	--data_dir=/data/tfrecords/ \
	--results_dir=/tmp/result/gpu8_amp_bs256 \
	--use_tf_amp \
	--use_static_loss_scaling \
	--loss_scale=128 > /data/tfrecords/log/tf_gpu8_amp_bs256.txt
