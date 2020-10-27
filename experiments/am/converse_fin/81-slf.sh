#!/bin/bash -e

source ../../../scripts/run-expt.sh "${0}"

module purge
module load kaldi-2020/5968b4c-GCC-6.4.0-2.28-OPENBLAS
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

convert devel "exp/chain/tdnn7q_sp_psmitivecs"
