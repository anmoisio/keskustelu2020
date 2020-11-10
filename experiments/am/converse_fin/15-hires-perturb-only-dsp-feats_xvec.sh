#!/bin/bash

source ../../../scripts/run-expt.sh "${0}"

module purge
module load kaldi-2020/5968b4c-GCC-6.4.0-2.28-OPENBLAS
module list

. ./cmd.sh
. ./path.sh
. ./utils/parse_options.sh

dir=data/am-train_sp_dsp_xvec_hires

# copy the data dir and remove perturbed speecon and FinDialogue data 
utils/copy_data_dir.sh \
  data/am-train_sp_hires_voxceleb_xvec \
  $dir

# train data with only DSPcon files
for file in $dir/{*.scp,spk2utt,utt2spk,utt2dur,text,reco2dur}
do
  cat $file | egrep -v '^(sp1.1-SA|sp0.9-SA|sp1.1-F|sp0.9-F)' >${file}_temp
  mv ${file}_temp ${file}
done
