#!/bin/bash -e
#SBATCH --partition batch
#SBATCH --time=2:00:00
#SBATCH --mem=7G

source ../../../scripts/run-expt.sh "${0}"
source "${PROJECT_SCRIPT_DIR}/score-functions.sh"


module purge
module load kaldi-2020/5968b4c-GCC-6.4.0-2.28-OPENBLAS
module load speech-scripts
module load srilm
module load sctk
module list

. ./cmd.sh
. ./path.sh
. ./utils/parse_options.sh

convert () {
	local test_set="${1}"
	local model_dir="${2}"

	local src_dir=$model_dir/decode_${test_set}_word_fullvocab
	local dst_dir=$model_dir/lattices_${test_set}_word_fullvocab

	local/convert_slf_parallel.sh --cmd "${decode_cmd}" \
	  data/${test_set} \
	  data/lang_test_word_fullvocab \
	  "${src_dir}"

	rm -rf "${dst_dir}"
	mv "${src_dir}/lats-in-htk-slf" "${dst_dir}"
	mv "${dst_dir}/lat_htk.scp" "${dst_dir}/lattice-list"
	sed -i "s:${src_dir}/lats-in-htk-slf:${dst_dir}:" "${dst_dir}/lattice-list"
	echo "Wrote ${dst_dir}/lattice-list."
}

decode () {
	local test_set="${1}"
	local model_dir="${2}"

	local lattices_file=$model_dir/lattices_${test_set}_word_fullvocab/lattice-list

	local trn_dir=${model_dir}/trn_${test_set}_word_fullvocab
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

results () {
    local test_set="${1}"
    local model_dir="${2}"

    "${PROJECT_SCRIPT_DIR}"/score.sh \
        ${test_set} \
        ${model_dir}/trn_${test_set}_word_fullvocab/lats-lms=*.trn \
        > ${model_dir}/results_${test_set}_word_fullvocab
}

# model=exp/chain/tdnn7q_sp_xvecs_lda200_vad
decode_set=eval

# for model in exp/chain/tdnn7q_sp{,_dsp,_noivecs,_vc*,_xvecs*}
for model in exp/chain/tdnn7q_sp
do
    convert ${decode_set} $model
    decode ${decode_set} $model
    results ${decode_set} $model
done