#!/bin/bash -e

source ../../../scripts/run-expt.sh "${0}"

module purge
module load kaldi-2020/5968b4c-GCC-6.4.0-2.28-OPENBLAS
module list

. ./cmd.sh
. ./path.sh
. ./utils/parse_options.sh

cd "${EXPT_SCRIPT_DIR}"

# --stage 6 for just scoring
steps/decode_fmllr.sh --nj 17 --cmd "$decode_cmd" \
    --stage 6 \
    exp/tri3b_mmi_b0.1/graph_word_trainvocab \
    data/devel \
    exp/tri3b_mmi_b0.1/decode_word_trainvocab_devel || exit 1;

