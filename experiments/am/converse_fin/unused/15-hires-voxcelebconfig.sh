#!/bin/bash

source ../../../scripts/run-expt.sh "${0}"

module purge
module load kaldi-vanilla
module load sox
module list

export PATH="${UTILS_DIR}:${PATH}"

. ./cmd.sh
. ./path.sh
. ./utils/parse_options.sh

echo $PATH

# print Kaldi repo version for logging
echo 'Kaldi version:'
git --no-pager --git-dir="${KALDI_ROOT}/.git/" log -n 1
echo

nj=8
train_set="am-train" 
test_sets="devel eval"

# high-resolution features using the MFCC configs that were
# used to train VoxCeleb i-vector extractor
if [ -f data/${train_set}_hires_voxceleb/feats.scp ]; then
  echo "$0: data/${train_set}_sp_hires_voxceleb/feats.scp already exists."
  echo " ... Please either remove it, or rerun this script with stage > 2."
  exit 1
fi

echo "$0: creating high-resolution MFCC features"
for setname in ${train_set} ${test_sets}; do
  
	data_dir=data/${setname}_hires_voxceleb
	echo "${data_dir}"
	mkdir -p "${data_dir}"

	cp "${PROJECT_DIR}/data/${setname}/wav.scp" "${data_dir}/"
	cp "${PROJECT_DIR}/data/${setname}/verbatim.ref" "${data_dir}/text"
	cp "${PROJECT_DIR}/data/${setname}/spk2utt" "${data_dir}/"
	cp "${PROJECT_DIR}/data/${setname}/utt2spk" "${data_dir}/"

  steps/make_mfcc.sh --write-utt2num-frames true \
    --mfcc-config 0007_voxceleb_v1_1a/conf/mfcc.conf \
    --nj $nj --cmd "$train_cmd" \
    ${data_dir}

  utils/fix_data_dir.sh \
    data/${setname}

  sid/compute_vad_decision.sh \
    --nj $nj --cmd "$train_cmd" \
    --vad-config 0007_voxceleb_v1_1a/conf/vad.conf \
    data/${setname} \
    exp/make_vad \
    ${data_dir}

  utils/fix_data_dir.sh \
    data/${setname}
done