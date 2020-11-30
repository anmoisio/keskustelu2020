#!/bin/bash -e
#SBATCH --partition batch
#SBATCH --time=4:00:00
#SBATCH --mem=38G

source ../../../scripts/run-expt.sh "${0}"

module purge
module load kaldi-2020/5968b4c-GCC-6.4.0-2.28-OPENBLAS
module list

. ./cmd.sh
. ./path.sh
. ./utils/parse_options.sh

dir=exp/chain/tdnn7q_sp_vcivecs_lda100

utils/lang/check_phones_compatible.sh \
    data/lang_chain/phones.txt \
    data/lang_test_word_fullvocab/phones.txt

utils/mkgraph.sh \
    --self-loop-scale 1.0 \
    data/lang_test_word_fullvocab \
    $dir \
    $dir/graph_word_fullvocab|| exit 1;


# 10GB mem
# utils/mkgraph.sh \
#     --self-loop-scale 1.0 \
#     data/lang_test_word \
#     exp/chain/tdnn7q_sp \
#     exp/chain/tdnn7q_sp/graph_word_smallvocab || exit 1;

# 104GB mem 3hours
# utils/mkgraph.sh \
#     --self-loop-scale 1.0 \
#     data/lang_test_word_fullvocab \
#     exp/chain/tdnn7q_sp_noivecs \
#     exp/chain/tdnn7q_sp_noivecs/graph_word_fullvocab || exit 1;

# utils/mkgraph.sh \
#     --self-loop-scale 1.0 \
#     data/lang_test_word_fullvocab \
#     $dir \
#     $dir/graph_word_fullvocab || exit 1;



# utils/mkgraph.sh \
#     --self-loop-scale 1.0 \
#     data/lang_test_morph_nosp \
#     $dir \
#     $dir/graph_morph_nosp || exit 1;

# utils/mkgraph.sh \
#     --self-loop-scale 1.0 \
#     data/lang_test_word_fullvocab \
#     $dir \
#     $dir/graph_word_fullvocab|| exit 1;