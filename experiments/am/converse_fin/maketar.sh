#!/bin/bash

for test_set in eval 
do
    lat_dir=exp/chain/tdnn7q_sp_ensemble2/lattices_${test_set}_word_fullvocab
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
    tar -czf "../../lattices_${test_set}_word_fullvocab.tar" .

    cd ..
    rm -r lats
    cd /m/triton/scratch/work/moisioa3/keskustelu2020/experiments/am/converse_fin
done