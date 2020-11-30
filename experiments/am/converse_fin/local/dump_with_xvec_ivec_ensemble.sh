#!/bin/bash

# Copyright 2017 Nagoya University (Tomoki Hayashi)
#  Apache 2.0  (http://www.apache.org/licenses/LICENSE-2.0)

. ./path.sh

cmd=run.pl
do_delta=false
nj=1
verbose=0
compress=true
write_utt2num_frames=true
scaleup=true

. utils/parse_options.sh

echo "$0 $@"

if [ $# != 10 ]; then
    echo "Usage: $0 <datadir> <cmvn-ark> <x-vec-mean.vec> <x-vec-lda-transform> <xvecdir> <i-vec-mean.vec> <i-vec-lda-transform> <i-vecdir> <logdir> <dumpdir>"
    exit 1;
fi

datadir=$1
cmvnark=$2
meanvec=$3
ldatrans=$4
xvecdir=$5
xvecscp=$xvecdir/xvector.scp
ivecmeanvec=$6
ivecldatrans=$7
ivecdir=$8
ivecscp=$ivecdir/ivector.scp
logdir=$9
dumpdir=${10}

mkdir -p $logdir
mkdir -p $dumpdir

dumpdir=`perl -e '($dir,$pwd)= @ARGV; if($dir!~m:^/:) { $dir = "$pwd/$dir"; } print $dir; ' ${dumpdir} ${PWD}`

for n in $(seq $nj); do
    # the next command does nothing unless $dumpdir/storage/ exists, see
    # utils/create_data_link.pl for more info.
    utils/create_data_link.pl ${dumpdir}/feats.${n}.ark
done

if $write_utt2num_frames; then
    write_num_frames_opt="--write-num-frames=ark,t:$dumpdir/utt2num_frames.JOB"
else
    write_num_frames_opt=
fi

# split scp file and xvec 
split_scps=""
for n in $(seq $nj); do
    split_scps="$split_scps $logdir/feats.$n.scp"
done
utils/split_scp.pl ${datadir}/feats.scp $split_scps || exit 1;

for n in $(seq $nj); do
    utils/filter_scp.pl $logdir/feats.$n.scp $xvecscp > $logdir/xvecs.$n.scp
done

# split ivec
for n in $(seq $nj); do
    utils/filter_scp.pl $logdir/feats.$n.scp $ivecscp > $logdir/ivecs.$n.scp
done

# dump features
$cmd JOB=1:$nj $logdir/dump_feature.JOB.log \
    apply-cmvn --norm-vars=true --utt2spk=ark:$datadir/utt2spk ark:$cmvnark \
    scp:$logdir/feats.JOB.scp ark:- \| \
    append-vector-to-feats ark:- "ark:ivector-subtract-global-mean $meanvec scp:$logdir/xvecs.JOB.scp ark:- | transform-vec $ldatrans ark:- ark:- | ivector-normalize-length --scaleup=$scaleup ark:- ark:- |" ark:- \| \
    append-vector-to-feats ark:- "ark:ivector-subtract-global-mean $ivecmeanvec scp:$logdir/ivecs.JOB.scp ark:- | transform-vec $ivecldatrans ark:- ark:- | ivector-normalize-length --scaleup=false ark:- ark:- |" ark:- \| \
    copy-feats --compress=$compress --compression-method=2 ${write_num_frames_opt} \
        ark:- ark,scp:${dumpdir}/feats.JOB.ark,${dumpdir}/feats.JOB.scp || exit 1


# concatenate scp files
for n in $(seq $nj); do
    cat $dumpdir/feats.$n.scp || exit 1;
done > $dumpdir/feats.scp || exit 1

if $write_utt2num_frames; then
    for n in $(seq $nj); do
        cat $dumpdir/utt2num_frames.$n || exit 1;
    done > $dumpdir/utt2num_frames || exit 1
    rm $dumpdir/utt2num_frames.* 2>/dev/null
fi

# remove temp scps
rm $logdir/feats.*.scp 2>/dev/null
if [ ${verbose} -eq 1 ]; then
    echo "Succeeded dumping features for training"
fi
