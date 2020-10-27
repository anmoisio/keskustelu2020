#!/bin/bash -e

source ../../../scripts/run-expt.sh "${0}"

module purge
module load kaldi-2020/5968b4c-GCC-6.4.0-2.28-OPENBLAS
module list

. ./cmd.sh
. ./path.sh
. ./utils/parse_options.sh

cd "${EXPT_SCRIPT_DIR}"

decode_sets=eval

dir=exp/chain/tdnn7q_sp_dsp
for decode_set in $decode_sets; do
    steps/nnet3/decode.sh --nj 8 --cmd "$decode_cmd" \
        --acwt 1.0 \
        --post-decode-acwt 10.0 \
        --online-ivector-dir exp/nnet3/ivectors_${decode_set}_hires_spdsp \
        $dir/graph_word_fullvocab \
        data/${decode_set}_hires \
        $dir/decode_${decode_set}_word_fullvocab
done

dir=exp/chain/tdnn7q_sp_noivecs
for decode_set in $decode_sets; do
    steps/nnet3/decode.sh --nj 8 --cmd "$decode_cmd" \
        --acwt 1.0 \
        --post-decode-acwt 10.0 \
        $dir/graph_word_fullvocab \
        data/${decode_set}_hires \
        $dir/decode_${decode_set}_word_fullvocab
done

dir=exp/chain/tdnn7q_sp_psmitivecs
for decode_set in $decode_sets; do
    steps/nnet3/decode.sh --nj 8 --cmd "$decode_cmd" \
        --acwt 1.0 \
        --post-decode-acwt 10.0 \
        --online-ivector-dir exp/nnet3/ivectors_${decode_set}_hires_psmit \
        $dir/graph_word_fullvocab \
        data/${decode_set}_hires \
        $dir/decode_${decode_set}_word_fullvocab
done

dir=exp/chain/tdnn7q_sp_vcivecs_lda100
for decode_set in $decode_sets; do
    steps/nnet3/decode.sh --nj 8 --cmd "$decode_cmd" \
        --acwt 1.0 \
        --post-decode-acwt 10.0 \
        $dir/graph_word_fullvocab \
        exp/nnet3/ivectors_${decode_set}_hires_voxceleb/feat_dump_lda100 \
        $dir/decode_${decode_set}_word_fullvocab
done

dir=exp/chain/tdnn7q_sp_vcivecs_lda200
for decode_set in $decode_sets; do
    steps/nnet3/decode.sh --nj 8 --cmd "$decode_cmd" \
        --acwt 1.0 \
        --post-decode-acwt 10.0 \
        $dir/graph_word_fullvocab \
        exp/nnet3/ivectors_${decode_set}_hires_voxceleb/feat_dump_lda200 \
        $dir/decode_${decode_set}_word_fullvocab
done