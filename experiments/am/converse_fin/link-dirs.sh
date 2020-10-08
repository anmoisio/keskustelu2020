#!/bin/bash

# kaldi scripts
ln -s /scratch/work/moisioa3/kaldi/egs/wsj/s5/steps .
ln -s /scratch/work/moisioa3/kaldi/egs/wsj/s5/utils .

# for creating vocab from arpa LM
# ln -s /scratch/work/moisioa3/conv_lm/elisa-asr-2019/conv_lm/common .

ln -s utils/parse_options.sh .