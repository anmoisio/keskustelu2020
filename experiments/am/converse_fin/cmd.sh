

export train_cmd="utils/slurm.pl --mem 3G --time 1:00:00"
export decode_cmd="utils/slurm.pl --mem 16G --time 1:00:00"
export cuda_cmd="utils/slurm.pl --gpu 1 --mem 3G --time 1:00:00"
export score_cmd="utils/slurm.pl --mem 1G --time 1:00:00"