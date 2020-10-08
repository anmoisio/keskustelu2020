#!/bin/bash
#SBATCH --time=1:00:00
#SBATCH --mem=10G

source ../../../scripts/run-expt.sh "${0}"

module purge
module load kaldi-2020/5968b4c-GCC-6.4.0-2.28-OPENBLAS
module list

. ./cmd.sh
. ./path.sh
. ./utils/parse_options.sh

cd "${EXPT_SCRIPT_DIR}"

utils/prepare_lang.sh \
    data/local/dict \
    "[oov]" \
    data/local/lang_tmp \
    data/lang || exit 1;