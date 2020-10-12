#!/bin/bash -e
# SBATCH --partition batch
# SBATCH --time=4:00:00
# SBATCH --mem=12G

source ../../../scripts/run-expt.sh "${0}"
source "${PROJECT_SCRIPT_DIR}/train-functions.sh"
source "${EXPT_SCRIPT_DIR}/params.sh"

# module purge
# module load variKN
# module load anaconda3
# module load srilm
# module list

train_varikn_ip
