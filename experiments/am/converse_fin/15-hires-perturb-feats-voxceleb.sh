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
# used to train VoxCeleb i-vector extractor
if [ -f data/${train_set}_hires_voxceleb/feats.scp ]; then
  echo "$0: data/${train_set}_sp_hires_voxceleb/feats.scp already exists."
  echo " ... Please either remove it, or rerun this script with stage > 2."
  exit 1
fi

echo "$0: creating high-resolution MFCC features with VoxCeleb config"

for datadir in ${train_set}_sp ${test_sets}; do
  utils/copy_data_dir.sh \
    data/$datadir \
    data/${datadir}_hires_voxceleb
done

# do volume-perturbation on the training data prior to extracting hires
# features; this helps make trained nnets more invariant to test data volume.
utils/data/perturb_data_dir_volume.sh \
  data/${train_set}_sp_hires_voxceleb

for datadir in ${train_set}_sp ${test_sets}; do
  steps/make_mfcc.sh --write-utt2num-frames true \
    --mfcc-config 0007_voxceleb_v1_1a/conf/mfcc.conf \
    --nj $nj --cmd "$train_cmd" \
    data/${datadir}_hires_voxceleb

  utils/fix_data_dir.sh \
    data/${datadir}_hires_voxceleb
done
