#!/bin/bash

source ../../../scripts/run-expt.sh "${0}"

module purge
module load speech-scripts
module load srilm
module list

. ./cmd.sh
. ./path.sh
. ./utils/parse_options.sh

local/prepare_dict_morph.sh 

