#!/bin/bash -e
#
# parameter $1: the experiment script

export LC_ALL=C

read_expt_params () {
	EXPT_NAME=$(basename "$(dirname ${EXPT_SCRIPT_DIR})")
	EXPT_PARAMS="$(basename ${EXPT_SCRIPT_DIR})"
	EXPT_WORK_DIR="${WORK_DIR}/conv_lm/experiments/${EXPT_NAME}/${EXPT_PARAMS}"

	PROJECT_DIR="${WORK_DIR}/conv_lm"
	PROJECT_SCRIPT_DIR="${PROJECT_DIR}/scripts"
	RECTOOL_LNA_DIR="${PROJECT_DIR}/sanasto2016/lna"
	RESULTS_DIR="${PROJECT_DIR}/results/${EXPT_NAME}/${EXPT_PARAMS}"

	source "${EXPT_SCRIPT_DIR}/params.sh"
}

set -o pipefail

# if the given script file does not include '#SBATCH'
if ! grep -q '^#SBATCH' "${1}"
then
	EXPT_SCRIPT_FILE="$(readlink -f ${1})"
	EXPT_SCRIPT_DIR="$(dirname ${EXPT_SCRIPT_FILE})"
	read_expt_params
	JOB_TMP_DIR="${TMPDIR}/${$}"

elif [ -n "${SLURM_JOB_ID}" ] # if there is an existing slurm job ID 
then
	# $0 is a temporary file created by SLURM.

	EXPT_SCRIPT_DIR="${SLURM_SUBMIT_DIR}"
	read_expt_params
	JOB_TMP_DIR="${TMPDIR}/${SLURM_JOB_ID}"
	echo "Experiment: ${EXPT_NAME}/${EXPT_PARAMS}"
	echo "Job ID: ${SLURM_JOB_ID}"
	echo "Task ID: ${SLURM_ARRAY_TASK_ID}"
	echo "Host: $(hostname)"
	echo "Start date: $(date)"
	echo "Work directory: ${EXPT_WORK_DIR}"
	echo "Temporary directory: ${JOB_TMP_DIR}"
else
	echo "Submit sbatch"
	# the given script is a sbatch script

	EXPT_SCRIPT_FILE="$(readlink -f ${1})"
	EXPT_TASK="$(basename ${EXPT_SCRIPT_FILE})"
	EXPT_TASK="${EXPT_TASK#*[[:digit:]]-}"
	EXPT_TASK="${EXPT_TASK%.sh}"
	[ -n "${EXPT_TASK}" ] || { echo "run-expt.sh requires path to a launch script." >&2; exit 1; }

	EXPT_SCRIPT_DIR="$(dirname ${EXPT_SCRIPT_FILE})"
	read_expt_params
	# if [ -d /triton ]
	# then
	declare -a args
	mkdir -p "${EXPT_SCRIPT_DIR}/log"
	args=(--job-name="${EXPT_NAME}-${EXPT_TASK}-${EXPT_PARAMS}")
	args+=(-o "${EXPT_SCRIPT_DIR}/log/${EXPT_TASK}-%j.log")
	args+=(-e "${EXPT_SCRIPT_DIR}/log/${EXPT_TASK}-%j.log")
	[ -n "${SLURM_EXCLUDE_NODES}" ] && args+=(--exclude="${SLURM_EXCLUDE_NODES}")
	args+=("${EXPT_SCRIPT_FILE}")
	(set -x; sbatch "${args[@]}")
	exit 0
	# fi
fi
