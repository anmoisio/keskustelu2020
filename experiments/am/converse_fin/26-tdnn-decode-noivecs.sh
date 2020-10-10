#!/bin/bash -e

source ../../../scripts/run-expt.sh "${0}"

module purge
module load kaldi-2020/5968b4c-GCC-6.4.0-2.28-OPENBLAS
module list

. ./cmd.sh
. ./path.sh
. ./utils/parse_options.sh

cd "${EXPT_SCRIPT_DIR}"

decode_sets=devel

dir=exp/chain/tdnn7q_sp_noivecs

# --stage 3 for just scoring
for decode_set in $decode_sets; do
    steps/nnet3/decode.sh --nj 8 --cmd "$decode_cmd" \
        --acwt 1.0 \
        --post-decode-acwt 10.0 \
        $dir/graph_word_fullvocab \
        data/${decode_set}_hires \
        $dir/decode_${decode_set}_word_fullvocab
done