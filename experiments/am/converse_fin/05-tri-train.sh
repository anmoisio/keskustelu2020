#!/bin/bash

source ../../../scripts/run-expt.sh "${0}"

module purge
module load kaldi-2020/5968b4c-GCC-6.4.0-2.28-OPENBLAS
module list

. ./cmd.sh
. ./path.sh
. ./utils/parse_options.sh


# tri1
# Take a subset of 4000 utterances.
utils/subset_data_dir.sh \
  data/am-train \
  4000 \
  data/am-train-4k

# align speaker-independent model
steps/align_si.sh --nj 10 --cmd "$train_cmd" \
  data/am-train-4k \
  data/lang_nosp \
  exp/mono0 \
  exp/mono0_ali || exit 1;

# deltas
steps/train_deltas.sh --cmd "$train_cmd" \
  2000 10000 \
  data/am-train-4k \
  data/lang_nosp \
  exp/mono0_ali \
  exp/tri1 || exit 1;


# tri2
# Take a subset of 8000 utterances.
utils/subset_data_dir.sh \
  data/am-train \
  8000 \
  data/am-train-8k

steps/align_si.sh --nj 10 --cmd "$train_cmd" \
  data/am-train-8k \
  data/lang_nosp \
  exp/tri1 \
  exp/tri1_ali || exit 1;

steps/train_lda_mllt.sh --cmd "$train_cmd" \
  --splice-opts "--left-context=3 --right-context=3" \
  2500 15000 \
  data/am-train-8k \
  data/lang_nosp \
  exp/tri1_ali \
  exp/tri2b || exit 1;

# tri3
# this one is different from WSJ example
steps/align_fmllr.sh  --nj 10 --cmd "$train_cmd" \
  data/am-train \
  data/lang_nosp \
  exp/tri2b \
  exp/tri2b_ali  || exit 1; 

steps/train_sat.sh --cmd "$train_cmd" \
  4200 40000 \
  data/am-train \
  data/lang_nosp \
  exp/tri2b_ali \
  exp/tri3b || exit 1;
