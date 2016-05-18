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
cmdarg "m:" "mask" "Brain mask"
cmdarg "e:" "meanfunc" "Mean or some example functional to base smoothing area"
## optional inputs
cmdarg "s:" "fwhm" "Smoothness level in mm (0 = skip)" "0"
cmdarg "f" "force" "Will overwrite any existing output" false
cmdarg "l?" "log" "Log file"
## parse
cmdarg_parse "$@"
[ $# == 0 ] && exit

#### Set Variables ####

inputs=( ${cmdarg_cfg['inputs']} )
outprefix=${cmdarg_cfg['outprefix']}
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
check_inputs $mask $meanfunc

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
pruns=(`for x in $(seq 1 $nruns); do echo $x |awk '{printf "%02d ", $1}'; done`)


#--- SMOOTHING ---#

log_echo "===="
log_echo "Smoothing"

log_echo "Calculate median value for thresholding"
median_vals=()
for run in ${pruns[@]}; do
  median_vals[run-1]=`fslstats ${inputs[run]} -k ${mask} -p 50`
done
median_val=`echo -e "${medians[@]}" | sort -n | awk '{arr[NR]=$1} END { if (NR%2==1) print arr[(NR+1)/2]; else print (arr[NR/2]+arr[NR/2+1])/2}'`
log_echo "... median = ${median_val}"

log_echo "Smoothing to ${fwhm}mm"
brightness_thr=`echo "$median_val * 0.75" | bc -l`
sigma=`echo "$fwhm / 1.55185 " | bc -l`  # sqrt(8 * log(2))=1.55185
for run in ${pruns[@]}; do
  log_cmd "susan ${workprefix}_thresh_run${run} ${brightness_thr} ${sigma} 3 1 1 ${meanfunc} ${brightness_thr} ${outprefix}_run${run}" "${outprefix}_run${run}${ext}"
  log_cmd "fslmaths ${outprefix}_smooth_run${run} -mas ${mask} ${outprefix}_run${run}" "${outprefix}_run${run}${ext}"
done


# Unset AFNI_DECONFLICT
if [ $overwrite == true ]; then
  export AFNI_DECONFLICT=$old_afni_deconflict
fi

