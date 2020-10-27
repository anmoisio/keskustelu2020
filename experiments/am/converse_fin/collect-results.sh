#!/bin/bash

for decode_dir in exp/chain/tdnn7q_sp*/decode_devel_word_fullvocab/scoring_kaldi
do
    echo $decode_dir
    cat $decode_dir/best_wer
    cat $decode_dir/best_cer
    cat $decode_dir/../oracle_wer
    echo 
done