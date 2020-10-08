#!/bin/bash
#SBATCH --time=12:00:00
#SBATCH --mem=24G

source ../../../scripts/run-expt.sh "${0}"

module purge
module load kaldi-2020/5968b4c-GCC-6.4.0-2.28-OPENBLAS
module list

. ./cmd.sh
. ./path.sh
. ./utils/parse_options.sh

cd "${EXPT_SCRIPT_DIR}"

utils/prepare_lang.sh \
    data/local/dict_fullvocab \
    "[oov]" \
    data/local/lang_tmp \
    data/lang_fullvocab || exit 1;


# create test (decoding) lang dir with silence and pron probs by copying files from 
# train lang dir w/ pron probs and decoding lang dir w/o probs
new=lang_test_word_fullvocab
train=lang_fullvocab
nosp=lang_test_word_fullvocab_nosp

mkdir -p data/$new
# copy everything from the lang dir w/o G.fst
cp -r data/$train/* data/$new || exit 1;
rm -rf data/$new/tmp
# copy G.fst from the lang dir w/o pron&silence probs
cp data/$nosp/G.* data/$new/