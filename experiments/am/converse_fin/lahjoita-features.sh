#!/bin/bash -e

source ../../../scripts/run-expt.sh "${0}"

module purge
module load kaldi-2020/5968b4c-GCC-6.4.0-2.28-OPENBLAS
module load sox
module list

. ./cmd.sh
. ./path.sh
. ./utils/parse_options.sh

cd "${EXPT_SCRIPT_DIR}"

data_dir=data/lahjoitapuhetta-untranscribed

(set -x; steps/make_mfcc.sh --nj 1 --cmd "${train_cmd}" \
	--mfcc-config conf/mfcc_hires.conf \
	"${data_dir}" \
	data/log/mfcc-lahjoitapuhetta-untranscribed \
	data/mfcc-lahjoitapuhetta-untranscribed)

(set -x; steps/compute_cmvn_stats.sh \
	"${data_dir}" \
	data/log/mfcc-lahjoitapuhetta-untranscribed \
	data/mfcc-lahjoitapuhetta-untranscribed)
