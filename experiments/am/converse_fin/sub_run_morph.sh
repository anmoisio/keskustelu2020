#!/bin/bash
#SBATCH --partition batch
#SBATCH --time=4:00:00
#SBATCH --mem=10G

source ../../../scripts/run-expt.sh "${0}"

module purge
module load speech-scripts
module load srilm
module load kaldi-2020/5968b4c-GCC-6.4.0-2.28-OPENBLAS
module list

. ./cmd.sh
. ./path.sh
. ./utils/parse_options.sh

# for n in {3,4}
# do
#     local/prepare_dict_morph.sh \
#         data/morph_lm_${n}-gram/kn-ip-dsp-web.arpa.gz \
#         data/local/dict_morph_nosp_${n}-gram

#     local/prepare_test_lang_morph.sh \
#         data/morph_lm_${n}-gram/kn-ip-dsp-web.arpa.gz \
#         data/local/dict_morph_nosp_${n}-gram \
#         data/lang_test_morph_nosp_${n}-gram

# done

local/prepare_dict_morph.sh \
    "data/D=0.001-D2=0.002-cutoffs001/kn.arpa.gz" \
    "data/local/dict_morph_nosp_D=0.001-D2=0.002-cutoffs001"

local/prepare_test_lang_morph.sh \
    "data/D=0.001-D2=0.002-cutoffs001/kn.arpa.gz" \
    "data/local/dict_morph_nosp_D=0.001-D2=0.002-cutoffs001" \
    "data/lang_test_morph_nosp_D=0.001-D2=0.002-cutoffs001"