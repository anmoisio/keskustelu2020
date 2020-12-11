#!/bin/bash

module purge
module load sctk
module list

# . ./cmd.sh
. ./path.sh
# . ./utils/parse_options.sh


for test_set in eval
do
    for lms in 11
    do
        baseline_model=exp/chain/tdnn7q_sp_noivecs/trn_${test_set}_word_fullvocab/lats-lms=${lms}.trn
        # model=exp/chain/tdnn7q_sp/trn_${test_set}_word_fullvocab/lats-lms=11.trn

        ASR-significance-test/run_sign_tests.sh \
            /m/triton/scratch/work/moisioa3/keskustelu2020/data/${test_set}/normalized.trn \
            "${baseline_model}" \
            exp/chain/tdnn7q_sp_*/trn_${test_set}_word_fullvocab/lats-lms=${lms}.trn

        dst_dir=significance_noivecs_${test_set}_lms${lms}
        mkdir "${dst_dir}"
        mv significance_report.* "${dst_dir}"/
    done
done