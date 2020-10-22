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
xvec_suffix=_hires_voxceleb_vad

# # note, we don't encode the 'max2' in the name of the ivectordir even though
# # that's the data we extract the ivectors from, as it's still going to be
# # valid for the non-'max2' data; the utterance list is the same.
xvectordir=exp/nnet3${nnet3_affix}/xvectors_${train_set}_sp${xvec_suffix}

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

# sid/compute_vad_decision.sh --nj $nj --cmd "$train_cmd" \
#   --vad-config 0007_voxceleb_v1_1a/conf/vad.conf \
#   data/${train_set}_sp_hires_voxceleb \
#   data/${train_set}_sp_hires_voxceleb \
#   data/${train_set}_sp_hires_voxceleb
  

extractor_dir=0007_voxceleb_v2_1a/exp/xvector_nnet_1a
# sid/nnet3/xvector/extract_xvectors.sh --cmd "$train_cmd" --nj 50 \
#   ${extractor_dir} \
#   data/${train_set}_sp_hires_voxceleb_xvec \
#   $xvectordir

# Also extract iVectors for the test data, but in this case we don't need the speed
# perturbation (sp).
# for data in ${test_sets}; do
#   # nspk=$(wc -l <data/${data}_hires/spk2utt) # nj can't be larger than number of spks
#   sid/nnet3/xvector/extract_xvectors.sh --cmd "$train_cmd" --nj 17 \
#     ${extractor_dir} \
#     data/${data}_hires_voxceleb_xvec \
#     exp/nnet3/xvectors_${data}${xvec_suffix}
# done

# Compute the mean vector of the training set x-vectors
# for centering the evaluation x-vectors.
# $train_cmd exp/xvectors_train/log/compute_mean.log \
#   ivector-mean scp:exp/nnet3/xvectors_${train_set}_sp${xvec_suffix}/xvector.scp \
#   exp/nnet3/xvectors_${train_set}_sp${xvec_suffix}/mean.vec || exit 1;

# Compute LDA to decrease the dimensionality
lda_dim=200
# $train_cmd exp/nnet3/xvectors_${train_set}_sp${xvec_suffix}/log/lda$lda_dim.log \
#   ivector-compute-lda --total-covariance-factor=0.0 --dim=$lda_dim \
#   "ark:ivector-subtract-global-mean scp:exp/nnet3/xvectors_${train_set}_sp${xvec_suffix}/xvector.scp ark:- |" \
#   ark:data/${train_set}_sp/utt2spk exp/nnet3/xvectors_${train_set}_sp${xvec_suffix}/lda$lda_dim.mat || exit 1;

for data in ${test_sets} ; do
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
