#!/bin/bash

source ../../../scripts/run-expt.sh "${0}"

module purge
module load kaldi-2020/5968b4c-GCC-6.4.0-2.28-OPENBLAS
module list

. ./cmd.sh
. ./path.sh
. ./utils/parse_options.sh

nnet_dir=exp/nnet3
xvec_dir=xvectors_am-train_sp_hires_voxceleb_vad

$train_cmd $nnet_dir/$xvec_dir/log/plda.log \
    ivector-compute-plda ark:data/train/spk2utt \
    "ark:ivector-subtract-global-mean scp:$nnet_dir/$xvec_dir/xvector.scp ark:- | transform-vec $nnet_dir/$xvec_dir/transform.mat ark:- ark:- | ivector-normalize-length ark:-  ark:- |" \
    $nnet_dir/$xvec_dir/plda || exit 1;