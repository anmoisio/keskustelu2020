#!/bin/bash -e
#SBATCH --partition batch
#SBATCH --time=1-00
#SBATCH --mem=53G

source ../../../scripts/run-expt.sh "${0}"

module purge
module load kaldi-2020/5968b4c-GCC-6.4.0-2.28-OPENBLAS
module list

. ./cmd.sh
. ./path.sh
. ./utils/parse_options.sh

# lang dir used for decoding
lang=data/lang_test_word

# check that train and decode phones are the same
utils/lang/check_phones_compatible.sh \
    data/lang/phones.txt \
    $lang/phones.txt

utils/mkgraph.sh \
    $lang \
    exp/tri3b_mmi_b0.1 \
    exp/tri3b_mmi_b0.1/graph_word_trainvocab