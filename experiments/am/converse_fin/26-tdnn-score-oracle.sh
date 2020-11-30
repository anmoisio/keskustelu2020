#!/bin/bash -e
#SBATCH --time=04:00:00  
#SBATCH --mem=4G

source ../../../scripts/run-expt.sh "${0}"

module purge
module load kaldi-2020/5968b4c-GCC-6.4.0-2.28-OPENBLAS
module list

. ./cmd.sh
. ./path.sh
. ./utils/parse_options.sh

cd "${EXPT_SCRIPT_DIR}"

decode_sets="devel eval"

# dir=exp/chain/tdnn7q_sp

# for decode_set in $decode_sets; do
#     steps/oracle_wer.sh --cmd "$decode_cmd" \
#         data/${decode_set}_hires \
#         data/lang_fullvocab \
#         $dir/decode_${decode_set}_word_fullvocab
# done

# for decode_set in $decode_sets; do
#     steps/oracle_wer.sh --cmd "$decode_cmd" \
#         data/${decode_set}_hires \
#         data/lang_fullvocab \
#         $dir/decode_${decode_set}_morph_nosp
# done

# for model in exp/chain/tdnn7q_sp_*xvecs*
# do
#     for decode_set in $decode_sets; do
#     	if  ! [ -f ${model}/decode_${decode_set}_word_fullvocab/oracle_wer ] ; then
#             echo ${model}/decode__${decode_set}_word_fullvocab
#             steps/oracle_wer.sh --cmd "$decode_cmd" \
#                 data/${decode_set}_hires_voxceleb_xvec \
#                 data/lang_test_word_fullvocab \
#                 ${model}/decode_${decode_set}_word_fullvocab
#         fi
#     done
# done

for model in exp/chain/tdnn7q_sp_vcivecs_lda100
do
    for decode_set in $decode_sets; do
    	if  ! [ -f ${model}/decode_${decode_set}_word_fullvocab/oracle_wer ] ; then
            echo ${model}/decode_${decode_set}_word_fullvocab
            steps/oracle_wer.sh --cmd "$decode_cmd" \
                exp/nnet3/ivectors_${decode_set}_hires_voxceleb/feat_dump_lda100 \
                data/lang_test_word_fullvocab \
                ${model}/decode_${decode_set}_word_fullvocab
        fi
    done
done