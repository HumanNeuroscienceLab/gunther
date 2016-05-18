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

cmdarg_info "header" "Script for functional pre-processing"
cmdarg_info "author" "McCarthy Lab <some address>"
## required inputs
cmdarg "i:" "inputs" "Path to functional runs to preprocess"
cmdarg "o:" "outprefix" "Output prefix"
## optional inputs
cmdarg "g:" "hp" "High-pass filter in seconds (-1 = skip)" "-1"
cmdarg "p:" "lp" "Low-pass filter in seconds (-1 = skip)" "-1"
cmdarg "f" "force" "Will overwrite any existing output" false
cmdarg "l?" "log" "Log file"
## parse
cmdarg_parse "$@"
[ $# == 0 ] && exit

#### Set Variables ####

inputs=( ${cmdarg_cfg['inputs']} )
outdir=${cmdarg_cfg['outdir']}
hp=${cmdarg_cfg['hp']}
lp=${cmdarg_cfg['lp']}
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


#--- Band-Pass Filter ---#
log_echo "===="
log_echo "Band-Pass Filter"

if [ $hp == "-1" ]; then
  hp_sigma=-1
else
  hp_sigma=`echo "$hp/2.0"|bc -l`
fi

if [ $lp == -1 ]; then
  lp_sigma=-1
else
  lp_sigma=`echo "$lp/2.0" | bc -l`
fi

# Not sure if this is needed?
if [ $hp == -1 -a $lp == "-1" ]; then
  log_echo "Skipping filter"
  for run in ${pruns[@]}; do
    log_echo "...run ${run}"
    log_tcmd "ln -sf ${inputs[run]} ${outprefix}_run${run}"
  done
else
  log_echo "Filtering"
  for run in ${pruns[@]}; do
    log_echo "...run ${run}"
    log_cmd "fslmaths ${inputs[run]} -Tmean ${outprefix}_tempMean_run${run}"
    log_cmd "fslmaths ${inputs[run]} -bptf ${hp_sigma} ${lp_sigma} -add ${outprefix}_tempMean_run${run} ${outprefix}_run${run}" "${outprefix}_run${run}${ext}"
    log_cmd "rm ${outprefix}_tempMean_run${run}${ext}"
  done
fi


#--- End ---#

# Unset AFNI_DECONFLICT
if [ $overwrite == true ]; then
  export AFNI_DECONFLICT=$old_afni_deconflict
fi

