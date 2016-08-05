#!/usr/bin/env bash

# Goals
# -----
# 
# For this script, a user should only need to run the following:
#
#     $0 -o output-directory -w working-directory -i "func-file1 [... func-fileN]"
#
# Environmental defaults for the freesurfer subject directory and task directory
# and each of the output paths should take over.
#
# All the commands with some useful logging information should all be saved.


#### Usage ####

source ${GUNTHERDIR}/include/cmdarg.sh

cmdarg_info "header" "Script for functional skull-strip"
cmdarg_info "author" "McCarthy Lab <some address>"
## required inputs
cmdarg "i:" "inputs" "Path to functional runs to preprocess"
cmdarg "o:" "outprefix" "Output prefix for final brain mask (*_mask) and masked functional runs (*_run*)"
cmdarg "w:" "workdir" "Path to working directory"
## optional inputs
cmdarg "k" "keepwdir" "Keep working directory" false
cmdarg "f" "force" "Will overwrite any existing output" false
cmdarg "l?" "log" "Log file"
## parse
cmdarg_parse "$@"
[ $# == 0 ] && exit


#### Set Variables ####

inputs=( ${cmdarg_cfg['inputs']} )
outprefix=${cmdarg_cfg['outprefix']}
workdir=${cmdarg_cfg['workdir']}
keepwdir=${cmdarg_cfg['keepwdir']}
overwrite=${cmdarg_cfg['force']}
_LOG_FILE=${cmdarg_cfg['log']}
[ ! -z $_LOG_FILE ] && _LOG_FILE=$( readlink -f ${_LOG_FILE} ) # absolute path (if exists)

ext=".nii.gz"
workprefix="prefunc"
outprefix=$( readlink -m ${outprefix} )
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

# get full paths since changing paths
workdir=$( readlink -m ${workdir} )
outdir=$( readlink -m ${outdir} )
for (( i = 0; i < ${#inputs[@]}; i++ )); do
  inputs[$i]=$( readlink -f ${inputs[$i]} )
done

[ ! -e $workdir ] && log_cmd "mkdir -p $workdir"
[ ! -e $outdir ] && log_cmd "mkdir -p $outdir"

# recheck inputs
check_inputs ${inputs[@]}

# change directory
log_cmd2 "cd $workdir"

# Runs
nruns=${#inputs[@]}
pruns=(`for x in $(seq 1 $nruns); do echo $x | awk '{printf "%02d ", $1}'; done`)


#--- SKULL STRIP ---#

log_echo "===="
log_echo "Skull Strip"


log_echo "== Mean Functional"

log_echo "Generate the mean functional for skull stripping"
for run in ${pruns[@]}; do
  log_echo "...run ${run}"
  i=$( echo "$run - 1" | bc -l )
  log_tcmd "3dTstat -mean -prefix ${workprefix}_mean_run${run}${ext} ${inputs[i]}"
done

log_echo "Combine mean EPIs from each run"
log_tcmd "3dTcat -prefix ${workprefix}_mean${ext} ${workprefix}_mean_run*${ext}"


log_echo "== Strip Step-1"

log_echo "Initial skull strip"
log_tcmd "bet2 ${workprefix}_mean${ext} mask -f 0.3 -n -m" "mask${ext}"
log_tcmd "immv mask_mask mask1" # fancy mv that figures out extension; and this is in working directory

log_echo "Apply initial masks"
for run in ${pruns[@]}; do
  log_echo "...run ${run}"
  i=$( echo "$run - 1" | bc -l )
  log_tcmd "3dcalc -a ${inputs[i]} -b mask1${ext} -expr 'a*step(b)' -prefix ${workprefix}_bet_run${run}${ext}"
done


log_echo "== Strip Step-2"

log_echo "Get the max of the robust range"
robust_max=0
for run in ${pruns[@]}; do
  temp=`fslstats ${workprefix}_bet_run${run} -p 2 -p 98 | awk '{print $2}'`
  temp2=`echo $temp '>' $robust_max | bc -l`
  if [ $temp2 == 1 ]; then robust_max=$temp; fi
done
log_echo "... robust_max = ${robust_max}"

log_echo "Threshold background signal using 10% of robust range"
robust_max_thr=`echo "$robust_max * 0.1" | bc -l`
log_echo "... threshold = ${robust_max_thr}"
for run in ${pruns[@]}; do
  log_echo "...run ${run}"
  log_tcmd "fslmaths ${workprefix}_bet_run${run} -thr ${robust_max_thr} -Tmin -bin mask2_run${run} -odt char" "mask2_run${run}${ext}"
done
log_tcmd "3dMean -mask_inter -prefix mask2${ext} mask2_run*${ext}"


log_echo "== Strip Step-3"

log_echo "Dilate the constrained mask for the final liberal mask"
log_tcmd "fslmaths mask2 -dilF mask3" "mask3${ext}"

log_echo "Apply final brain mask"
for run in ${pruns[@]}; do
  log_echo "...run ${run}"
  i=$( echo "$run - 1" | bc -l )
  log_tcmd "3dcalc -a ${inputs[i]} -b mask3${ext} -expr 'a*step(b)' -prefix ${outprefix}_run${run}${ext} -datum float"
  log_tcmd "ln -sf ${outprefix}_run${run}${ext} ${workprefix}_thresh_run${run}${ext}"
done

log_tcmd "cp mask3${ext} ${outprefix}_mask${ext}" "${outprefix}_mask${ext}"


log_echo "== Mean Functional"
for run in ${pruns[@]}; do
  log_echo "...run ${run}"
  log_tcmd "3dTstat -mean -prefix mean_func_run${run}${ext} ${workprefix}_thresh_run${run}${ext}"
done
log_tcmd "3dMean -overwrite -prefix ${outprefix}_mean${ext} mean_func_run*${ext}"


#--- End ---#

#log_echo "===="
#log_echo "Copy output files"
#
#log_echo "Mean Functional (also known here as the example functional)"
#log_tcmd "fslmaths mean_func${ext} ${outdir}/mean_func${ext}"
#log_tcmd "ln -sf ${outdir}/mean_func${ext} ${outdir}/example_func${ext}"
#
#log_echo "Mask"
#log_tcmd "fslmaths mask3 ${outdir}/mask"
#
#log_echo "Preprocessed functional runs"
#for run in ${pruns[@]}; do
#  log_cmd "fslmaths ${workprefix}_tempfilt_run${run} ${outdir}/filtered_func_run${run}"
#done

log_echo "Clean up"
# clean up the working directory
if [ $keepwdir == false ]; then
  log_echo "Removing working directory"
  log_cmd "cd $outdir"
  log_cmd "rm ${workdir}/*"
  log_cmd "rmdir ${workdir}"
fi

# Unset AFNI_DECONFLICT
if [ $overwrite == true ]; then
  export AFNI_DECONFLICT=$old_afni_deconflict
fi

