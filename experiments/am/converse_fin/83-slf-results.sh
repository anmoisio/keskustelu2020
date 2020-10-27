#!/bin/bash -e

source ../../../scripts/run-expt.sh "${0}"

module purge
module load sctk

results () {
    local test_set="${1}"
    local model_dir="${2}"

    "${PROJECT_SCRIPT_DIR}"/score.sh \
        ${test_set} \
        ${model_dir}/trn_${test_set}/lats-lms=*.trn \
        > ${model_dir}/results_${test_set}_word_fullvocab
}

results devel "exp/chain/tdnn7q_sp_psmitivecs"