#!/bin/bash

source ../../../scripts/run-expt.sh "${0}"

module purge
module load kaldi-vanilla
module list

. utils/parse_options.sh  # e.g. this parses the --stage option if supplied.

num_threads_ubm=32

echo "$0: computing a LDA+MLLT transform from the hires data."
steps/train_lda_mllt.sh --cmd "$train_cmd" \
    --num-iters 13 \
    --realign-iters "" \
    --splice-opts "--left-context=3 --right-context=3" \
    5000 10000 \
    data/am-train \
    data/lang \
    exp/tri3b_mmi_b0.1_ali \
    exp/small-lda-mllt

echo "$0: training the diagonal UBM."
# Use 512 Gaussians in the UBM.
steps/online/nnet2/train_diag_ubm.sh --cmd "$train_cmd" --nj 30 \
    --num-frames 400000 \
    --num-threads 16 \
    data/am-train 256 \
    exp/small-lda-mllt \
    exp/diag_ubm

