#!/bin/bash -e

source ../../../scripts/run-expt.sh "${0}"
source "${PROJECT_SCRIPT_DIR}/score-functions.sh"
source "${EXPT_SCRIPT_DIR}/params.sh"

module purge
module load speech-scripts
module load srilm
module load kaldi-vanilla
# module load cudnn
# module load libgpuarray
module load anaconda3
source activate /scratch/work/groszt1/envs/theanoLM
# declare -a DEVICES=(cuda0)
# RUN_GPU='srun --gres=gpu:1'
module list
DECODE_CMD="utils/slurm.pl --mem 16G --time 1:00:00"

n=50
lm_scale=10

steps/lmrescore_theanolm_nbest.sh --cmd "${DECODE_CMD}" \
    --N $n \
    --lm-scale $lm_scale \
    --stage 5 \
    /scratch/work/moisioa3/conv_lm/experiments/morph/srilm-5-gram/lang/train-nosp \
    nnlm.h5 \
    /scratch/work/moisioa3/conv_lm/experiments/morph/srilm-5-gram/models/tdnn/decode-devel \
    decode_nbest
