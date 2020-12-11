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

dir=exp/chain/tdnn7q_sp_noivecs/decode_lahjoitapuhetta_noivecs_word_fullvocab
# nnet3_affix=_ensemble

align-text ark:${dir}/scoring_kaldi/test_filt.txt \
    ark:${dir}/scoring_kaldi/penalty_0.0/11.txt ark,t:-  | \
    utils/scoring/wer_per_utt_details.pl  \
    > ${dir}/scoring_kaldi/wer_per_utt