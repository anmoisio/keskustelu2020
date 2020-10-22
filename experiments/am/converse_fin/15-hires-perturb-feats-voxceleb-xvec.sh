#!/bin/bash

source ../../../scripts/run-expt.sh "${0}"

module purge
module load kaldi-2020/5968b4c-GCC-6.4.0-2.28-OPENBLAS
module load sox
module list

. ./cmd.sh
. ./path.sh
. ./utils/parse_options.sh

# print Kaldi repo version for logging
echo 'Kaldi version:'
git --no-pager --git-dir="${KALDI_ROOT}/.git/" log -n 1
echo

nj=8
train_set="am-train" 
test_sets="devel eval"

# high-resolution features using the MFCC configs that were
# used to train VoxCeleb x-vector extractor
# Note: different MFCCs are used for extracting x-vectors (these ones)
# and training/decoding the AM. Because we use pretrained VoxCeleb x-vec extractor,
# we need the MFCCs with matching parameters (0007_voxceleb_v2_1a/conf/mfcc.conf)
if [ -f data/${train_set}_hires_voxceleb_xvec/feats.scp ]; then
  echo "$0: data/${train_set}_sp_hires_voxceleb_xvec/feats.scp already exists."
  echo " ... Please either remove it, or rerun this script with stage > 2."
  exit 1
fi

echo "$0: creating high-resolution MFCC features with VoxCeleb x-vector config"

for datadir in ${train_set}_sp ${test_sets}; do
  utils/copy_data_dir.sh \
    data/$datadir \
    data/${datadir}_hires_voxceleb_xvec
done

# do volume-perturbation on the training data prior to extracting hires
# features; this helps make trained nnets more invariant to test data volume.
utils/data/perturb_data_dir_volume.sh \
  data/${train_set}_sp_hires_voxceleb_xvec

for datadir in ${train_set}_sp ${test_sets}; do
  steps/make_mfcc.sh --write-utt2num-frames true \
    --mfcc-config 0007_voxceleb_v2_1a/conf/mfcc.conf \
    --nj $nj --cmd "$train_cmd" \
    data/${datadir}_hires_voxceleb_xvec

  utils/fix_data_dir.sh \
    data/${datadir}_hires_voxceleb_xvec

  sid/compute_vad_decision.sh --nj $nj --cmd "$train_cmd" \
    --vad-config 0007_voxceleb_v2_1a/conf/vad.conf \
    data/${datadir}_hires_voxceleb_xvec \
    data/make_vad_xvec 

  utils/fix_data_dir.sh \
    data/${datadir}_hires_voxceleb_xvec
done
