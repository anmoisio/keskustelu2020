# morfessor
# MORFESSOR_DAMPENING=ones
# MORFESSOR_CORPUS_WEIGHT=0.05
# RANDOM_SEED="1"
# declare -a TRAIN_FILES=("${data_dir}/lm-train/dsp.txt" "${data_dir}"/lm-train/web{1..6}.txt)

# variKN
declare -a TRAIN_FILES=("${PROJECT_DIR}/data/lm-train/char/dsp.txt" ${PROJECT_DIR}/data/lm-train/char/web{1..6}.txt)
DEVEL_FILE="${PROJECT_DIR}/data/lm-train/char/devel.txt"
EVAL_FILE="${PROJECT_DIR}/data/lm-train/char/eval.txt"
VARIKN_DSCALE="0.01"

UTILS_DIR="${EXPT_SCRIPT_DIR}/utils"
LM="${EXPT_SCRIPT_DIR}/kn.arpa"

export PATH="${UTILS_DIR}:${PATH}"
export TRAIN_CMD="${UTILS_DIR}/slurm.pl --mem 3G --time 1:00:00"
export DECODE_CMD="${UTILS_DIR}/slurm.pl --mem 10G --time 1:00:00"
export MKGRAPH_CMD="${UTILS_DIR}/slurm.pl --mem 4G --time 1:00:00"
export BIG_MEMORY_CMD="${UTILS_DIR}/slurm.pl --mem 8G --time 1:00:00"