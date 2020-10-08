#!/bin/bash -e

source ../../../scripts/run-expt.sh "${0}"

module purge
module load kaldi-2020/5968b4c-GCC-6.4.0-2.28-OPENBLAS
module load sox
module list

. ./cmd.sh
. ./path.sh
. ./utils/parse_options.sh

cd "${EXPT_SCRIPT_DIR}"

for set_name in am-train
do
	data_dir="${EXPT_WORK_DIR}/data/${set_name}"
	echo "${data_dir}"
	mkdir -p "${data_dir}"

	cp "${PROJECT_DIR}/data/${set_name}/wav.scp" "${data_dir}/"
	cp "${PROJECT_DIR}/data/${set_name}/verbatim.ref" "${data_dir}/text"
	cp "${PROJECT_DIR}/data/${set_name}/spk2utt" "${data_dir}/"
	cp "${PROJECT_DIR}/data/${set_name}/utt2spk" "${data_dir}/"

	(set -x; steps/make_mfcc.sh --nj 20 --cmd "${train_cmd}" \
	  "${data_dir}" \
	  "${EXPT_WORK_DIR}/log/mfcc-${set_name}" \
	  "${EXPT_WORK_DIR}/mfcc")

	(set -x; steps/compute_cmvn_stats.sh \
	  "${data_dir}" \
	  "${EXPT_WORK_DIR}/log/mfcc-${set_name}" \
	  "${EXPT_WORK_DIR}/mfcc")
done
