#!/bin/bash
#SBATCH --time=0:30:00
#SBATCH --mem=4G

# Estimate pronunciation and silence probabilities.

source ../../../scripts/run-expt.sh "${0}"

module purge
module load kaldi-2020/5968b4c-GCC-6.4.0-2.28-OPENBLAS
module list

. ./cmd.sh
. ./path.sh
. ./utils/parse_options.sh

cd "${EXPT_SCRIPT_DIR}"

# for this to work, ther should be lattices or alignments

decode_dir=exp/chain/tdnn7q_sp/decode_devel_morph_nosp
# Silprob for normal lexicon.
steps/get_prons.sh --cmd "$train_cmd" \
    data/am-train \
    data/lang_test_morph_nosp \
    $decode_dir || exit 1;

utils/dict_dir_add_pronprobs.sh \
    --max-normalize true \
    data/local/dict_morph_nosp \
    $decode_dir/pron_counts.txt \
    $decode_dir/sil_counts.txt \
    $decode_dir/pron_bigram_counts.txt \
    data/local/dict_morph || exit 1
