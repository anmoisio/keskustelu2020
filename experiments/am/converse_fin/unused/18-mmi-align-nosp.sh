#!/bin/bash

source ../../../scripts/run-expt.sh "${0}"

module purge
module load kaldi-2020/5968b4c-GCC-6.4.0-2.28-OPENBLAS
module list

. ./cmd.sh
. ./path.sh
. ./utils/parse_options.sh

cd "${EXPT_SCRIPT_DIR}"
  
steps/align_fmllr.sh --nj 30 --cmd "${train_cmd}" \
  data/am-train \
  data/lang \
  exp/tri3b_mmi_b0.1 \
  exp/tri3b_mmi_b0.1_ali