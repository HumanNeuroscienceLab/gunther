#!/usr/bin/env bash

# Goals
# -----
# 
# For this script, a user should only need to run the following:
#
#     $0 -o output-directory -w working-directory -i func-file1 [... func-fileN] [--fwhm X] [--hp X]
#
# Environmental defaults for the freesurfer subject directory and task directory
# and each of the output paths should take over.
#
# All the commands with some useful logging information should all be saved.


#### Usage ####

source ${GUNTHERDIR}/include/cmdarg.sh

cmdarg_info "header" "Script for intensity normalization"
cmdarg_info "author" "McCarthy Lab <some address>"
## required inputs
cmdarg "i:" "inputs" "Path to functional runs to preprocess"
cmdarg "o:" "outprefix" "Output prefix"
## optional inputs
cmdarg "f" "force" "Will overwrite any existing output" false
cmdarg "l?" "log" "Log file"
## parse
cmdarg_parse "$@"
[ $# == 0 ] && exit


#### Set Variables ####

inputs=( ${cmdarg_cfg['inputs']} )
outprefix=${cmdarg_cfg['outprefix']}
overwrite=${cmdarg_cfg['force']}
_LOG_FILE=${cmdarg_cfg['log']}
[ ! -z $_LOG_FILE ] && _LOG_FILE=$( readlink -f ${_LOG_FILE} ) # absolute path (if exists)

ext=".nii.gz"
outprefix=$( readlink -f ${outprefix} )
outdir=$( dirname ${outprefix} )

old_afni_deconflict=$AFNI_DECONFLICT
if [ $overwrite == true ]; then
  export AFNI_DECONFLICT="OVERWRITE"
fi


#### Log ####

source ${GUNTHERDIR}/include/log.sh

check_logfile

log_echo ""
log_echo "RUNNING: $0 $@"


#### Checks/Setup ####

source ${GUNTHERDIR}/include/io.sh

check_inputs ${inputs[@]}

[ ! -e $outdir ] && log_cmd "mkdir -p $outdir"

# get full paths since changing paths
outdir=$( readlink -f ${outdir} )
for (( i = 0; i < ${#inputs[@]}; i++ )); do
  inputs[$i]=$( readlink -f ${inputs[$i]} )
done

# recheck inputs
check_inputs ${inputs[@]}

# change directory?
log_cmd2 "cd $outdir"


# Runs
nruns=${#inputs[@]}
pruns=(`for x in $(seq 1 $nruns); do echo $x | awk '{printf "%02d ", $1}'; done`)


#--- INTENSITY NORMALIZATION ---#
log_echo "===="
log_echo "Intensity Normalization"

log_echo "Mean 4D intensity normalization"
for run in ${pruns[@]}; do
  log_echo "...run ${run}"
  log_cmd "fslmaths ${inputs[run]} -ing 10000 ${outprefix}_run${run}" "${outprefix}_run${run}${ext}"
done

# Unset AFNI_DECONFLICT
if [ $overwrite == true ]; then
  export AFNI_DECONFLICT=$old_afni_deconflict
fi

