#!/bin/bash

for lat_dir in exp/chain/tdnn7q_sp_ensemble2/lattices_eval_word_fullvocab
do
    echo $lat_dir

    # folder_name=${PWD##*/}
    # echo $folder_name

    # rm -r lats
    mkdir $lat_dir/lats
    cp $lat_dir/{1..8}/*.lat.gz $lat_dir/lats/


    touch $lat_dir/lats/lattice-list
    for filename in $lat_dir/lats/*.lat.gz
    do 
        # echo print to lattice list
        echo "$(basename ${filename})" >> $lat_dir/lats/lattice-list
    done

    # rm -r $lat_dir/../${folder_name}.tar
    echo create tar file
    cd $lat_dir/lats
    tar -czf "../../lattices_eval_word_fullvocab.tar" .

    # cd ..
    # rm -r lats
    # cd /m/triton/scratch/work/moisioa3/keskustelu2020/experiments/am/converse_fin
done