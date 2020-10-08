#!/bin/bash -e

# nosp = no silence & pronunciation probabilities
dir=data/local/dict_train_nosp
mkdir -p "${dir}"

train_trn="../../../data/am-train/verbatim.trn"

vocab_file="${dir}/vocab.txt"
echo "${vocab_file} :: ${train_trn}"
sed 's/(.*$//' "${train_trn}" |
  ngram-count -order 1 -no-sos -no-eos -text - -write-vocab - |
  egrep -v '^(-pau-|<s>|</s>|<unk>)$' \
  >"${vocab_file}"

# lexicon.txt is without the _B, _E, _S, _I markers for beginning, ending, and singleton phones.
dict_file="${dir}/lexicon.txt"
echo "${dict_file} :: ${vocab_file}"
echo "[oov] SPN" >"${dict_file}"
vocab2dict-fi.pl -read="${vocab_file}" >>"${dict_file}"

rm -f "${dir}/lexiconp.txt"

# Create a list of normal (non-silence) phones. We have only one stress.
symbols_file="${dir}/nonsilence_phones.txt"
echo "${symbols_file} :: ${dict_file}"
cut -d' ' -f2- "${dict_file}" |
  tr ' ' '\n' |
  sort -u |
  egrep -v '^(SIL|SPN|NSN)$' \
  >"${symbols_file}"

# Create a list of silence phones.
echo "${dir}/silence_phones.txt"
echo 'SIL' >"${dir}/silence_phones.txt"
echo 'SPN' >>"${dir}/silence_phones.txt"
echo 'NSN' >>"${dir}/silence_phones.txt"

echo "${dir}/optional_silence.txt"
echo 'SIL' >"${dir}/optional_silence.txt"

# Here we would have extra questions about stress if we would use it; there's
# also one for silence.
echo "${dir}/extra_questions.txt :: ${dir}/<non>silence_phones.txt"
awk '{
    printf("%s ", $1);
  }
  END {
    printf "\n";
  }' "${dir}/silence_phones.txt" \
  >"${dir}/extra_questions.txt"
perl -e '
  while(<>) {
    foreach $phone (split(" ", $_)) {
      $phone =~ m/^([^\d]+)(\d*)$/ || die "Invalid phone in nonsilence_phones.txt: $_";
      $phones{$2} .= "$phone ";
    }
  }
  foreach $phone (values %phones) {
    print "$phone\n";
  }' "${dir}/nonsilence_phones.txt" \
  >>"${dir}/extra_questions.txt"
