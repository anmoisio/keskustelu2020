#!/bin/bash

# nosp = no silence & pronunciation probabilities
dir=data/local/dict_test_morph_nosp
mkdir -p "${dir}"

lm_file="/scratch/work/moisioa3/conv_lm/experiments/morph/srilm-5-gram/kn-ip-dsp-web.arpa.gz"
# extract full 2.4M token vocab from the LM
vocab_file="${dir}/vocab.txt"
echo "${vocab_file} :: $lm_file"
zcat "$lm_file" |
  sed '/\\1-grams:/,/\\2-grams/!d;//d' |
  cut -f2 |
  egrep -v '^(<s>|</s>|<unk>|)$' \
  >"${vocab_file}"

# lexicon.txt is without the _B, _E, _S, _I markers for beginning, ending, and singleton phones.
dict_file="${dir}/lexicon.txt"
echo "${dict_file} :: ${vocab_file}"
echo "[oov] SPN" >"${dict_file}"

# modified script that removes word boundary markers
/scratch/work/moisioa3/conv_lm/scripts/vocab2dict-fi.pl -read="${vocab_file}" >>"${dict_file}"