#!/bin/bash -e

source ../../../scripts/run-expt.sh "${0}"

module purge
module load kaldi-2020/5968b4c-GCC-6.4.0-2.28-OPENBLAS
module list

. ./cmd.sh
. ./path.sh
. ./utils/parse_options.sh

n=50
lmwt=12

nbest () {
    local test_set="${1}"
    local graph_dir="${2}"
    local decode_dir="${3}"
    local out_dir="${4}"

    kaldi-utensils/cutlery/get_nbest.sh --cmd "${score_cmd}" \
        --num_best ${n} \
        --LMWT ${lmwt} \
        "${graph_dir}" \
        "${decode_dir}" \
        "${out_dir}"
}

model=exp/chain/tdnn7q_sp_ensemble2

for decode_set in devel eval
do
    for lm in _morph_nosp_4-gram
    do
        nbest ${decode_set} \
            ${model}/graph${lm} \
            ${model}/decode_${decode_set}${lm} \
            ${model}/${n}best_${decode_set}${lm}
    done
done
