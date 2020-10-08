#!/bin/bash -e
#SBATCH --time=2:00:00
#SBATCH --mem=12G

source ../../../scripts/run-expt.sh "${0}"

module purge
module load kaldi-2020/5968b4c-GCC-6.4.0-2.28-OPENBLAS
module list

. ./cmd.sh
. ./path.sh
. ./utils/parse_options.sh

# fullvocab lang dir
lang=lang_fullvocab_nosp

utils/prepare_lang.sh \
  data/local/dict_fullvocab_nosp \
  "[oov]" \
  data/local/lang_tmp_fv_nosp \
  data/$lang
