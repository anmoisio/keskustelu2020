#!/bin/bash

source ../../../scripts/run-expt.sh "${0}"

module purge
module load kaldi-2020/5968b4c-GCC-6.4.0-2.28-OPENBLAS
module list

. ./cmd.sh
. ./path.sh
. ./utils/parse_options.sh

cd "${EXPT_SCRIPT_DIR}"
  
# MMI training starting from the LDA+MLLT+SAT systems on all the  data.
steps/align_fmllr.sh --nj 30 --cmd "$train_cmd" \
    data/am-train \
    data/lang \
    exp/tri3b \
    exp/tri3b_ali

steps/make_denlats.sh --nj 30 --sub-split 30 --cmd "$decode_cmd" \
    --transform-dir exp/tri3b_ali \
    data/am-train \
    data/lang \
    exp/tri3b \
    exp/tri3b_denlats

# 4 iterations of MMI seems to work well overall. The number of iterations is
# used as an explicit argument even though train_mmi.sh will use 4 iterations by
# default.
num_mmi_iters=4
steps/train_mmi.sh --cmd "$decode_cmd" \
    --boost 0.1 \
    --num-iters $num_mmi_iters \
    data/am-train \
    data/lang \
    exp/tri3b_{ali,denlats} \
    exp/tri3b_mmi_b0.1