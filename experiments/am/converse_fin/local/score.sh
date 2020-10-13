#!/bin/bash
# WER, CER scores

[ -f ./path.sh ] && . ./path.sh

# begin configuration section.
cmd=run.pl
scoring_opts=
cer=true
#end configuration section.

echo "$0 $@"  # Print the command line for logging
[ -f ./path.sh ] && . ./path.sh
. parse_options.sh || exit 1;

if [ $# -ne 3 ]; then
  echo "Usage: $0 [--cmd (run.pl|queue.pl...)] <data-dir> <lang-dir|graph-dir> <decode-dir>"
  echo " Options:"
  echo "    --cmd (run.pl|queue.pl...)      # specify how to run the sub-processes."
  echo "    --cer (true|false)              # compute character error rate"
  exit 1;
fi

data=$1
lang_or_graph=$2
dir=$3

steps/scoring/score_kaldi_wer.sh $scoring_opts --cmd "$cmd" $data $lang_or_graph $dir

if $cer; then
  steps/scoring/score_kaldi_cer.sh $scoring_opts --cmd "$cmd" $data $lang_or_graph $dir
fi 
