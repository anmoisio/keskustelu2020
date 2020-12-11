#!/bin/bash -e
#SBATCH --time=4:00:00
#SBATCH --mem=12G
#SBATCH --gres=gpu:1
#SBATCH --array=0-127

source ../../../scripts/run-expt.sh "${0}"
source "${PROJECT_SCRIPT_DIR}/score-functions.sh"
source "${EXPT_SCRIPT_DIR}/params.sh"

module purge
module load speech-scripts
module load srilm
module load cudnn
module load libgpuarray
module load anaconda3
source activate /scratch/work/groszt1/envs/theanoLM
declare -a DEVICES=(cuda0)
RUN_GPU='srun --gres=gpu:1'

decode () {
	local test_set="${1}"
    local nnlm="${2}"
    local lattices_dir="${3}"

	local num_batches="128"
	local batch_index="${SLURM_ARRAY_TASK_ID}"

	for nnlm_weight in 0.5 1.0
	do
		for lm_scale in 10 11
		do
			decode_theanolm "${nnlm_weight}" "${lm_scale}" \
			                "${test_set}" \
			                "${num_batches}" "${batch_index}" \
                            "${nnlm}" "${lattices_dir}"
		done
	done
	echo "decode ${test_set} finished."
}

module list 

export EXPT_NAME=tdnn7q_sp_ensemble2
export EXPT_WORK_DIR="${WRKDIR}/keskustelu2020/experiments/am/converse_fin/exp/chain/${EXPT_NAME}"

lstm_dir=/scratch/work/moisioa3/conv_lm/experiments/theanolm-morph-42k/expt2-sampled-seq40
source ${lstm_dir}/params.sh

ngram_model=morph_nosp_4-gram
for test_set in devel eval
do
	decode $test_set ${lstm_dir}/nnlm.h5 \
            ${EXPT_WORK_DIR}/lattices_${test_set}_${ngram_model}.tar
done