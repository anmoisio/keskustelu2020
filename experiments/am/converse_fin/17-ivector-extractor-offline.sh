#!/bin/bash

source ../../../scripts/run-expt.sh "${0}"

module purge
module load kaldi-2020/5968b4c-GCC-6.4.0-2.28-OPENBLAS
module list

. ./cmd.sh
. ./path.sh
. ./utils/parse_options.sh

stage=2

nj=30
train_set="am-train" # you might set this to e.g. train.
test_sets="devel eval"

nj_extractor=30
# It runs a JOB with '-pe smp N', where N=$[threads*processes]
num_processes_extractor=1
num_threads_extractor=1

nnet3_affix=_offline    # affix for exp/nnet3 directory to put iVector stuff in (e.g.
                # in the tedlium recip it's _cleaned).

train_data=data/am-train_sp_hires_voxceleb

if [ $stage -le 1 ]; then
  # Train the UBM.
  sid/train_diag_ubm.sh --cmd "$train_cmd" \
    --nj 40 --num-threads 8 \
    --num-frames 700000 \
    $train_data 512 \
    exp/nnet3${nnet3_affix}/diag_ubm_vc

  sid/train_full_ubm.sh --cmd "utils/slurm.pl --mem 25G --time 1:00:00" \
    --nj 40 --remove-low-count-gaussians false \
    $train_data \
    exp/nnet3${nnet3_affix}/diag_ubm_vc \
    exp/nnet3${nnet3_affix}/full_ubm_vc
fi

if [ $stage -le 2 ]; then
  # Train the iVector extractor.  Use all of the speed-perturbed data since iVector extractors
  # can be sensitive to the amount of data. 
  echo "$0: training the iVector extractor"
  sid/train_ivector_extractor.sh --cmd "$train_cmd" \
    --ivector-dim 400 \
    --num-iters 5 \
    --nj $nj_extractor \
    --num-threads $num_threads_extractor \
    --num-processes $num_processes_extractor \
    exp/nnet3${nnet3_affix}/full_ubm_vc/final.ubm \
    $train_data \
    exp/nnet3${nnet3_affix}/extractor || exit 1;
fi

if [ $stage -le 3 ]; then
  sid/extract_ivectors.sh --cmd "$train_cmd" --nj 40 \
    exp/nnet3${nnet3_affix}/extractor \
    data/${train_set}_sp_hires_voxceleb \
    exp/nnet3${nnet3_affix}/ivectors_${train_set}_sp_hires

  # Also extract iVectors for the test data, but in this case we don't need the speed
  # perturbation (sp).
  for data in ${test_sets}; do
    sid/extract_ivectors.sh --cmd "$train_cmd" --nj 17 \
        exp/nnet3${nnet3_affix}/extractor \
        data/${data}_hires_voxceleb  \
        exp/nnet3${nnet3_affix}/ivectors_${data}_hires
  done
fi

if [ $stage -le 4 ]; then
  # Compute the mean vector of the training set i-vectors
  # for centering the evaluation i-vectors.
  $train_cmd exp/nnet3${nnet3_affix}/ivectors_train/log/compute_mean.log \
    ivector-mean scp:exp/nnet3${nnet3_affix}/ivectors_${train_set}_sp_hires/ivector.scp \
    exp/nnet3${nnet3_affix}/ivectors_${train_set}_sp_hires/mean.vec || exit 1;
fi

if [ $stage -le 5 ]; then
  ivec_suffix=_hires
  # # Compute LDA to decrease the dimensionality
  lda_dim=200
  $train_cmd exp/nnet3${nnet3_affix}/ivectors_${train_set}_sp${ivec_suffix}/log/lda$lda_dim.log \
    ivector-compute-lda --total-covariance-factor=0.0 --dim=$lda_dim \
    "ark:ivector-subtract-global-mean scp:exp/nnet3${nnet3_affix}/ivectors_${train_set}_sp${ivec_suffix}/ivector.scp ark:- |" \
    ark:data/${train_set}_sp/utt2spk exp/nnet3${nnet3_affix}/ivectors_${train_set}_sp${ivec_suffix}/lda$lda_dim.mat || exit 1;

  for data in ${train_set}_sp ${test_sets}; do
    # apply LDA and concatenate the i-vectors to features
    ivecdir=exp/nnet3${nnet3_affix}/ivectors_${data}${ivec_suffix}

    local/dump_with_ivec.sh --cmd "$train_cmd" \
      --nj 8 \
      data/${data}_hires \
      data/${data}_hires/data/cmvn_${data}_hires.ark \
      exp/nnet3${nnet3_affix}/ivectors_${train_set}_sp${ivec_suffix}/mean.vec \
      exp/nnet3${nnet3_affix}/ivectors_${train_set}_sp${ivec_suffix}/lda$lda_dim.mat \
      ${ivecdir} \
      ${ivecdir}/log_feats_lda${lda_dim}_vad \
      ${ivecdir}/feat_dump_lda${lda_dim}_vad

    cp data/${data}/utt2spk ${ivecdir}/feat_dump_lda${lda_dim}_vad/
    cp data/${data}/text ${ivecdir}/feat_dump_lda${lda_dim}_vad/
  done
fi