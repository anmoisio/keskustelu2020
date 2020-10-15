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
train_set="am-train" # you might set this to e.g. train.
test_sets="devel eval"
ivec_suffix=_hires_voxceleb_vad

# # note, we don't encode the 'max2' in the name of the ivectordir even though
# # that's the data we extract the ivectors from, as it's still going to be
# # valid for the non-'max2' data; the utterance list is the same.
ivectordir=exp/nnet3${nnet3_affix}/ivectors_${train_set}_sp${ivec_suffix}

# # We now extract iVectors on the speed-perturbed training data .  With
# # --utts-per-spk-max 2, the script pairs the utterances into twos, and treats
# # each of these pairs as one speaker; this gives more diversity in iVectors..
# # Note that these are extracted 'online' (they vary within the utterance).

# # Having a larger number of speakers is helpful for generalization, and to
# # handle per-utterance decoding well (the iVector starts at zero at the beginning
# # of each pseudo-speaker).
temp_data_root=${ivectordir}
# utils/data/modify_speaker_info.sh \
#   --utts-per-spk-max 2 \
#   data/${train_set}_sp_hires_voxceleb  \
#   ${temp_data_root}/${train_set}_sp_hires_voxceleb_max2

# sid/compute_vad_decision.sh --nj $nj --cmd "$train_cmd" \
#   --vad-config 0007_voxceleb_v1_1a/conf/vad.conf \
#   ${temp_data_root}/${train_set}_sp_hires_voxceleb_max2

# extractor_dir=0007_voxceleb_v1_1a/exp/extractor 
# sid/extract_ivectors.sh --cmd "$train_cmd" --nj 40 \
#   ${extractor_dir} \
#   ${temp_data_root}/${train_set}_sp_hires_voxceleb_max2 \
#   $ivectordir

# # Also extract iVectors for the test data, but in this case we don't need the speed
# # perturbation (sp).
# for data in ${test_sets}; do
#   # nspk=$(wc -l <data/${data}_hires/spk2utt) # nj can't be larger than number of spks
#   sid/extract_ivectors.sh --cmd "$train_cmd" --nj 17 \
#       ${extractor_dir} \
#       data/${data}_hires_voxceleb  \
#       exp/nnet3/ivectors_${data}${ivec_suffix}
# done

# Compute the mean vector of the training set i-vectors
# for centering the evaluation i-vectors.
# $train_cmd exp/ivectors_train/log/compute_mean.log \
#   ivector-mean scp:exp/nnet3/ivectors_${train_set}_sp${ivec_suffix}/ivector.scp \
#   exp/nnet3/ivectors_${train_set}_sp${ivec_suffix}/mean.vec || exit 1;

# # Compute LDA to decrease the dimensionality
lda_dim=200
# $train_cmd exp/nnet3/ivectors_${train_set}_sp${ivec_suffix}/log/lda$lda_dim.log \
#   ivector-compute-lda --total-covariance-factor=0.0 --dim=$lda_dim \
#   "ark:ivector-subtract-global-mean scp:exp/nnet3/ivectors_${train_set}_sp${ivec_suffix}/ivector.scp ark:- |" \
#   ark:data/${train_set}_sp/utt2spk exp/nnet3/ivectors_${train_set}_sp${ivec_suffix}/lda$lda_dim.mat || exit 1;

for data in ${train_set}_sp ; do
  # apply LDA and concatenate the i-vectors to features
  ivecdir=exp/nnet3/ivectors_${data}${ivec_suffix}

  local/dump_with_ivec.sh --cmd "$train_cmd" \
    --nj 8 \
    data/${data}_hires \
    data/${data}_hires/data/cmvn_${data}_hires.ark \
    exp/nnet3/ivectors_${train_set}_sp${ivec_suffix}/mean.vec \
    exp/nnet3/ivectors_${train_set}_sp${ivec_suffix}/lda$lda_dim.mat \
    ${ivecdir} \
    ${ivecdir}/log_feats_lda${lda_dim}_vad \
    ${ivecdir}/feat_dump_lda${lda_dim}_vad

  cp data/${data}/utt2spk ${ivecdir}/feat_dump_lda${lda_dim}_vad/
  cp data/${data}/text ${ivecdir}/feat_dump_lda${lda_dim}_vad/
done

  # transform-feats \
  #   ${ivecdir}/lda.mat \
  #   scp:${ivecdir}/ivector.scp \
  #   ark,scp:${ivecdir}/ivector_lda.ark,${ivecdir}/ivector_lda.scp

  # old number of dimensions
  # feat-to-dim scp:${ivecdir}/ivector.scp -
  # new number of dimensions
  # feat-to-dim scp:${ivecdir}/ivector_lda.scp -