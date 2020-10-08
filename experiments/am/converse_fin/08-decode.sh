#!/bin/bash -e

source ../../../scripts/run-expt.sh "${0}"

module purge
module load kaldi-2020/5968b4c-GCC-6.4.0-2.28-OPENBLAS
module list

. ./cmd.sh
. ./path.sh
. ./utils/parse_options.sh

cd "${EXPT_SCRIPT_DIR}"


steps/decode_fmllr.sh --nj 17 --cmd "$decode_cmd" \
    exp/tri3b/graph_word_trainvocab_nosp \
    data/devel \
    exp/tri3b/decode_word_trainvocab_nosp_devel1 || exit 1;

# steps/decode_fmllr.sh --nj 17 --cmd "$decode_cmd" \
#     exp/tri3b/graph_nosp \
#     data/eval \
#     exp/tri3b/decode_nosp_eval || exit 1;
