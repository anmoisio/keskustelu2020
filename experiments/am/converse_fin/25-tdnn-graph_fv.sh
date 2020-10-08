#!/bin/bash -e
#SBATCH --partition batch
#SBATCH --time=12:00:00
#SBATCH --mem=104G

source ../../../scripts/run-expt.sh "${0}"

module purge
module load kaldi-2020/5968b4c-GCC-6.4.0-2.28-OPENBLAS
module list

. ./cmd.sh
. ./path.sh
. ./utils/parse_options.sh

# 10GB mem
# utils/mkgraph.sh \
#     --self-loop-scale 1.0 \
#     data/lang_test_word \
#     exp/chain/tdnn7q_sp \
#     exp/chain/tdnn7q_sp/graph_word_smallvocab || exit 1;

# 104GB mem 3hours
utils/mkgraph.sh \
    --self-loop-scale 1.0 \
    data/lang_test_word_fullvocab \
    exp/chain/tdnn7q_sp \
    exp/chain/tdnn7q_sp/graph_word_fullvocab || exit 1;
