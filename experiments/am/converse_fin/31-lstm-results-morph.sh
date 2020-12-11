#!/bin/bash -e

source ../../../scripts/run-expt.sh "${0}"
source "${PROJECT_SCRIPT_DIR}/score-functions.sh"

module purge
module load sctk
module list

export EXPT_NAME=tdnn7q_sp_ensemble2
export EXPT_WORK_DIR="${WRKDIR}/keskustelu2020/experiments/am/converse_fin/exp/chain/${EXPT_NAME}"
export RESULTS_DIR="${EXPT_WORK_DIR}/results-morph-4-gram"

lstm_dir=/scratch/work/moisioa3/conv_lm/experiments/theanolm-morph-42k/expt2-sampled-seq40
source ${lstm_dir}/params.sh

decode_params="tpn=62-beam=650-order=22"
ngram=_morph_nosp_4-gram

for test_set in eval devel
do
	# echo "${test_set}"
	# collect_transcripts "${test_set}" "decode-lstm-lattices_${test_set}${ngram}"

	# for filename in "${RESULTS_DIR}-lats-${decode_params}/${test_set}"/lambda=???-lms=??.trn
	# do
	#     echo combine segmented text in "${filename}" write to "${filename%.trn}"-combined.trn
	#     "${PROJECT_SCRIPT_DIR}"/combine.py --input-trn "${filename}" --output-trn "${filename%.trn}"-combined.trn
	# done

    "${PROJECT_SCRIPT_DIR}"/score.sh ${test_set} \
        "${RESULTS_DIR}-lats-${decode_params}/${test_set}"/lambda=*-lms=*.trn \
        > ${EXPT_WORK_DIR}/results-${test_set}-rescored-lstmseq40-morph.txt
done


