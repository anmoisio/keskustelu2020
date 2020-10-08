#!/bin/bash
#SBATCH --partition batch
#SBATCH --time=4:00:00
#SBATCH --mem=10G

source ../../../scripts/run-expt.sh "${0}"

module purge
module load speech-scripts
module load srilm
module list

. ./cmd.sh
. ./path.sh
. ./utils/parse_options.sh

local/prepare_test_dict.sh

