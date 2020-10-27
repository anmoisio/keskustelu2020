#!/bin/bash

source ../../../scripts/run-expt.sh "${0}"

module purge
module load kaldi-2020/5968b4c-GCC-6.4.0-2.28-OPENBLAS
module list

. ./cmd.sh
. ./path.sh
. ./utils/parse_options.sh

stage=3

nj=30
train_set="am-train" # you might set this to e.g. train.
test_sets="devel eval"

nnet3_affix=    # affix for exp/nnet3 directory to put iVector stuff in (e.g.
                # in the tedlium recip it's _cleaned).

num_threads_ubm=32

nj_extractor=10
# It runs a JOB with '-pe smp N', where N=$[threads*processes]
num_processes_extractor=1
num_threads_extractor=1

if [ $stage -le 1 ]; then
  # echo "$0: computing a subset of data to train the diagonal UBM."
  mkdir -p exp/nnet3${nnet3_affix}/diag_ubm_700k_spdsp
  temp_data_root=exp/nnet3${nnet3_affix}/diag_ubm_700k_spdsp

  # train a diagonal UBM using a subset of about half of the data
  num_utts_total=$(wc -l <data/${train_set}_sp_dsp_hires/utt2spk)
  num_utts=$[$num_utts_total/2]
  utils/data/subset_data_dir.sh \
      data/${train_set}_sp_dsp_hires \
      $num_utts \
      ${temp_data_root}/${train_set}_sp_dsp_hires_subset

  echo "$0: computing a PCA transform from the hires data."
  steps/online/nnet2/get_pca_transform.sh --cmd "$train_cmd" \
      --splice-opts "--left-context=3 --right-context=3" \
      --max-utts 10000 --subsample 2 \
      ${temp_data_root}/${train_set}_sp_dsp_hires_subset \
      exp/nnet3${nnet3_affix}/pca_transform_spdsp

  echo "$0: training the diagonal UBM."
  # Use 512 Gaussians in the UBM.
  steps/online/nnet2/train_diag_ubm.sh --cmd "$train_cmd" --nj 30 \
      --num-frames 700000 \
      --num-threads 16 \
      ${temp_data_root}/${train_set}_sp_dsp_hires_subset 512 \
      exp/nnet3${nnet3_affix}/pca_transform_spdsp \
      exp/nnet3${nnet3_affix}/diag_ubm_700k_spdsp
fi


if [ $stage -le 2 ]; then
  # Train the iVector extractor.  Use all of the speed-perturbed data since iVector extractors
  # can be sensitive to the amount of data.  The script defaults to an iVector dimension of
  # 100.
  echo "$0: training the iVector extractor"
  steps/online/nnet2/train_ivector_extractor.sh --cmd "$train_cmd" \
    --nj $nj_extractor \
    --num-threads $num_threads_extractor \
    --num-processes $num_processes_extractor \
    data/${train_set}_sp_dsp_hires \
    exp/nnet3${nnet3_affix}/diag_ubm_700k_spdsp \
    exp/nnet3${nnet3_affix}/extractor_spdsp || exit 1;


  # note, we don't encode the 'max2' in the name of the ivectordir even though
  # that's the data we extract the ivectors from, as it's still going to be
  # valid for the non-'max2' data; the utterance list is the same.
  ivectordir=exp/nnet3${nnet3_affix}/ivectors_${train_set}_sp_dsp_hires

  # We now extract iVectors on the speed-perturbed training data .  With
  # --utts-per-spk-max 2, the script pairs the utterances into twos, and treats
  # each of these pairs as one speaker; this gives more diversity in iVectors..
  # Note that these are extracted 'online' (they vary within the utterance).

  # Having a larger number of speakers is helpful for generalization, and to
  # handle per-utterance decoding well (the iVector starts at zero at the beginning
  # of each pseudo-speaker).
  temp_data_root=${ivectordir}
  utils/data/modify_speaker_info.sh \
    --utts-per-spk-max 2 \
    data/${train_set}_sp_dsp_hires \
    ${temp_data_root}/${train_set}_sp_dsp_hires_max2

  steps/online/nnet2/extract_ivectors_online.sh --cmd "$train_cmd" --nj $nj \
    ${temp_data_root}/${train_set}_sp_dsp_hires_max2 \
    exp/nnet3${nnet3_affix}/extractor_spdsp \
    $ivectordir
fi

if [ $stage -le 3 ]; then
  # Also extract iVectors for the test data, but in this case we don't need the speed
  # perturbation (sp).
  for data in ${test_sets}; do
    nspk=$(wc -l <data/${data}_hires/spk2utt)
    steps/online/nnet2/extract_ivectors_online.sh --cmd "$train_cmd" --nj 1 \
        data/${data}_hires \
        exp/nnet3${nnet3_affix}/extractor_spdsp \
        exp/nnet3${nnet3_affix}/ivectors_${data}_hires_spdsp
  done
fi