#!/bin/bash

source ../../../scripts/run-expt.sh "${0}"

module purge
module load kaldi-vanilla
module list

. utils/parse_options.sh  # e.g. this parses the --stage option if supplied.

cd "${EXPT_SCRIPT_DIR}"
  
steps/align_fmllr.sh --nj 30 --cmd "${train_cmd}" \
  ../mmi/data/am-train \
  data/lang \
  exp/tri3b_mmi_b0.1 \
  exp/tri3b_mmi_b0.1_ali_hires
  # fail