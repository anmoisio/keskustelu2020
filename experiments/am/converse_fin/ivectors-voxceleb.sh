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

# # note, we don't encode the 'max2' in the name of the ivectordir even though
# # that's the data we extract the ivectors from, as it's still going to be
# # valid for the non-'max2' data; the utterance list is the same.
# ivectordir=exp/nnet3${nnet3_affix}/ivectors_${train_set}_sp_hires_voxceleb 

# # We now extract iVectors on the speed-perturbed training data .  With
# # --utts-per-spk-max 2, the script pairs the utterances into twos, and treats
# # each of these pairs as one speaker; this gives more diversity in iVectors..
# # Note that these are extracted 'online' (they vary within the utterance).

# # Having a larger number of speakers is helpful for generalization, and to
# # handle per-utterance decoding well (the iVector starts at zero at the beginning
# # of each pseudo-speaker).
# temp_data_root=${ivectordir}
# utils/data/modify_speaker_info.sh \
#   --utts-per-spk-max 2 \
#   data/${train_set}_sp_hires_voxceleb  \
#   ${temp_data_root}/${train_set}_sp_hires_voxceleb_max2

# extractor_dir=0007_voxceleb_v1_1a/exp/extractor 
# sid/extract_ivectors.sh --cmd "$train_cmd" --nj 40 \
#   ${extractor_dir} \
#   ${temp_data_root}/${train_set}_sp_hires_voxceleb_max2 \
#   $ivectordir

# # Also extract iVectors for the test data, but in this case we don't need the speed
# # perturbation (sp).
# for data in ${test_sets}; do
#   # nspk=$(wc -l <data/${data}_hires/spk2utt)
#   sid/extract_ivectors.sh --cmd "$train_cmd" --nj 17 \
#       ${extractor_dir} \
#       data/${data}_hires_voxceleb  \
#       exp/nnet3${nnet3_affix}/ivectors_${data}_hires_voxceleb 
# done

# for data in ${train_set}_sp ${test_sets}; do
#   # Compute the mean vector for centering the evaluation i-vectors.
#   $train_cmd exp/ivectors_train/log/compute_mean.log \
#     ivector-mean scp:exp/nnet3${nnet3_affix}/ivectors_${data}_hires_voxceleb/ivector.scp \
#     exp/nnet3${nnet3_affix}/ivectors_${data}_hires_voxceleb/mean.vec || exit 1;
# done

# # Compute LDA to decrease the dimensionality
# lda_dim=200
# for data in ${train_set}_sp ${test_sets}; do
#   $train_cmd exp/nnet3/ivectors_${data}_hires_voxceleb/log/lda.log \
#     ivector-compute-lda --total-covariance-factor=0.0 --dim=$lda_dim \
#     "ark:ivector-subtract-global-mean scp:exp/nnet3/ivectors_${data}_hires_voxceleb/ivector.scp ark:- |" \
#     ark:data/${data}/utt2spk exp/nnet3/ivectors_${data}_hires_voxceleb/transform.mat || exit 1;
# done

# apply LDA and concatenate the i-vectors to features
for data in devel; do
  ivecdir=exp/nnet3/ivectors_${data}_hires_voxceleb
  # transform-feats \
  #   ${ivecdir}/transform.mat \
  #   scp:${ivecdir}/ivector.scp \
  #   ark,scp:${ivecdir}/ivector_lda.ark,${ivecdir}/ivector_lda.scp

  # old number of dimensions
  # feat-to-dim scp:${ivecdir}/ivector.scp -
  # new number of dimensions
  # feat-to-dim scp:${ivecdir}/ivector_lda.scp -

  # append-vector-to-feats \
  #   scp:data/${data}_hires_voxceleb/feats.scp \
  #   scp:${ivecdir}/ivector_lda.scp \
  #   ark,scp:data/${data}_hires_voxceleb/feats_ivec.ark,data/${data}_hires_voxceleb/feats_ivec.scp

  # convert matrix to vector
  # copy-matrix --binary=false scp:${ivecdir}/ivector_lda.scp ark,t:- | \
  #   copy-vector ark,t:- ark,scp:${ivecdir}/ivector_lda_vec.ark,${ivecdir}/ivector_lda_vec.scp

  # copy-matrix --binary=false scp:${ivecdir}/ivector_lda.scp ark,t:- | \
  #   copy-vector ark,t:- ark,scp:${ivecdir}/ivector_lda_converted.ark,${ivecdir}/ivector_lda_converted.scp

  # append-vector-to-feats \
  #   scp:data/${data}_hires_voxceleb/feats.scp \
  #   scp:${ivecdir}/ivector_lda_converted.scp \
  #   ark,scp:data/${data}_hires_voxceleb/feats_ivec.ark,data/${data}_hires_voxceleb/feats_ivec.scp
    
  paste-feats \
    scp:data/${data}_hires_voxceleb/feats.scp \
    scp:${ivecdir}/ivector_lda.scp \
    ark,scp:data/${data}_hires_voxceleb/feats_ivec.ark,data/${data}_hires_voxceleb/feats_ivec.scp

  # echo "dim:"
  # feat-to-dim scp:exp/nnet3/ivectors_devel_hires_voxceleb/ivector_lda_converted.scp -
done