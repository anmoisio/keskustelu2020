#!/bin/bash -e
#SBATCH --time=0:30:00
#SBATCH --mem=4G

source ../../../scripts/run-expt.sh "${0}"

module purge
module load kaldi-2020/5968b4c-GCC-6.4.0-2.28-OPENBLAS
module list

# print Kaldi repo version for logging
echo 'Kaldi version:'
git --no-pager --git-dir=${KALDI_ROOT}/.git/ log -n 1
echo

. ./cmd.sh
. ./path.sh
. ./utils/parse_options.sh

# training lang dir
lang=lang_nosp

utils/prepare_lang.sh data/local/dict_nosp \
  "[oov]" \
  data/local/lang_tmp_nosp \
  data/$lang
