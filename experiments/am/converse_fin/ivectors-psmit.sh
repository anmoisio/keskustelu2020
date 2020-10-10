#!/bin/bash

source ../../../scripts/run-expt.sh "${0}"

module purge
module load kaldi-2020/5968b4c-GCC-6.4.0-2.28-OPENBLAS
module list

. ./cmd.sh
. ./path.sh
. ./utils/parse_options.sh

nj=10
train_set="am-train" # you might set this to e.g. train.
test_sets="devel eval"

# note, we don't encode the 'max2' in the name of the ivectordir even though
# that's the data we extract the ivectors from, as it's still going to be
# valid for the non-'max2' data; the utterance list is the same.
ivectordir=exp/nnet3${nnet3_affix}/ivectors_${train_set}_sp_hires_psmit

# We now extract iVectors on the speed-perturbed training data .  With
# --utts-per-spk-max 2, the script pairs the utterances into twos, and treats
# each of these pairs as one speaker; this gives more diversity in iVectors..
# Note that these are extracted 'online' (they vary within the utterance).

extractor_dir=extractor_psmit
steps/online/nnet2/extract_ivectors_online.sh --cmd "$train_cmd" --nj $nj \
  exp/nnet3/ivectors_am-train_sp_hires/am-train_sp_hires_max2 \
  ${extractor_dir} \
  $ivectordir

# Also extract iVectors for the test data, but in this case we don't need the speed
# perturbation (sp).
# for data in ${test_sets}; do
#   nspk=$(wc -l <data/${data}_hires/spk2utt)
#   steps/online/nnet2/extract_ivectors_online.sh --cmd "$train_cmd" --nj 1 \
#       data/${data}_hires \
#       ${extractor_dir} \
#       exp/nnet3${nnet3_affix}/ivectors_${data}_hires_psmit
# done
