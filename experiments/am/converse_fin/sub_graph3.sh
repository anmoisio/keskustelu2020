#!/bin/bash -e
#SBATCH --partition batch
#SBATCH --time=4:00:00
#SBATCH --mem=38G

source ../../../scripts/run-expt.sh "${0}"

module purge
module load kaldi-2020/5968b4c-GCC-6.4.0-2.28-OPENBLAS
module list

. ./cmd.sh
. ./path.sh
. ./utils/parse_options.sh

for dir in exp/chain/tdnn7q_sp_ensemble2
do
    utils/lang/check_phones_compatible.sh \
        data/lang_chain/phones.txt \
        data/lang_test_morph_nosp/phones.txt

    utils/mkgraph.sh \
        --self-loop-scale 1.0 \
        data/lang_test_morph_nosp \
        $dir \
        $dir/graph_morph_nosp_5-gram || exit 1;

done