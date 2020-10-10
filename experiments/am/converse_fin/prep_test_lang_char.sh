#!/bin/bash -e
#SBATCH --partition batch
#SBATCH --time=4:00:00
#SBATCH --mem=10G

source ../../../scripts/run-expt.sh "${0}"

module purge
module load kaldi-2020/5968b4c-GCC-6.4.0-2.28-OPENBLAS
module list

. ./cmd.sh
. ./path.sh
. ./utils/parse_options.sh

# print Kaldi repo version for logging
echo 'Kaldi version:'
git --no-pager --git-dir="${KALDI_ROOT}/.git/" log -n 1 
echo

lm="/scratch/work/moisioa3/conv_lm/experiments/morph/srilm-5-gram/kn-ip-dsp-web.arpa.gz"

# lang dir
lang=data/lang_test_morph_nosp
extra=3
utils/prepare_lang.sh \
  --num-extra-phone-disambig-syms $extra \
  --phone-symbol-table data/lang/phones.txt \
  data/local/dict_morph_nosp \
  "[oov]" \
  data/local/lang_tmp_morph_nosp \
  $lang

local/make_lfst_aff.py $(tail -n1 $lang/phones/disambig.txt) \
	< data/local/lang_tmp_morph_nosp/lexiconp_disambig.txt | fstcompile --isymbols=$lang/phones.txt \
	--osymbols=$lang/words.txt --keep_isymbols=false --keep_osymbols=false | \
	fstaddselfloops  $lang/phones/wdisambig_phones.int $lang/phones/wdisambig_words.int | \
	fstarcsort --sort_type=olabel > $lang/L_disambig.fst

zcat ${lm} | arpa2fst --disambig-symbol="#0" \
	--read-symbol-table=${lang}/words.txt - \
	${lang}/G.fst

# fails after make_lfst_aff.py (no need for this)
# utils/validate_lang.pl --skip-determinization-check "${lang}"
