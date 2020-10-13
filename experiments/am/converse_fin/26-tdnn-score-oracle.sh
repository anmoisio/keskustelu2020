#!/bin/bash -e
#SBATCH --time=01:00:00  
#SBATCH --mem=4G

source ../../../scripts/run-expt.sh "${0}"

module purge
module load kaldi-2020/5968b4c-GCC-6.4.0-2.28-OPENBLAS
module list

. ./cmd.sh
. ./path.sh
. ./utils/parse_options.sh

cd "${EXPT_SCRIPT_DIR}"

decode_sets=devel

dir=exp/chain/tdnn7q_sp

# for decode_set in $decode_sets; do
#     steps/oracle_wer.sh --cmd "$decode_cmd" \
#         data/${decode_set}_hires \
#         data/lang_fullvocab \
#         $dir/decode_${decode_set}_word_fullvocab
# done

for decode_set in $decode_sets; do
    steps/oracle_wer.sh --cmd "$decode_cmd" \
        data/${decode_set}_hires \
        data/lang_fullvocab \
        $dir/decode_${decode_set}_morph_nosp
done
