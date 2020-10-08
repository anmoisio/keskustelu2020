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

# training lang dir
lang=data/lang_nosp

# new lang dir used for decoding
dir=data/lang_test_word_nosp

# LM
lm="/scratch/work/moisioa3/conv_lm/experiments/4gram/ip/kn-ip-dsp-web.arpa.gz"

# create lang dir for decoding with grammar G.fst

echo "${dir}"
mkdir -p "${dir}"
cp -r "${EXPT_WORK_DIR}/$lang/"* "${dir}/"

tmpdir="${EXPT_WORK_DIR}/lm_tmp"
mkdir -p "${tmpdir}"
echo "${tmpdir}/oovs.txt :: ${lm} ${dir}/words.txt"
# find_arpa_oovs.pl will close the input early and cause a SIGPIPE.
zcat "${lm}" |
	"${UTILS_DIR}/find_arpa_oovs.pl" "${dir}/words.txt" \
	>"${tmpdir}/oovs.txt" || true

echo "${dir}/G.fst :: ${lm}"
zcat "${lm}" |
	arpa2fst - |
	fstprint |
	"${UTILS_DIR}/remove_oovs.pl" "${tmpdir}/oovs.txt" |
	"${UTILS_DIR}/eps2disambig.pl" |
	"${UTILS_DIR}/s2eps.pl" |
	fstcompile --isymbols="${dir}/words.txt" \
				--osymbols="${dir}/words.txt" --keep_isymbols=false --keep_osymbols=false |
	fstrmepsilon |
	fstarcsort --sort_type=ilabel \
	>"${dir}/G.fst"

utils/validate_lang.pl --skip-determinization-check "${dir}"

rm -rf "${tmpdir}"

