#!/bin/bash -e

# begin configuration section.
cmd=run.pl
data_dir=
lang_dir=
decode_dir=
nj=1
# End configuration section.

. utils/parse_options.sh

echo "$0 $@"  # Print the command line for logging

if [ $# != 3 ]; then
   echo "Compute lattice oracle WER and CER"
   echo ""
   echo "Usage: $0 [options] <data-dir> <lang-dir> <decode-dir>"
   echo "  --cmd <cmd>       # How to run the jobs (default: run.pl)"
   exit 1;
fi

data_dir=$1
lang_dir=$2
decode_dir=$3

oracle_dir=${decode_dir}_oracle
oov_sym=`cat ${lang_dir}/oov.int`

$cmd JOB=1:$nj ${oracle_dir}/log/process.JOB.log \
utils/sym2int.pl --map-oov ${oov_sym} -f 2- \
    ${lang_dir}/words.txt ${data_dir}/text \|\
    lattice-oracle --write-lattices="ark:|gzip -c >${oracle_dir}/lat.JOB.gz" \
    --word-symbol-table=${lang_dir}/words.txt \
    "ark:gunzip -c ${decode_dir}/lat.JOB.gz |" ark:- ark,t:${oracle_dir}/oracle.JOB.tra
    
steps/scoring/score_kaldi_wer.sh ${data_dir} ${lang_dir} ${oracle_dir}
steps/scoring/score_kaldi_cer.sh ${data_dir}  ${lang_dir}  ${oracle_dir}
