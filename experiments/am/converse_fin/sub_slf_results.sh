#!/bin/bash -e
# SBATCH --partition batch
# SBATCH --time=2:00:00
# SBATCH --mem=4G

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
	local decode_suffix="${3}"
	# local data_dir="${4}"

	local src_dir=$model_dir/decode_${test_set}${decode_suffix}
	local dst_dir=$model_dir/lattices_${test_set}${decode_suffix}

	local/convert_slf_parallel.sh --cmd "${decode_cmd}" \
	  data/${test_set} \
	  data/lang_test${decode_suffix} \
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
	local decode_suffix="${3}"
	lm="${4}"

	local lattices_file=$model_dir/lattices_${test_set}${decode_suffix}/lattice-list

	local trn_dir=${model_dir}/trn_${test_set}${decode_suffix}
	mkdir -p "${trn_dir}"

	# lm=/scratch/work/moisioa3/conv_lm/experiments/4gram/ip/kn-ip-dsp-web.arpa.gz

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
	local decode_suffix="${3}"

	for filename in ${model_dir}/trn_${test_set}${decode_suffix}/lats-lms=*.trn
	do
		echo combine segmented text in "${filename}" write to "${filename%.trn}"-combined.trn
		"${PROJECT_SCRIPT_DIR}"/combine.py --input-trn "${filename}" --output-trn "${filename%.trn}"-combined.trn
	done

    "${PROJECT_SCRIPT_DIR}"/score.sh \
        ${test_set} \
        ${model_dir}/trn_${test_set}${decode_suffix}/lats-lms=*-combined.trn \
        > ${model_dir}/results_${test_set}${decode_suffix}
}


# for decode_set in eval
# do
# 	for model in exp/chain/tdnn7q_sp_ensemble2
# 	do
# 		# for suffix in _morph_nosp_{3-gram,4-gram,5-gram,"D=0.001-D2=0.002-cutoffs00"}
# 		for suffix in _morph_nosp_{3,4,5}-gram
# 		do
# 			if  ! [ -d ${model}/lattices_${decode_set}"${suffix}" ] 2> /dev/null && [ -d ${model}/decode_${decode_set}"${suffix}" ] ; then
# 				echo ${decode_set} $model "${suffix}"
# 				convert ${decode_set} $model "${suffix}"
# 			fi
# 		done
# 	done
# done

model=exp/chain/tdnn7q_sp_ensemble2
# for decode_set in devel eval
# do
# 	for n in 5
# 	do
# 		decode ${decode_set} ${model} "_morph_nosp_${n}-gram" "data/morph_lm_${n}-gram/kn-ip-dsp-web.arpa.gz"
# 	done
# done 

# for decode_set in devel eval
# do
# 	decode ${decode_set} ${model} "_morph_nosp_D=0.001-D2=0.002-cutoffs001" "data/morph_lm_D=0.001-D2=0.002-cutoffs001/kn.arpa.gz"
# done 

# for decode_set in devel eval
# do
# 	for suffix in _morph_nosp_{3-gram,4-gram,5-gram}
# 	do
# 		results ${decode_set} ${model} "${suffix}" 
# 	done
# done 

for decode_set in devel eval
do
	for suffix in "_morph_nosp_D=0.001-D2=0.002-cutoffs001"
	do
		results ${decode_set} ${model} "${suffix}" 
	done
done 