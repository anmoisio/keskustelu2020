#!/bin/bash

source ../../../scripts/run-expt.sh "${0}"

module purge
module load kaldi-2020/5968b4c-GCC-6.4.0-2.28-OPENBLAS
module list

. ./cmd.sh
. ./path.sh
. ./utils/parse_options.sh

stage=1

nj=30
train_set="am-train" # you might set this to e.g. train.
test_sets="devel eval"

nj_extractor=30
# It runs a JOB with '-pe smp N', where N=$[threads*processes]
num_processes_extractor=1
num_threads_extractor=1

# same as xvector_nnet_1a_finetune_2layers but extract from the 7th layer

dir=exp/xvector_nnet_1a_finetune_2layers_extract7
nnet3_affix=_finetune_2layers_extract7

cp -r exp/xvector_nnet_1a_finetune_2layers $dir

# training data
train_data=data/am-train_sp_hires_voxceleb_xvec

srand=123

# This chunk-size corresponds to the maximum number of frames the
# stats layer is able to pool over.  In this script, it corresponds
# to 100 seconds.  If the input recording is greater than 100 seconds,
# we will compute multiple xvectors from the same recording and average
# to produce the final xvector.
max_chunk_size=10000

# The smallest number of frames we're comfortable computing an xvector from.
# Note that the hard minimum is given by the left and right context of the
# frame-level layers.
min_chunk_size=25

xvec_suffix=_hires
extractor_dir=$dir

# These three files will be used by sid/nnet3/xvector/extract_xvectors.sh
rm $dir/extract.config
echo "output-node name=output input=tdnn7.affine" > $dir/extract.config
echo "$max_chunk_size" > $dir/max_chunk_size
echo "$min_chunk_size" > $dir/min_chunk_size

if [ $stage -le 3 ]; then
  # extract x-vectors for train data
  xvectordir=exp/nnet3${nnet3_affix}/xvectors_${train_set}_sp${xvec_suffix}
  sid/nnet3/xvector/extract_xvectors.sh --cmd "$train_cmd" --nj 50 \
    ${extractor_dir} \
    data/${train_set}_sp_hires_voxceleb_xvec \
    $xvectordir

  # Also extract x-vectors for the test data, but in this case we don't need the speed
  # perturbation (sp).
  for data in ${test_sets}; do
    # nspk=$(wc -l <data/${data}_hires/spk2utt) # nj can't be larger than number of spks
    sid/nnet3/xvector/extract_xvectors.sh --cmd "$train_cmd" --nj 17 \
      ${extractor_dir} \
      data/${data}_hires_voxceleb_xvec \
      exp/nnet3${nnet3_affix}/xvectors_${data}${xvec_suffix}
  done
fi

lda_dim=200

if [ $stage -le 4 ]; then
  # Compute the mean vector of the training set x-vectors
  # for centering the evaluation x-vectors.
  $train_cmd exp/xvectors_train/log/compute_mean.log \
    ivector-mean scp:exp/nnet3${nnet3_affix}/xvectors_${train_set}_sp${xvec_suffix}/xvector.scp \
    exp/nnet3${nnet3_affix}/xvectors_${train_set}_sp${xvec_suffix}/mean.vec || exit 1;

  # Compute LDA to decrease the dimensionality
  
  $train_cmd exp/nnet3${nnet3_affix}/xvectors_${train_set}_sp${xvec_suffix}/log/lda$lda_dim.log \
    ivector-compute-lda --total-covariance-factor=0.0 --dim=$lda_dim \
    "ark:ivector-subtract-global-mean scp:exp/nnet3${nnet3_affix}/xvectors_${train_set}_sp${xvec_suffix}/xvector.scp ark:- |" \
    ark:data/${train_set}_sp/utt2spk exp/nnet3${nnet3_affix}/xvectors_${train_set}_sp${xvec_suffix}/lda$lda_dim.mat || exit 1;
fi

if [ $stage -le 5 ]; then
  for data in ${train_set}_sp ${test_sets} ; do
    # apply LDA and concatenate the i-vectors to features
    xvecdir=exp/nnet3${nnet3_affix}/xvectors_${data}${xvec_suffix}

    local/dump_with_xvec.sh --cmd "$train_cmd" \
      --nj 8 \
      data/${data}_hires \
      data/${data}_hires/data/cmvn_${data}_hires.ark \
      exp/nnet3${nnet3_affix}/xvectors_${train_set}_sp${xvec_suffix}/mean.vec \
      exp/nnet3${nnet3_affix}/xvectors_${train_set}_sp${xvec_suffix}/lda$lda_dim.mat \
      ${xvecdir} \
      ${xvecdir}/log_feats_lda${lda_dim}_vad \
      ${xvecdir}/feat_dump_lda${lda_dim}_vad

    cp data/${data}/utt2spk ${xvecdir}/feat_dump_lda${lda_dim}_vad/
    cp data/${data}/text ${xvecdir}/feat_dump_lda${lda_dim}_vad/
  done
fi


exit 0;
