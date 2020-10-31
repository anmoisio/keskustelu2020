#!/bin/bash

source ../../../scripts/run-expt.sh "${0}"

module purge
module load kaldi-2020/5968b4c-GCC-6.4.0-2.28-OPENBLAS
# module load anaconda3
# module load sox
module list

. ./cmd.sh
. ./path.sh
. ./utils/parse_options.sh

stage=7

# training data
train_data=data/am-train_sp_hires_voxceleb_xvec

# musan corpus on SPA network
musan_root=/scratch/elec/puhe/c/MUSAN

# for extractor training
train_stage=-1
use_gpu=true
remove_egs=false

nnet_dir=exp/xvector_nnet_1a
egs_dir=exp/xvector_nnet_1a/egs

# In the followinig sections, we augment the the training data with reverberation,
# noise, music, and babble, and combine it with the clean data.

if [ $stage -le 1 ]; then
  frame_shift=0.01
  awk -v frame_shift=$frame_shift '{print $1, $2*frame_shift;}' $train_data/utt2num_frames \
    > $train_data/reco2dur

  if [ ! -d "RIRS_NOISES" ]; then
    # Download the package that includes the real RIRs, simulated RIRs, isotropic noises and point-source noises
    wget --no-check-certificate http://www.openslr.org/resources/28/rirs_noises.zip
    unzip rirs_noises.zip
  fi

  # Make a version with reverberated speech
  rvb_opts=()
  rvb_opts+=(--rir-set-parameters "0.5, RIRS_NOISES/simulated_rirs/smallroom/rir_list")
  rvb_opts+=(--rir-set-parameters "0.5, RIRS_NOISES/simulated_rirs/mediumroom/rir_list")

  # Make a reverberated version of the VoxCeleb2 list.  Note that we don't add any
  # additive noise here.
  python steps/data/reverberate_data_dir.py \
    "${rvb_opts[@]}" \
    --speech-rvb-probability 1 \
    --pointsource-noise-addition-probability 0 \
    --isotropic-noise-addition-probability 0 \
    --num-replications 1 \
    --source-sampling-rate 16000 \
    $train_data ${train_data}_reverb
  cp $train_data/vad.scp ${train_data}_reverb/
  utils/copy_data_dir.sh --utt-suffix "-reverb" ${train_data}_reverb ${train_data}_reverb.new
  rm -rf ${train_data}_reverb
  mv ${train_data}_reverb.new ${train_data}_reverb
fi

# augment with music, speech and noise (MUSAN)
if [ $stage -le 2 ]; then
  # Prepare the MUSAN corpus, which consists of music, speech, and noise
  # suitable for augmentation.
  local/make_musan.sh $musan_root data

  # Get the duration of the MUSAN recordings.  This will be used by the
  # script augment_data_dir.py.
  for name in speech noise music; do
    utils/data/get_utt2dur.sh data/musan_${name}
    mv data/musan_${name}/utt2dur data/musan_${name}/reco2dur
  done

  # Augment with musan_noise
  python steps/data/augment_data_dir.py --utt-suffix "noise" --fg-interval 1 --fg-snrs "15:10:5:0" --fg-noise-dir "data/musan_noise" ${train_data} ${train_data}_noise
  # Augment with musan_music
  python steps/data/augment_data_dir.py --utt-suffix "music" --bg-snrs "15:10:8:5" --num-bg-noises "1" --bg-noise-dir "data/musan_music" ${train_data} ${train_data}_music
  # Augment with musan_speech
  python steps/data/augment_data_dir.py --utt-suffix "babble" --bg-snrs "20:17:15:13" --num-bg-noises "3:4:5:6:7" --bg-noise-dir "data/musan_speech" ${train_data} ${train_data}_babble

  # Combine reverb, noise, music, and babble into one directory.
  utils/combine_data.sh \
    ${train_data}_aug \
    ${train_data}_reverb \
    ${train_data}_noise \
    ${train_data}_music \
    ${train_data}_babble
fi

if [ $stage -le 3 ]; then
  # Take a random subset of the augmentations
  utils/subset_data_dir.sh \
    ${train_data}_aug \
    50000 \
    ${train_data}_aug_50k

  utils/fix_data_dir.sh ${train_data}_aug_50k

  # Make MFCCs for the augmented data.  Note that we do not compute a new
  # vad.scp file here.  Instead, we use the vad.scp from the clean version of
  # the list.
  steps/make_mfcc.sh \
    --mfcc-config 0007_voxceleb_v2_1a/conf/mfcc.conf \
    --nj 50 --cmd "$train_cmd" \
    ${train_data}_aug_50k

  # Combine the clean and augmented lists.
  utils/combine_data.sh ${train_data}_combined ${train_data}_aug_50k ${train_data}
fi

# Now we prepare the features to generate examples for xvector training.
if [ $stage -le 4 ]; then
  # This script applies CMVN and removes nonspeech frames.  Note that this is somewhat
  # wasteful, as it roughly doubles the amount of training data on disk.  After
  # creating training examples, this can be removed.
  local/nnet3/xvector/prepare_feats_for_egs.sh --nj 40 --cmd "$train_cmd" \
    ${train_data}_combined ${train_data}_combined_no_sil exp/train_combined_no_sil
  utils/fix_data_dir.sh ${train_data}_combined_no_sil
fi

if [ $stage -le 5 ]; then
  # Now, we need to remove features that are too short after removing silence
  # frames.  We want atleast 5s (500 frames) per utterance.
  min_len=400
  mv ${train_data}_combined_no_sil/utt2num_frames ${train_data}_combined_no_sil/utt2num_frames.bak
  awk -v min_len=${min_len} '$2 > min_len {print $1, $2}' ${train_data}_combined_no_sil/utt2num_frames.bak > ${train_data}_combined_no_sil/utt2num_frames
  utils/filter_scp.pl ${train_data}_combined_no_sil/utt2num_frames ${train_data}_combined_no_sil/utt2spk > ${train_data}_combined_no_sil/utt2spk.new
  mv ${train_data}_combined_no_sil/utt2spk.new ${train_data}_combined_no_sil/utt2spk
  utils/fix_data_dir.sh ${train_data}_combined_no_sil

  # We also want several utterances per speaker. Now we'll throw out speakers
  # with fewer than 8 utterances.
  min_num_utts=8
  awk '{print $1, NF-1}' ${train_data}_combined_no_sil/spk2utt > ${train_data}_combined_no_sil/spk2num
  awk -v min_num_utts=${min_num_utts} '$2 >= min_num_utts {print $1, $2}' ${train_data}_combined_no_sil/spk2num | utils/filter_scp.pl - ${train_data}_combined_no_sil/spk2utt > ${train_data}_combined_no_sil/spk2utt.new
  mv ${train_data}_combined_no_sil/spk2utt.new ${train_data}_combined_no_sil/spk2utt
  utils/spk2utt_to_utt2spk.pl ${train_data}_combined_no_sil/spk2utt > ${train_data}_combined_no_sil/utt2spk

  utils/filter_scp.pl ${train_data}_combined_no_sil/utt2spk ${train_data}_combined_no_sil/utt2num_frames > ${train_data}_combined_no_sil/utt2num_frames.new
  mv ${train_data}_combined_no_sil/utt2num_frames.new ${train_data}_combined_no_sil/utt2num_frames

  # Now we're ready to create training examples.
  utils/fix_data_dir.sh ${train_data}_combined_no_sil
fi


if [ $stage -le 6 ]; then
  num_pdfs=$(awk '{print $2}' ${train_data}_combined_no_sil/utt2spk | sort | uniq -c | wc -l)

  # Now we create the nnet examples using sid/nnet3/xvector/get_egs.sh.
  # The argument --num-repeats is related to the number of times a speaker
  # repeats per archive.  If it seems like you're getting too many archives
  # (e.g., more than 200) try increasing the --frames-per-iter option.  The
  # arguments --min-frames-per-chunk and --max-frames-per-chunk specify the
  # minimum and maximum length (in terms of number of frames) of the features
  # in the examples.
  #
  # To make sense of the egs script, it may be necessary to put an "exit 1"
  # command immediately after stage 3.  Then, inspect
  # exp/<your-dir>/egs/temp/ranges.* . The ranges files specify the examples that
  # will be created, and which archives they will be stored in.  Each line of
  # ranges.* has the following form:
  #    <utt-id> <local-ark-indx> <global-ark-indx> <start-frame> <end-frame> <spk-id>
  # For example:
  #    100304-f-sre2006-kacg-A 1 2 4079 881 23

  # If you're satisfied with the number of archives (e.g., 50-150 archives is
  # reasonable) and with the number of examples per speaker (e.g., 1000-5000
  # is reasonable) then you can let the script continue to the later stages.
  # Otherwise, try increasing or decreasing the --num-repeats option.  You might
  # need to fiddle with --frames-per-iter.  Increasing this value decreases the
  # the number of archives and increases the number of examples per archive.
  # Decreasing this value increases the number of archives, while decreasing the
  # number of examples per archive.
    sid/nnet3/xvector/get_egs.sh --cmd "$train_cmd" \
      --nj 8 \
      --stage 0 \
      --frames-per-iter 100000000 \
      --frames-per-iter-diagnostic 100000 \
      --min-frames-per-chunk 200 \
      --max-frames-per-chunk 400 \
      --num-diagnostic-archives 3 \
      --num-repeats 50 \
      "${train_data}_combined_no_sil" $egs_dir
fi


if [ $stage -le 7 ]; then
  echo "$0: creating neural net configs using the xconfig parser";
  num_targets=$(wc -w $egs_dir/pdf2num | awk '{print $1}')
  feat_dim=$(cat $egs_dir/info/feat_dim)

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
  mkdir -p $nnet_dir/configs
  cat <<EOF > $nnet_dir/configs/network.xconfig
  # please note that it is important to have input layer with the name=input

  # The frame-level layers
  input dim=${feat_dim} name=input
  relu-batchnorm-layer name=tdnn1 input=Append(-2,-1,0,1,2) dim=512
  relu-batchnorm-layer name=tdnn2 input=Append(-2,0,2) dim=512
  relu-batchnorm-layer name=tdnn3 input=Append(-3,0,3) dim=512
  relu-batchnorm-layer name=tdnn4 dim=512
  relu-batchnorm-layer name=tdnn5 dim=1500

  # The stats pooling layer. Layers after this are segment-level.
  # In the config below, the first and last argument (0, and ${max_chunk_size})
  # means that we pool over an input segment starting at frame 0
  # and ending at frame ${max_chunk_size} or earlier.  The other arguments (1:1)
  # mean that no subsampling is performed.
  stats-layer name=stats config=mean+stddev(0:1:1:${max_chunk_size})

  # This is where we usually extract the embedding (aka xvector) from.
  relu-batchnorm-layer name=tdnn6 dim=512 input=stats

  # This is where another layer the embedding could be extracted
  # from, but usually the previous one works better.
  relu-batchnorm-layer name=tdnn7 dim=512
  output-layer name=output include-log-softmax=true dim=${num_targets}
EOF

  steps/nnet3/xconfig_to_configs.py \
      --xconfig-file $nnet_dir/configs/network.xconfig \
      --config-dir $nnet_dir/configs
  cp $nnet_dir/configs/final.config $nnet_dir/nnet.config

  # These three files will be used by sid/nnet3/xvector/extract_xvectors.sh
  echo "output-node name=output input=tdnn6.affine" > $nnet_dir/extract.config
  echo "$max_chunk_size" > $nnet_dir/max_chunk_size
  echo "$min_chunk_size" > $nnet_dir/min_chunk_size
fi

dropout_schedule='0,0@0.20,0.1@0.50,0'
srand=123
if [ $stage -le 8 ]; then
  steps/nnet3/train_raw_dnn.py --stage=$train_stage \
    --cmd="$train_cmd" \
    --trainer.optimization.proportional-shrink 10 \
    --trainer.optimization.momentum=0.5 \
    --trainer.optimization.num-jobs-initial=3 \
    --trainer.optimization.num-jobs-final=8 \
    --trainer.optimization.initial-effective-lrate=0.001 \
    --trainer.optimization.final-effective-lrate=0.0001 \
    --trainer.optimization.minibatch-size=64 \
    --trainer.srand=$srand \
    --trainer.max-param-change=2 \
    --trainer.num-epochs=3 \
    --trainer.dropout-schedule="$dropout_schedule" \
    --trainer.shuffle-buffer-size=1000 \
    --egs.frames-per-eg=1 \
    --egs.dir="$egs_dir" \
    --cleanup.remove-egs $remove_egs \
    --cleanup.preserve-model-interval=10 \
    --use-gpu=true \
    --dir=$nnet_dir  || exit 1;
fi

exit 0;
