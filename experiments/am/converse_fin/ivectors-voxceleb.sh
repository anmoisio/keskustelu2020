#!/bin/bash

#  KALDI VERSION   447e964

source ../../../scripts/run-expt.sh "${0}"

module purge
module load kaldi-2020
module list

# print Kaldi repo version for logging
echo 'Kaldi version:'
git --no-pager --git-dir="${KALDI_ROOT}/.git/" log -n 1 --pretty=oneline 
echo

. ./cmd.sh
. ./path.sh
. ./utils/parse_options.sh

nj=10
train_set="am-train" # you might set this to e.g. train.
test_sets="devel eval"

# note, we don't encode the 'max2' in the name of the ivectordir even though
# that's the data we extract the ivectors from, as it's still going to be
# valid for the non-'max2' data; the utterance list is the same.
ivectordir=exp/nnet3${nnet3_affix}/ivectors_${train_set}_sp_hires_voxceleb 

# We now extract iVectors on the speed-perturbed training data .  With
# --utts-per-spk-max 2, the script pairs the utterances into twos, and treats
# each of these pairs as one speaker; this gives more diversity in iVectors..
# Note that these are extracted 'online' (they vary within the utterance).

# Having a larger number of speakers is helpful for generalization, and to
# handle per-utterance decoding well (the iVector starts at zero at the beginning
# of each pseudo-speaker).
# temp_data_root=${ivectordir}
# utils/data/modify_speaker_info.sh \
#   --utts-per-spk-max 2 \
#   data/${train_set}_sp_hires_voxceleb  \
#   ${temp_data_root}/${train_set}_sp_hires_max2

extractor_dir=0007_voxceleb_v1_1a/exp/extractor 
sid/extract_ivectors.sh --cmd "$train_cmd" --nj $nj \
  ${extractor_dir} \
  data/${train_set}_sp_hires_voxceleb  \
  $ivectordir

# Also extract iVectors for the test data, but in this case we don't need the speed
# perturbation (sp).
for data in ${test_sets}; do
  nspk=$(wc -l <data/${data}_hires/spk2utt)
  sid/extract_ivectors.sh --cmd "$train_cmd" --nj 1 \
      ${extractor_dir} \
      data/${data}_hires_voxceleb  \
      exp/nnet3${nnet3_affix}/ivectors_${data}_hires_voxceleb 
done
