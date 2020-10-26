#!/bin/bash

#  KALDI VERSION   447e964

source ../../../scripts/run-expt.sh "${0}"

module purge
module load kaldi-2020/5968b4c-GCC-6.4.0-2.28-OPENBLAS
module list

# print Kaldi repo version for logging
echo 'Kaldi version:'
git --no-pager --git-dir="${KALDI_ROOT}/.git/" log -n 1 
echo

. ./cmd.sh
. ./path.sh
. ./utils/parse_options.sh

nj=8
train_set="am-train" 
test_sets="devel eval"
xvec_suffix=_hires_conv


extractor_dir=exp/xvector_nnet_1a

# extract x-vectors for train data
xvectordir=exp/nnet3${nnet3_affix}/xvectors_${train_set}_sp${xvec_suffix}
sid/nnet3/xvector/extract_xvectors.sh --cmd "$train_cmd" --nj 50 \
  ${extractor_dir} \
  data/${train_set}_sp_hires_voxceleb_xvec \
  $xvectordir

# Also extract x-vectors for the test data, but in this case we don't need the speed
# perturbation (sp).
for data in ${test_sets}; do
  # nspk=$(wc -l <data/${data}_hires/spk2utt) # nj can't be larger than number of spks
  sid/nnet3/xvector/extract_xvectors.sh --cmd "$train_cmd" --nj 17 \
    ${extractor_dir} \
    data/${data}_hires_voxceleb_xvec \
    exp/nnet3/xvectors_${data}${xvec_suffix}
done

# Compute the mean vector of the training set x-vectors
# for centering the evaluation x-vectors.
$train_cmd exp/xvectors_train/log/compute_mean.log \
  ivector-mean scp:exp/nnet3/xvectors_${train_set}_sp${xvec_suffix}/xvector.scp \
  exp/nnet3/xvectors_${train_set}_sp${xvec_suffix}/mean.vec || exit 1;

# Compute LDA to decrease the dimensionality
lda_dim=200
$train_cmd exp/nnet3/xvectors_${train_set}_sp${xvec_suffix}/log/lda$lda_dim.log \
  ivector-compute-lda --total-covariance-factor=0.0 --dim=$lda_dim \
  "ark:ivector-subtract-global-mean scp:exp/nnet3/xvectors_${train_set}_sp${xvec_suffix}/xvector.scp ark:- |" \
  ark:data/${train_set}_sp/utt2spk exp/nnet3/xvectors_${train_set}_sp${xvec_suffix}/lda$lda_dim.mat || exit 1;

for data in am-train_sp ; do
  # apply LDA and concatenate the i-vectors to features
  xvecdir=exp/nnet3/xvectors_${data}${xvec_suffix}

  local/dump_with_xvec.sh --cmd "$train_cmd" \
    --nj 8 \
    data/${data}_hires \
    data/${data}_hires/data/cmvn_${data}_hires.ark \
    exp/nnet3/xvectors_${train_set}_sp${xvec_suffix}/mean.vec \
    exp/nnet3/xvectors_${train_set}_sp${xvec_suffix}/lda$lda_dim.mat \
    ${xvecdir} \
    ${xvecdir}/log_feats_lda${lda_dim}_vad \
    ${xvecdir}/feat_dump_lda${lda_dim}_vad

  cp data/${data}/utt2spk ${xvecdir}/feat_dump_lda${lda_dim}_vad/
  cp data/${data}/text ${xvecdir}/feat_dump_lda${lda_dim}_vad/
done
