#!/bin/bash -e
#SBATCH --time=1-00
#SBATCH --mem=53G

source ../../../scripts/run-expt.sh "${0}"
cd "${EXPT_SCRIPT_DIR}"

module purge
module load kaldi-2020/5968b4c-GCC-6.4.0-2.28-OPENBLAS
module list

. ./cmd.sh
. ./path.sh
. ./utils/parse_options.sh

# lang dir used for decoding
lang=data/lang_test_word_nosp

# AM
model=exp/tri3b

# check that train and decode phones are the same
utils/lang/check_phones_compatible.sh \
    data/lang_nosp/phones.txt \
    $lang/phones.txt

# compose decoding graph
utils/mkgraph.sh \
    ${lang} \
    ${model} \
    ${model}/graph_word_trainvocab_nosp