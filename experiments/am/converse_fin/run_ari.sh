#!/bin/bash -e
#SBATCH --partition debug
#SBATCH --time=1:00:00
#SBATCH --mem=4G

source ../../../scripts/run-expt.sh "${0}"

. ./cmd.sh
. ./path.sh
. ./utils/parse_options.sh

module purge
module load kaldi-2020/5968b4c-GCC-6.4.0-2.28-OPENBLAS
module load anaconda3
module list

pip list

cd "${EXPT_SCRIPT_DIR}"

# pip install --user scikit-learn==0.22.0 spherecluster kaldi-io numpy

python3 local/compute_ari_with_embeddings.py \
    exp/nnet3_offline/ivectors_devel_hires/ivector.scp \
    data/devel_hires/utt2spk