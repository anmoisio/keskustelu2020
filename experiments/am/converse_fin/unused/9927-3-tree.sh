#!/bin/bash -e

source ../../../scripts/run-expt.sh "${0}"

module purge
module load kaldi-vanilla
module list

cd "${EXPT_SCRIPT_DIR}"
set -e -o pipefail
echo "$0 $@"  # Print the command line for logging

. ./utils/parse_options.sh

train_set=am-train
ali_dir=exp/tri3b_mmi_b0.1_ali
treedir=exp/chain/tri3b_mmi_tree
lang=data/lang_chain_2y

# Build a tree using our new topology. This is the critically different
# step compared with other recipes.
steps/nnet3/chain/build_tree.sh --frame-subsampling-factor 3 \
    --context-opts "--context-width=2 --central-position=1" \
    --cmd "$train_cmd" \
    7000 \
    ../chain_tdnn_enarvi_swbd7q/data/$train_set \
    $lang \
    $ali_dir \
    $treedir