#!/bin/bash

source ../../../scripts/run-expt.sh "${0}"

module purge
module load kaldi-2020/5968b4c-GCC-6.4.0-2.28-OPENBLAS
module list

. ./cmd.sh
. ./path.sh
. ./utils/parse_options.sh

stage=1

nj=30
train_set="am-train" # you might set this to e.g. train.
test_sets="devel eval"

nnet3_affix_src=
nnet3_affix_tgt=_ensemble
xvec_suffix=_hires_voxceleb_vad
ivec_suffix=_hires_voxceleb_vad

lda_dim=100

if [ $stage -le 1 ]; then
  # Compute LDA to decrease the dimensionality
  $train_cmd exp/nnet3${nnet3_affix_src}/xvectors_${train_set}_sp${xvec_suffix}/log/lda$lda_dim.log \
    ivector-compute-lda --total-covariance-factor=0.0 --dim=$lda_dim \
    "ark:ivector-subtract-global-mean scp:exp/nnet3${nnet3_affix_src}/xvectors_${train_set}_sp${xvec_suffix}/xvector.scp ark:- |" \
    ark:data/${train_set}_sp/utt2spk exp/nnet3${nnet3_affix_src}/xvectors_${train_set}_sp${xvec_suffix}/lda$lda_dim.mat || exit 1;
fi

if [ $stage -le 2 ]; then
  for data in ${train_set}_sp ${test_sets} ; do
    # apply LDA and concatenate the i-vectors to features
    xvecdir_src=exp/nnet3${nnet3_affix_src}/xvectors_${data}${xvec_suffix}
    xvecdir_tgt=exp/nnet3${nnet3_affix_tgt}/xvectors_${data}${xvec_suffix}

    ivecdir=exp/nnet3${nnet3_affix_src}/ivectors_${data}${ivec_suffix}

    local/dump_with_xvec_ivec_ensemble.sh --cmd "$train_cmd" \
      --nj 8 \
      data/${data}_hires \
      data/${data}_hires/data/cmvn_${data}_hires.ark \
      exp/nnet3${nnet3_affix_src}/xvectors_${train_set}_sp${xvec_suffix}/mean.vec \
      exp/nnet3${nnet3_affix_src}/xvectors_${train_set}_sp${xvec_suffix}/lda$lda_dim.mat \
      ${xvecdir_src} \
      exp/nnet3${nnet3_affix_src}/ivectors_${train_set}_sp${ivec_suffix}/mean.vec \
      exp/nnet3${nnet3_affix_src}/ivectors_${train_set}_sp${ivec_suffix}/lda$lda_dim.mat \
      ${ivecdir} \
      ${xvecdir_tgt}/log_feats_lda${lda_dim}_vad \
      ${xvecdir_tgt}/feat_dump_lda${lda_dim}_vad

    cp data/${data}/utt2spk ${xvecdir_tgt}/feat_dump_lda${lda_dim}_vad/
    cp data/${data}/text ${xvecdir_tgt}/feat_dump_lda${lda_dim}_vad/
  done
fi


exit 0;
