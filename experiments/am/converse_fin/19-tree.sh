#!/bin/bash

source ../../../scripts/run-expt.sh "${0}"

module purge
module load kaldi-2020/5968b4c-GCC-6.4.0-2.28-OPENBLAS
module list

. ./cmd.sh
. ./path.sh
. ./utils/parse_options.sh
cd "${EXPT_SCRIPT_DIR}"
set -e -o pipefail

speed_perturb=true
affix=7q

echo "$0 $@"  # Print the command line for logging

suffix=
$speed_perturb && suffix=_sp
dir=exp/chain/tdnn${affix}${suffix}

# The iVector-extraction and feature-dumping parts are the same as the standard
# nnet3 setup, and you can skip them by setting "--stage 8" if you have already
# run those things.

train_set=am-train
ali_dir=exp/tri3b_mmi_b0.1_ali_am-train${suffix}
treedir=exp/chain/tri3b_mmi_tree${suffix}
lang=data/lang_chain


# Get the alignments as lattices (gives the LF-MMI training more freedom).
# use the same num-jobs as the alignments
nj=$(cat $ali_dir/num_jobs) || exit 1;
steps/align_fmllr_lats.sh --nj $nj --cmd "$train_cmd" \
  data/am-train${suffix} \
  data/lang \
  exp/tri3b_mmi_b0.1 \
  exp/tri3b_mmi_b0.1_lats${suffix}
rm exp/tri3b_mmi_b0.1_lats${suffix}/fsts.*.gz # save space


# Create a version of the lang/ directory that has one state per phone in the
# topo file. [note, it really has two states.. the first one is only repeated
# once, the second one has zero or more repeats.]
rm -rf $lang
cp -r data/lang $lang
silphonelist=$(cat $lang/phones/silence.csl) || exit 1;
nonsilphonelist=$(cat $lang/phones/nonsilence.csl) || exit 1;
# Use our special topology... note that later on may have to tune this
# topology.
steps/nnet3/chain/gen_topo.py \
  $nonsilphonelist \
  $silphonelist \
  >$lang/topo

# Build a tree using our new topology. This is the critically different
# step compared with other recipes.
steps/nnet3/chain/build_tree.sh --frame-subsampling-factor 3 \
    --context-opts "--context-width=2 --central-position=1" \
    --cmd "$train_cmd" \
    7000 \
    data/${train_set}${suffix} \
    $lang \
    $ali_dir \
    $treedir