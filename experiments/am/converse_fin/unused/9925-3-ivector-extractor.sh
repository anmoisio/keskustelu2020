#!/bin/bash

source ../../../scripts/run-expt.sh "${0}"

module purge
module load kaldi-vanilla
module list

. utils/parse_options.sh  # e.g. this parses the --stage option if supplied.
. path.sh

nj=30
train_set="am-train" # you might set this to e.g. train.
test_sets="devel eval"

nj_extractor=10
# It runs a JOB with '-pe smp N', where N=$[threads*processes]
num_processes_extractor=1
num_threads_extractor=1

nnet3_affix=    # affix for exp/nnet3 directory to put iVector stuff in (e.g.
                # in the tedlium recip it's _cleaned).

# Train the iVector extractor.  Use all of the speed-perturbed data since iVector extractors
# can be sensitive to the amount of data.  The script defaults to an iVector dimension of
# 100.
echo "$0: training the iVector extractor"
steps/online/nnet2/train_ivector_extractor.sh --cmd "$train_cmd" \
  --nj $nj_extractor \
  --num-threads $num_threads_extractor \
  --num-processes $num_processes_extractor \
  ../mmi/data/${train_set} \
  exp/diag_ubm \
  exp/extractor_enarvi || exit 1;

steps/online/nnet2/copy_data_dir.sh \
  --utts-per-spk-max 2 \
  ../mmi/data/${train_set} \
  data/am-train-2ups

steps/online/nnet2/extract_ivectors_online.sh --cmd "$train_cmd" --nj $nj \
  data/am-train-2ups \
  exp/extractor_enarvi \
  exp/ivectors_enarvi_train

# Also extract iVectors for the test data
for data in ${test_sets}; do
  steps/online/nnet2/extract_ivectors_online.sh --cmd "$train_cmd" --nj 1 \
    ../mmi/data/${data} \
    exp/extractor_enarvi \
    exp/ivectors_enarvi_${data}
done
