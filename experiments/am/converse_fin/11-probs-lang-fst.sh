#!/bin/bash

source ../../../scripts/run-expt.sh "${0}"

. ./cmd.sh
. ./path.sh
. ./utils/parse_options.sh

cd "${EXPT_SCRIPT_DIR}"

# create test (decoding) lang dir with silence and pron probs by copying files from 
# train lang dir w/ pron probs and decoding lang dir w/o probs
mkdir -p data/lang_test_word
cp -r data/lang/* data/lang_test_word || exit 1;
rm -rf data/lang_test_word/tmp
cp data/lang_test_word_nosp/G.* data/lang_test_word/