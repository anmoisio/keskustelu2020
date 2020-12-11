#!/bin/bash -e

# dict 
dict=data/local/dict_morph_nosp
# lang dir
lang=data/lang_test_morph_nosp

. ./utils/parse_options.sh

if [ $# != 3 ]; then
    echo "Usage: $0 <lm> <dict-dir> <lang-dir>"
    exit 1;
fi

lm=$1
dict=$2
lang=$3

extra=3
utils/prepare_lang.sh \
  --num-extra-phone-disambig-syms $extra \
  --phone-symbol-table data/lang/phones.txt \
  ${dict} \
  "[oov]" \
  $lang/tmp \
  $lang

local/make_lfst_aff.py $(tail -n1 $lang/phones/disambig.txt) \
	< data/local/lang_tmp_morph_nosp/lexiconp_disambig.txt | fstcompile --isymbols=$lang/phones.txt \
	--osymbols=$lang/words.txt --keep_isymbols=false --keep_osymbols=false | \
	fstaddselfloops  $lang/phones/wdisambig_phones.int $lang/phones/wdisambig_words.int | \
	fstarcsort --sort_type=olabel > $lang/L_disambig.fst

zcat ${lm} | arpa2fst --disambig-symbol="#0" \
	--read-symbol-table=${lang}/words.txt - \
	${lang}/G.fst

# fails after make_lfst_aff.py, no need for this
# utils/validate_lang.pl --skip-determinization-check "${lang}"
