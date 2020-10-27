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

affix=7q

echo "$0 $@"  # Print the command line for logging

suffix=_sp_dsp

stage=3
nj=30

# The iVector-extraction and feature-dumping parts are the same as the standard
# nnet3 setup, and you can skip them by setting "--stage 8" if you have already
# run those things.

train_set=am-train
gmm_dir=exp/tri3b_mmi_b0.1
ali_dir=exp/tri3b_mmi_b0.1_ali${suffix}
lat_dir=exp/tri3b_mmi_b0.1_lats${suffix}
treedir=exp/chain/tri3b_mmi_tree${suffix}
lang=data/lang_chain

dir=data/am-train_sp_dsp

if [ $stage -le 1 ]; then
  # copy the data dir and remove perturbed speecon and FinDialogue data 
  utils/copy_data_dir.sh \
    data/am-train_sp \
    $dir

  # train data with only DSPcon files
  for file in $dir/{*.scp,spk2utt,utt2spk,utt2dur,text,reco2dur}
  do
    cat $file | egrep -v '^(sp1.1-SA|sp0.9-SA|sp1.1-F|sp0.9-F)' >${file}_temp
    mv ${file}_temp ${file}
  done
fi

if [ $stage -le 2 ]; then
  # if we are using the speed-perturbed data we need to generate
  # alignments for it.
  echo "$0: aligning with the perturbed low-resolution data"
  steps/align_fmllr.sh --nj $nj --cmd "$train_cmd" \
    data/${train_set}${suffix} \
    data/lang \
    $gmm_dir \
    $ali_dir
  
  # Get the alignments as lattices (gives the LF-MMI training more freedom).
  # use the same num-jobs as the alignments
  # lats are used in AM training
  nj=$(cat $ali_dir/num_jobs) || exit 1;
  steps/align_fmllr_lats.sh --nj $nj --cmd "$train_cmd" \
    data/${train_set}${suffix} \
    data/lang \
    $gmm_dir \
    $lat_dir
  rm $lat_dir/fsts.*.gz # save space
fi

if [ $stage -le 3 ]; then
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
fi