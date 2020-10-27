#!/bin/bash -e
#SBATCH --partition batch
#SBATCH --time=2:00:00
#SBATCH --mem=7G

source ../../../scripts/run-expt.sh "${0}"
source "${PROJECT_SCRIPT_DIR}/score-functions.sh"

module purge
module load speech-scripts
module load srilm

decode () {
	local test_set="${1}"
	local model_dir="${2}"

	local lattices_file=$model_dir/lattices_${test_set}_word_fullvocab/lattice-list

	local trn_dir=${model_dir}/trn_${test_set}
	mkdir -p "${trn_dir}"

	lm=/scratch/work/moisioa3/conv_lm/experiments/4gram/ip/kn-ip-dsp-web.arpa.gz

	for lm_scale in {8..12}
	do
		export DECODE_LATTICES_LM1="${lm}"
		export DECODE_LATTICES_LM_SCALE="${lm_scale}"
		export DECODE_LATTICES_ORDER="4"

		trn_file="${trn_dir}/lats-lms=${lm_scale}.trn"
		decode-lattices.sh "${lattices_file}" >"${trn_file}"
		echo "Wrote ${trn_file}."
	done
}

decode devel "exp/chain/tdnn7q_sp_psmitivecs"
