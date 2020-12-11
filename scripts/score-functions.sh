#!/bin/bash -e
#
# Functions for scoring text with language models, using SRILM and various
# neural network language modeling toolkits.
#
# Author: Seppo Enarvi

# source "${PROJECT_SCRIPT_DIR}/defs.sh"

# debug
set -E
trap 'echo Failed on line: $LINENO at command: $BASH_COMMAND' ERR

eval_kn () {
	local test_set="${1:-eval}"
	local model_name="${2:-kn}"

	[ -n "${AM}" ] || AM="${PROJECT_DIR}/models/puhekieli2016c"
	[ -n "${LM}" ] || LM="${EXPT_WORK_DIR}/${model_name}"
	[ -n "${LOOKAHEAD_LM}" ] || LOOKAHEAD_LM="${EXPT_WORK_DIR}/${model_name}-lookahead"
	[ -n "${DICTIONARY}" ] || DICTIONARY="${EXPT_WORK_DIR}/${model_name}"
	export FSA="1"
	export SPLIT_MULTIWORDS=""
	export ADAPTATION=""
	export SPEAKER_ID_FIELD="1"
	[ -n "${BEAM}" ] || BEAM="280"
	[ -n "${LM_SCALE}" ] || LM_SCALE="30"
	export TOKEN_LIMIT="100000"
	[ -n "${NUM_BATCHES}" ] || NUM_BATCHES="135"
	export MAX_PARALLEL="135"
	[ -n "${AUDIO_LIST}" ] || AUDIO_LIST="${PROJECT_DIR}/data/${test_set}/wav-list"
	export REFERENCE_TRN="${PROJECT_DIR}/data/${test_set}/normalized.trn"
	[ -n "${RESULTS}" ] || RESULTS="${RESULTS_DIR}/${test_set}/lms=${LM_SCALE}.trn"
	export AM LM LOOKAHEAD_LM DICTIONARY CLASSES BEAM LM_SCALE NUM_BATCHES
	export AUDIO_LIST RECTOOL_LNA_DIR RECTOOL_OUTPUT_DIR RESULTS
	export RECTOOL_MEM_PER_CPU
	export RECOGNITIONS_DIR="${EXPT_WORK_DIR}/rec"

	echo resultsd ${RESULTS}
	mkdir -p $(dirname "${RESULTS}")
	recognize-batch.sh
}

# Prunes a batch of lattices to match a maximum node count.
#
prune_lattices () {
	local test_set="${1}"
	local max_nodes="${2}"
	local num_batches="${3:-1}"
	local batch_index="${4:-1}"

	[ -n "${max_nodes}" ] || { echo "Requires the maximum number of nodes." >&2; exit 1; }
	[ -n "${EXPT_WORK_DIR}" ] || { echo "EXPT_WORK_DIR required." >&2; exit 1; }

	local lattices_file="${EXPT_WORK_DIR}/lattices/${test_set}/lattice-list"
	declare -a batch_lattices
	readarray -t batch_lattices < <(sed -n "${batch_index}~${num_batches}p" "${lattices_file}")

	local output_dir="${EXPT_WORK_DIR}/lattices/${test_set}-pruned"
	mkdir -p "${output_dir}"

	for lattice in "${batch_lattices[@]}"
	do
		local name=$(basename "${lattice}" -rescored.slf)
		local output_file="${output_dir}/${name}.slf"
		if [ -s "${output_file}" ]
		then
			echo "${name}: exists already"
		else
			echo "${name}: pruning"
			lattice-tool \
			  -in-lattice "${lattice}" -read-htk \
			  -out-lattice "${output_file}" -write-htk \
			  -nodes-prune "${max_nodes}" \
			  -debug 2 2>&1 |
			  egrep 'left with [0-9]+ nodes' || true
			echo "${name}: done"
		fi
	done
}

# Creates a .trn from the best hypotheses in an n-best list.
#
get_best_hypotheses () {
	local nbest_file="${1}"
	local trn_file="${2}"

	echo "${trn_file} :: ${nbest_file}"
	# $1 = ID
	# $2 = scaled AM score
	# $3 = scaled LM score
	# $4 = number of words
	awk '{ $2=$2+$3; $3=$4=""; print }' <"${nbest_file}" \
	| sort -k1,1 -k2,2gr \
	| awk '$1!=id{ id=$1; for(i=3; i<=NF; ++i) printf $i " "; print "(" $1 ")" }' \
	>"${trn_file}"
}

# Interpolates LM scores in an n-best list and writes the best sentences to a
# .trn.
#
interpolate_nbest_scores () {
	local nnlm_weight="${1}"
	local nnlm_scale="${2}"
	local bolm_scale="${3}"
	local test_set="${4}"

	[ -n "${EXPT_WORK_DIR}" ] || { echo "EXPT_WORK_DIR required." >&2; exit 1; }
	[ -n "${RESULTS_DIR}" ] || { echo "RESULTS_DIR required." >&2; exit 1; }

	local baseline_nbest_file="${EXPT_WORK_DIR}/rescore-50best/${test_set}/baseline-lms=${bolm_scale}.nbest"
	local nnlm_probs_file="${baseline_nbest_file}.nnlm-probs"
	local interpolated_nbest_file="${EXPT_WORK_DIR}/rescore-50best/${test_set}/ips=${nnlm_weight}x${nnlm_scale}x${bolm_scale}.nbest"
	local rescored_trn_file="${RESULTS_DIR}/${test_set}/ip=score${nnlm_weight}x${nnlm_scale}x${bolm_scale}.trn"

	nnlm_probs_length=$(wc -l <"${nnlm_probs_file}")
	baseline_nbest_length=$(wc -l <"${baseline_nbest_file}")
	if [ "${nnlm_probs_length}" -ne "${baseline_nbest_length}" ]
	then
		echo "${nnlm_probs_file} contains ${nnlm_probs_length} lines, but ${baseline_nbest_file} contains ${baseline_nbest_length} lines."
		exit 1
	fi

	mkdir -p "${RESULTS_DIR}/${test_set}"

	echo "${interpolated_nbest_file}"
	# $1 = NNLM score
	# $2 = ID
	# $3 = AM score
	# $4 = back-off LM score
	# $5 = number of words
	paste -d' ' "${nnlm_probs_file}" "${baseline_nbest_file}" \
	| awk -v "nnscale=${nnlm_scale}" -v "boscale=${bolm_scale}" -v "lambda=${nnlm_weight}" \
	  '{ nnscore=$1*nnscale; boscore=$4*boscale; $4=nnscore*lambda+boscore*(1-lambda); $1=""; print }' \
	| awk '{ $1=$1; print }' \
	>"${interpolated_nbest_file}"

	get_best_hypotheses "${interpolated_nbest_file}" "${rescored_trn_file}"
}

# Interpolates LM probabilities in an n-best list and writes the best sentences
# to a .trn.
#
interpolate_nbest_probs () {
	local nnlm_weight="${1}"
	local nnlm_scale="${2}"
	local bolm_scale="${3}"

	[ -n "${EXPT_WORK_DIR}" ] || { echo "EXPT_WORK_DIR required." >&2; exit 1; }
	[ -n "${RESULTS_DIR}" ] || { echo "RESULTS_DIR required." >&2; exit 1; }

	local baseline_nbest_file="${EXPT_WORK_DIR}/rescore-50best/${test_set}/baseline-lms=${bolm_scale}.nbest"
	local nnlm_probs_file="${baseline_nbest_file}.nnlm-probs"
	local interpolated_nbest_file="${EXPT_WORK_DIR}/rescore-50best/${test_set}/ipp=${nnlm_weight}x${nnlm_scale}x${bolm_scale}.nbest"
	local rescored_trn_file="${RESULTS_DIR}/${test_set}/ip=prob${nnlm_weight}x${nnlm_scale}x${bolm_scale}.trn"

	nnlm_probs_length=$(wc -l <"${nnlm_probs_file}")
	baseline_nbest_length=$(wc -l <"${baseline_nbest_file}")
	if [ "${nnlm_probs_length}" -ne "${baseline_nbest_length}" ]]
	then
		echo "${nnlm_probs_file} contains ${nnlm_probs_length} lines, but ${baseline_nbest_file} contains ${baseline_nbest_length} lines."
		exit 1
	fi

	mkdir -p "${RESULTS_DIR}"

	echo "${interpolated_nbest_file}"
	# $1 = ID
	# $2 = AM score
	# $3 = LM score
	# $4 = number of words
	interpolate-nbest-lmprobs.py \
	  "${baseline_nbest_file}" \
	  "${nnlm_probs_file}" \
	  --scale1 "${bolm_scale}" \
	  --scale2 "${nnlm_scale}" \
	  --lambda "${nnlm_weight}" \
	>"${interpolated_nbest_file}"

	get_best_hypotheses "${interpolated_nbest_file}" "${rescored_trn_file}"
}

decode_kn () {
	local test_set="${1:-eval}"

	[ -n "${EXPT_WORK_DIR}" ] || { echo "EXPT_WORK_DIR required." >&2; exit 1; }
	[ -n "${RESULTS_DIR}" ] || { echo "RESULTS_DIR required." >&2; exit 1; }
	[ -n "${LATTICES}" ] || { echo "LATTICES required." >&2; exit 1; }

	local lm="${LM:-${EXPT_WORK_DIR}/kn.arpa.gz}"
	if [ "${lm}" = "-" ]
	then
		lm=""
	fi

	local lattices_tar="${PROJECT_DIR}/lattices/${test_set}/${LATTICES}.tar"
	local lattices_dir="${JOB_TMP_DIR}/lattices"
	[ -e "${lattices_dir}" ] && { echo "${lattices_dir} exists already!" >&2; exit 2; }
	echo "${lattices_dir}"
	mkdir -p "${lattices_dir}"
	tar xf "${lattices_tar}" -C "${lattices_dir}"
	local lattices_file="${lattices_dir}/lattice-list"
	sed -i "s:^:${lattices_dir}/:" "${lattices_file}"

	local trn_dir="${RESULTS_DIR}/${test_set}"
	mkdir -p "${trn_dir}"

	for lm_scale in {10..14}
	do
		export DECODE_LATTICES_ORDER="${LM_ORDER:-4}"
		export DECODE_LATTICES_LM1="${lm}"
		export DECODE_LATTICES_LM2=""
		export DECODE_LATTICES_LM_SCALE="${lm_scale}"
		export DECODE_LATTICES_CLASSES="${CLASSES}"

		trn_file="${trn_dir}/lambda=1.0-lms=${lm_scale}.trn"
		echo "Reading ${lattices_file}."
		decode-lattices.sh "${lattices_file}" |
		  sed 's/+ +//g' \
		  >"${trn_file}"
		echo "Wrote ${trn_file}."

		if [ -n "${BASELINE_LM}" ]
		then
			export DECODE_LATTICES_LM2="${BASELINE_LM}"

			trn_file="${trn_dir}/lambda=0.5-lms=${lm_scale}.trn"
			echo "Reading ${lattices_file}."
			decode-lattices.sh "${lattices_file}" |
			  sed 's/+ +//g' \
			  >"${trn_file}"
			echo "Wrote ${trn_file}."
		fi
	done

	rm -rf "${JOB_TMP_DIR}"
}

# Rescores an n-best list using a TheanoLM model, with given model scales and a
# weight for the TheanoLM probabilities.
rescore_theanolm () {
	local nnlm_weight="${1:-1}"
	local nnlm_scale="${2:-15}"
	local bolm_scale="${3:-15}"
	local test_set="${4:-eval}"

	[ -n "${EXPT_WORK_DIR}" ] || { echo "EXPT_WORK_DIR required." >&2; exit 1; }
	[ -n "${EXPT_NAME}" ] || { echo "EXPT_NAME required." >&2; exit 1; }
	[ -n "${EXPT_PARAMS}" ] || { echo "EXPT_PARAMS required." >&2; exit 1; }
	[ -n "${BASELINE_LATTICES}" ] || { echo "BASELINE_LATTICES required." >&2; exit 1; }
	[ -n "${RESULTS_DIR}" ] || { echo "RESULTS_DIR required." >&2; exit 1; }

	declare -a extra_args
	if [ -n "${IGNORE_UNK}" ]
	then
		extra_args+=(--unk-penalty 0)
	elif [ -n "${UNK_PENALTY}" ]
	then
		extra_args+=(--unk-penalty="${UNK_PENALTY}")
	fi

	if [ ! -n "${bolm_scale}" ]
	then
		local some_lattice=$(head -1 "${BASELINE_LATTICES}")
		bolm_scale=$(sed -n -r 's/lmscale=([0-9\.]+).*/\1/p' "${some_lattice}")
		[ -n "${bolm_scale##*[!0-9.]*}" ] || bolm_scale="30"
	fi

	source "${PROJECT_SCRIPT_DIR}/configure-theano.sh"
	export THEANO_FLAGS
	# echo "${PYTHONPATH}" | tr ':' '\n' | grep '\/Theano\/' || { echo "Theano not found in PYTHONPATH." >&2; exit 1; }
	echo "${THEANO_FLAGS}"
        theanolm version
        echo "=="

	local baseline_nbest_file="${EXPT_WORK_DIR}/rescore-${NBEST_FROM_LATTICES_N}best/${test_set}/baseline-lms=${bolm_scale}.nbest"
	# if [ ! -s "${baseline_nbest_file}" ]
	# then
	# 	mkdir -p "${EXPT_WORK_DIR}/rescore-${NBEST_FROM_LATTICES_N}best/${test_set}"
	# 	set -x
	# 	export DECODE_LATTICES_LM_SCALE="${bolm_scale}"
	# 	nbest-from-lattices.sh "${BASELINE_LATTICES}" >"${baseline_nbest_file}"
	# 	set +x
	# fi

	local sentences_file="${baseline_nbest_file}.sentences"
	# if [ ! -s "${sentences_file}" ]
	# then
	# 	# Include start-of-sentence and end-of-sentence tags, so that
	# 	# empty sentences will get a score.
	# 	cut -d' ' -f5- <"${baseline_nbest_file}" |
	# 	  awk '{ print "<s>", $0, "</s>" }' \
	# 	  >"${sentences_file}"
	# fi

	local nnlm_probs_file="${baseline_nbest_file}.nnlm-probs"
	# if [ ! -s "${nnlm_probs_file}" ]
	# then
	# 	local vocab_file
	# 	local vocab_format
	# 	if [ -n "${CLASSES}" ]
	# 	then
	# 		vocab_file="${CLASSES}"
	# 		vocab_format="srilm-classes"
	# 	else
	# 		vocab_file="${EXPT_WORK_DIR}/nnlm.vocab"
	# 		vocab_format="words"
	# 	fi

	# 	# Replace LM probabilities in the n-best list.
	# 	(set -x; theanolm score \
	# 	  "${EXPT_WORK_DIR}/nnlm.h5" \
	# 	  "${sentences_file}" \
	# 	  --output-file "${nnlm_probs_file}" \
	# 	  --output "utterance-scores" \
	# 	  --log-base 10)
	# 	#    \
	# 	#   "${extra_args[@]}")
	# fi

	interpolate_nbest_scores "${nnlm_weight}" "${nnlm_scale}" "${bolm_scale}" "${test_set}"
}

# Decodes a lattice using a TheanoLM model, with given model scales and a
# weight for the TheanoLM probabilities.
#
decode_theanolm () {
	local nnlm_weight="${1:-1}"
	local lm_scale="${2:-15}"
	local test_set="${3:-eval}"
    local num_batches="${4:-1}"
    local batch_index="${5:-1}"
	local nnlm="${6:-nnlm.h5}"
	local lattices_tar="${7:-lattices}"

	[ -n "${EXPT_WORK_DIR}" ] || { echo "EXPT_WORK_DIR required." >&2; exit 1; }
	[ -n "${EXPT_NAME}" ] || { echo "EXPT_NAME required." >&2; exit 1; }
	# [ -n "${EXPT_PARAMS}" ] || { echo "EXPT_PARAMS required." >&2; exit 1; }

	local max_tokens_per_node="${MAX_TOKENS_PER_NODE:-64}"
	local beam="${BEAM:-400}"
	local recombination_order="${RECOMBINATION_ORDER:-10}"
	local run_gpu="${RUN_GPU}"

	# local lattices_tar="${PROJECT_DIR}/lattices/${test_set}/${LATTICES}.tar"
	local lattices_dir="${JOB_TMP_DIR}/lattices"
	[ -e "${lattices_dir}" ] && { echo "${lattices_dir} exists already!" >&2; exit 2; }
	echo "${lattices_dir}"
	mkdir -p "${lattices_dir}"
	tar xf "${lattices_tar}" -C "${lattices_dir}"
	local lattices_file="${lattices_dir}/lattice-list"
	sed -i "s:^:${lattices_dir}/:" "${lattices_file}"

	declare -a extra_args
	if [ -n "${SHORTLIST}" ]
	then
		extra_args+=(--shortlist)
	fi
	if [ -n "${UNK_FROM_LATTICE}" ]
	then
		extra_args+=(--unk-from-lattice)
	elif [ -n "${UNK_PENALTY}" ]
	then
		extra_args+=(--unk-penalty="${UNK_PENALTY}")
	fi
	if [ -n "${DEBUG}" ]
	then
		extra_args+=(--debug --log-level debug)
	elif [ -n "${DEBUG_LOG}" ]
	then
		extra_args+=(--log-level debug)
	fi

	source "${PROJECT_SCRIPT_DIR}/configure-theano.sh"
	export THEANO_FLAGS
	# echo "${PYTHONPATH}" | tr ':' '\n' | grep '\/Theano\/' || { echo "Theano not found in PYTHONPATH." >&2; exit 1; }
	echo "${THEANO_FLAGS}"
	theanolm version
	echo "=="

	local vocab_file
	local vocab_format
	if [ -n "${CLASSES}" ]
	then
		vocab_file="${CLASSES}"
		vocab_format="srilm-classes"
	else
		vocab_file="${EXPT_WORK_DIR}/nnlm.vocab"
		vocab_format="words"
	fi

	suffix=$(basename "${lattices_tar%.tar}")
	out_dir="${EXPT_WORK_DIR}/decode-lstm-${suffix}/${test_set}/lambda=${nnlm_weight}-lms=${lm_scale}"
	mkdir -p "${out_dir}"
	out_file="${out_dir}/${batch_index}.trn"

	# Replace LM probabilities in the n-best list.
	(set -x; ${run_gpu} theanolm decode \
	  	"${nnlm}" \
	  	--lattice-list "${lattices_file}" \
		--output-file "${out_file}" \
		--output "trn" \
		--nnlm-weight "${nnlm_weight}" \
		--lm-scale "${lm_scale}" \
		--max-tokens-per-node "${max_tokens_per_node}" \
		--beam "${beam}" \
		--recombination-order "${recombination_order}" \
		--num-jobs "${num_batches}" \
		--job "${batch_index}" \
		"${extra_args[@]}")

	# (set -x; ${run_gpu} theanolm decode \
	#   	"${EXPT_WORK_DIR}/nnlm.h5" \
	#   	--lattice-list "${lattices_file}" \
	# 	--lattice-format kaldi \
	# 	--kaldi-vocabulary "${EXPT_WORK_DIR}/lang_new/words.txt" \
	# 	--output kaldi \
	# 	--nnlm-weight "${nnlm_weight}" \
	# 	--lm-scale "${lm_scale}" \
	# 	--max-tokens-per-node "${max_tokens_per_node}" \
	# 	--beam "${beam}" \
	# 	--recombination-order "${recombination_order}" \
	# 	--num-jobs "${num_batches}" \
	# 	--job "${batch_index}" \
	# 	"${extra_args[@]}")
	# 	lattice-minimize ark:- ark:- \| \
  	# 	gzip -c \>"${out_dir}/lat.JOB.gz"

	# Convert subwords to words.
	sed -i 's/+ +//g' "${out_file}"

	rm -rf "${JOB_TMP_DIR}"

	echo "decode_theanolm finished."
}

# Decodes devel set using TheanoLM and a range of NNLM weights and LM scales.
# Has to be called from a job in an array of 80 jobs (IDs 0 - 79).
#
decode_theanolm_devel () {
	local task_id="${SLURM_ARRAY_TASK_ID}"

	if [ "${task_id}" -lt 10 ]
	then
		local nnlm_weight=0.5
		local lm_scale=11
		local batch_index="${task_id}"
	elif [ "${task_id}" -lt 20 ]
	then
		local nnlm_weight=0.5
		local lm_scale=12
		local batch_index="$(( ${task_id} - 10 ))"
	elif [ "${task_id}" -lt 30 ]
	then
		local nnlm_weight=0.5
		local lm_scale=13
		local batch_index="$(( ${task_id} - 20 ))"
	elif [ "${task_id}" -lt 40 ]
	then
		local nnlm_weight=0.5
		local lm_scale=14
		local batch_index="$(( ${task_id} - 30 ))"
	elif [ "${task_id}" -lt 50 ]
	then
		local nnlm_weight=1.0
		local lm_scale=11
		local batch_index="$(( ${task_id} - 40 ))"
	elif [ "${task_id}" -lt 60 ]
	then
		local nnlm_weight=1.0
		local lm_scale=12
		local batch_index="$(( ${task_id} - 50 ))"
	elif [ "${task_id}" -lt 70 ]
	then
		local nnlm_weight=1.0
		local lm_scale=13
		local batch_index="$(( ${task_id} - 60 ))"
	else
		local nnlm_weight=1.0
		local lm_scale=14
		local batch_index="$(( ${task_id} - 70 ))"
	fi

	decode_theanolm "${nnlm_weight}" "${lm_scale}" devel 10 "${batch_index}"
}

collect_transcripts () {
	local test_set="${1:-eval}"
	local decode_dir="${2:-decode-lstm}"

	[ -n "${EXPT_WORK_DIR}" ] || { echo "EXPT_WORK_DIR required." >&2; exit 1; }
	[ -n "${RESULTS_DIR}" ] || { echo "RESULTS_DIR required." >&2; exit 1; }

	local max_tokens_per_node="${MAX_TOKENS_PER_NODE:-64}"
	local beam="${BEAM:-400}"
	local recombination_order="${RECOMBINATION_ORDER:-10}"
	# local random_seed="${RANDOM_SEED}"

	for in_dir in "${EXPT_WORK_DIR}/${decode_dir}/${test_set}/"*
	do
		if [ ! -d "${in_dir}" ]
		then
			continue
		fi
		params=$(basename "${in_dir}")
		out_dir="${RESULTS_DIR}-lats-tpn=${max_tokens_per_node}-beam=${beam}-order=${recombination_order}/${test_set}"
		mkdir -p "${out_dir}"
		out_file="${out_dir}/${params}.trn"
		echo "${out_file}"
		cat "${in_dir}/"*.trn |
		  sed 's:<s> ::g' |
		  sed 's:</s> ::g' \
		  >"${out_file}"
	done
}

perplexity_kn () {
	if [ -n "${1}" ]
	then
		local model_name=("${1}")
	else
		local model_name="kn"
	fi

	[ -n "${EXPT_SCRIPT_DIR}" ] || { echo "EXPT_SCRIPT_DIR required." >&2; exit 1; }
	[ -n "${EXPT_WORK_DIR}" ] || { echo "EXPT_WORK_DIR required." >&2; exit 1; }

	local model_file="${LM}"
	local ngram_order="${NGRAM_ORDER:-4}"
	[ -s "${model_file}" ] || model_file="${EXPT_WORK_DIR}/${model_name}.arpa"
	[ -s "${model_file}" ] || model_file="${model_file}.gz"
	[ -s "${model_file}" ] || { echo "Language model file not found." >&2; exit 1; }

	declare -a args
	args=(-order "${ngram_order}" -lm "${model_file}" -debug 0)
	[ -n "${CLASSES}" ] && args+=(-classes "${CLASSES}" -simple-classes)

	set -x
	ngram "${args[@]}" -ppl "${DEVEL_FILE}" |
	  tee "${EXPT_SCRIPT_DIR}/perplexity-devel.txt"
	ngram "${args[@]}" -ppl "${EVAL_FILE}" |
	  tee "${EXPT_SCRIPT_DIR}/perplexity-eval.txt"
	set +x
}

perplexity_kn_morph () {
	[ -n "${EXPT_WORK_DIR}" ] || { echo "EXPT_WORK_DIR required." >&2; exit 1; }

	local model_file="${LM}"
	[ -s "${model_file}" ] || model_file="${EXPT_WORK_DIR}/kn.arpa"
	[ -s "${model_file}" ] || model_file="${model_file}.gz"
	[ -s "${model_file}" ] || { echo "Language model file not found." >&2; exit 1; }

	declare -a args
	args=(--arpa="${model_file}" --unk='<unk>' --unkwarn)

	if [ "${SUBWORD_STYLE}" = "prefix-affix" ]
	then
		set -x
		perplexity "${args[@]}" --init_hist=1 --mb=<(echo $'^<s>\n+$') \
                           "${DEVEL_FILE}" "${EXPT_SCRIPT_DIR}/perplexity-devel.txt"
		perplexity "${args[@]}" --init_hist=1 --mb=<(echo $'^<s>\n+$') \
                           "${EVAL_FILE}" "${EXPT_SCRIPT_DIR}/perplexity-eval.txt"
		set +x
	else
		set -x
		perplexity "${args[@]}" --init_hist=2 --wb=<(echo '<w>') \
                           "${DEVEL_FILE}" "${EXPT_SCRIPT_DIR}/perplexity-devel.txt"
		perplexity "${args[@]}" --init_hist=2 --wb=<(echo '<w>') \
                           "${EVAL_FILE}" "${EXPT_SCRIPT_DIR}/perplexity-eval.txt"
		set +x
	fi
}

perplexity_theanolm () {
	[ -n "${EXPT_WORK_DIR}" ] || { echo "EXPT_WORK_DIR required." >&2; exit 1; }

	declare -a extra_args
	[ -n "${SHORTLIST}" ] && extra_args+=(--shortlist)
	[ -n "${SUBWORD_STYLE}" ] && extra_args+=(--subwords "${SUBWORD_STYLE}")
	if [ -n "${DEBUG}" ]
	then
		extra_args+=(--debug --log-level debug)
	elif [ -n "${DEBUG_LOG}" ]
	then
		extra_args+=(--log-level debug)
	fi

	source "${PROJECT_SCRIPT_DIR}/configure-theano.sh"
	export THEANO_FLAGS
	# echo "${PYTHONPATH}" | tr ':' '\n' | grep '\/Theano\/' || { echo "Theano not found in PYTHONPATH." >&2; exit 1; }
	echo "${THEANO_FLAGS}"
        theanolm version
        echo "=="

	local vocab_file
	local vocab_format
	if [ -n "${CLASSES}" ]
	then
		vocab_file="${CLASSES}"
		vocab_format="srilm-classes"
	else
		vocab_file="${EXPT_WORK_DIR}/nnlm.vocab"
		vocab_format="words"
	fi

	set -x
	theanolm score \
	  "${EXPT_WORK_DIR}/nnlm.h5" \
	  "${DEVEL_FILE}" \
	  --output-file "${EXPT_SCRIPT_DIR}/perplexity-devel-.txt" \
	  --output "perplexity" \
	  --exclude-unk \
	  "${extra_args[@]}"
	theanolm score \
	  "${EXPT_WORK_DIR}/nnlm.h5" \
	  "${EVAL_FILE}" \
	  --output-file "${EXPT_SCRIPT_DIR}/perplexity-eval-.txt" \
	  --output "perplexity" \
	  --exclude-unk \
	  "${extra_args[@]}"
	set +x
}

word_scores_kn () {
	[ -n "${EXPT_WORK_DIR}" ] || { echo "EXPT_WORK_DIR required." >&2; exit 1; }

	local model_file="${LM}"
	local ngram_order="${NGRAM_ORDER:-4}"
	[ -s "${model_file}" ] || model_file="${EXPT_WORK_DIR}/kn-prune=5e-10.arpa"
	[ -s "${model_file}" ] || model_file="${model_file}.gz"
	[ -s "${model_file}" ] || model_file="${EXPT_WORK_DIR}/kn.arpa"
	[ -s "${model_file}" ] || model_file="${model_file}.gz"
	[ -s "${model_file}" ] || { echo "Language model file not found." >&2; exit 1; }

	declare -a args
	args=(-order "${ngram_order}" -lm "${model_file}" -debug 0)
	[ -n "${CLASSES}" ] && args+=(-classes "${CLASSES}" -simple-classes)

	set -x
	ngram "${args[@]}" -ppl "${DEVEL_FILE}" -debug 2
	ngram "${args[@]}" -ppl "${EVAL_FILE}" -debug 2
	set +x
}

word_scores_theanolm () {
	[ -n "${EXPT_WORK_DIR}" ] || { echo "EXPT_WORK_DIR required." >&2; exit 1; }

	declare -a extra_args
	[ -n "${SHORTLIST}" ] && extra_args+=(--shortlist)
	[ -n "${SUBWORD_STYLE}" ] && extra_args+=(--subwords "${SUBWORD_STYLE}")

	source "${PROJECT_SCRIPT_DIR}/configure-theano.sh"
	export THEANO_FLAGS
	# echo "${PYTHONPATH}" | tr ':' '\n' | grep '\/Theano\/' || { echo "Theano not found in PYTHONPATH." >&2; exit 1; }
	echo "${THEANO_FLAGS}"
	which theanolm
        theanolm version
        echo "=="

	local vocab_file
	local vocab_format
	if [ -n "${CLASSES}" ]
	then
		vocab_file="${CLASSES}"
		vocab_format="srilm-classes"
	else
		vocab_file="${EXPT_WORK_DIR}/nnlm.vocab"
		vocab_format="words"
	fi

	set -x
	theanolm score \
	  "${EXPT_WORK_DIR}/nnlm.h5" \
	  "${DEVEL_FILE}" \
	  --output-file "${EXPT_WORK_DIR}/word-scores-devel.txt" \
	  --output "word-scores" \
	  --exclude-unk \
	  --log-level debug \
	  "${extra_args[@]}"
	theanolm score \
	  "${EXPT_WORK_DIR}/nnlm.h5" \
	  "${EVAL_FILE}" \
	  --output-file "${EXPT_WORK_DIR}/word-scores-eval.txt" \
	  --output "word-scores" \
	  --exclude-unk \
	  --log-level debug \
	  "${extra_args[@]}"
	set +x
}
