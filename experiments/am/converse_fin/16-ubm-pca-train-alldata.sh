#!/bin/bash

source ../../../scripts/run-expt.sh "${0}"

module purge
module load kaldi-2020/5968b4c-GCC-6.4.0-2.28-OPENBLAS
module list

. ./cmd.sh
. ./path.sh
. ./utils/parse_options.sh

nj=30
train_set="am-train" # you might set this to e.g. train.
test_sets="devel eval"

num_threads_ubm=32
nnet3_affix=_alldata    # affix for exp/nnet3 directory to put iVector stuff in (e.g.
                # in the tedlium recip it's _cleaned).

mkdir -p exp/nnet3${nnet3_affix}/diag_ubm
temp_data_root=exp/nnet3${nnet3_affix}/diag_ubm

echo "$0: computing a PCA transform from the hires data."
steps/online/nnet2/get_pca_transform.sh --cmd "$train_cmd" \
    --splice-opts "--left-context=3 --right-context=3" \
    --max-utts 10000 --subsample 2 \
    data/${train_set}_sp_hires \
    exp/nnet3${nnet3_affix}/pca_transform

echo "$0: training the diagonal UBM."
# Use 512 Gaussians in the UBM.
steps/online/nnet2/train_diag_ubm.sh --cmd "$train_cmd" --nj 30 \
    --num-frames 700000 \
    --num-threads 16 \
    data/${train_set}_sp_hires 512 \
    exp/nnet3${nnet3_affix}/pca_transform \
    exp/nnet3${nnet3_affix}/diag_ubm
