#!/bin/bash -e

source ../../../scripts/run-expt.sh "${0}"

module purge
module load kaldi-2020/5968b4c-GCC-6.4.0-2.28-OPENBLAS
module list

. ./cmd.sh
. ./path.sh
. ./utils/parse_options.sh

cd "${EXPT_SCRIPT_DIR}"

# decode_sets="devel eval"

dir=exp/chain/tdnn7q_sp_noivecs
# nnet3_affix=_ensemble

steps/nnet3/decode.sh --nj 8 --cmd "$decode_cmd" \
    --acwt 1.0 \
    --post-decode-acwt 10.0 \
    --stage 3 \
    $dir/graph_word_fullvocab \
    data/lahjoitapuhetta-untranscribed \
    $dir/decode_lahjoitapuhetta-untranscribed_noivecs_word_fullvocab

# for n in 4
# do
#     for decode_set in eval; do
#         steps/nnet3/decode.sh --nj 17 --cmd "$decode_cmd" \
#             --acwt 1.0 \
#             --post-decode-acwt 10.0 \
#             $dir/graph_morph_nosp_${n}-gram \
#             exp/nnet3${nnet3_affix}/xvectors_${decode_set}_hires_voxceleb_vad/feat_dump_lda100_vad \
#             $dir/decode_${decode_set}_morph_nosp_${n}-gram_nj17
#     done
# done

# for decode_set in eval; do
#     steps/nnet3/decode.sh --nj 17 --cmd "$decode_cmd" \
#         --acwt 1.0 \
#         --post-decode-acwt 10.0 \
#         $dir/graph_word_fullvocab \
#         exp/nnet3${nnet3_affix}/xvectors_${decode_set}_hires_voxceleb_vad/feat_dump_lda100_vad \
#         $dir/decode_${decode_set}_word_fullvocab_nj17
# done
# for decode_set in devel; do
#     steps/nnet3/decode.sh --nj 30 --cmd "$decode_cmd" \
#         --acwt 1.0 \
#         --post-decode-acwt 10.0 \
#         $dir/graph_word_fullvocab \
#         exp/nnet3${nnet3_affix}/xvectors_${decode_set}_hires_voxceleb_vad/feat_dump_lda100_vad \
#         $dir/decode_${decode_set}_word_fullvocab_nj30
# done

# dir=exp/chain/tdnn7q_sp_ensemble_conv
# nnet3_affix=_ensemble_conv
# for decode_set in $decode_sets; do
#     steps/nnet3/decode.sh --nj 8 --cmd "$decode_cmd" \
#         --acwt 1.0 \
#         --post-decode-acwt 10.0 \
#         $dir/graph_word_fullvocab \
#         exp/nnet3${nnet3_affix}/xvectors_${decode_set}_hires_conv/feat_dump_lda100_vad \
#         $dir/decode_${decode_set}_word_fullvocab
# done

# dir=exp/chain/tdnn7q_sp_vcxvecs_lda200_vad
# for decode_set in $decode_sets; do
#     steps/nnet3/decode.sh --nj 8 --cmd "$decode_cmd" \
#         --acwt 1.0 \
#         --post-decode-acwt 10.0 \
#         $dir/graph_word_fullvocab \
#         exp/nnet3${nnet3_affix}/xvectors_${decode_set}_hires_voxceleb_vad/feat_dump_lda200_vad \
#         $dir/decode_${decode_set}_word_fullvocab
# done