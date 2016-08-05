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
cmdarg "o:" "outdir" "Output directory"
cmdarg "w:" "workdir" "Path to working directory"
## optional inputs
cmdarg "g:" "hp" "High-pass filter in seconds (-1 = skip)" "-1"
cmdarg "p:" "lp" "Low-pass filter in seconds (-1 = skip)" "-1"
cmdarg "s:" "fwhm" "Smoothness level in mm (0 = skip)" "0"
cmdarg "k" "keepwdir" "Keep working directory" false
cmdarg "m" "mcdir" "Previously run mc directory" ""
cmdarg "f" "force" "Will overwrite any existing output" false
cmdarg "l?" "log" "Log file"
## parse
cmdarg_parse "$@"
[ $# == 0 ] && exit

#### Set Variables ####

inputs=( ${cmdarg_cfg['inputs']} )
outdir=${cmdarg_cfg['outdir']}
workdir=${cmdarg_cfg['workdir']}
hp=${cmdarg_cfg['hp']}
lp=${cmdarg_cfg['lp']}
fwhm=${cmdarg_cfg['fwhm']}
keepwdir=${cmdarg_cfg['keepwdir']}
mcdir=${cmdarg_cfg['mcdir']}
overwrite=${cmdarg_cfg['force']}
_LOG_FILE=${cmdarg_cfg['log']}
[ ! -z $_LOG_FILE ] && _LOG_FILE=$( readlink -f ${_LOG_FILE} ) # absolute path (if exists)

ext=".nii.gz"
workprefix="prefiltered_func_data"

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

check_inputs "${inputs[@]}"
[ ! -z $mcdir ] && check_inputs ${mcdir}

[ ! -e $outdir ] && log_cmd "mkdir -p $outdir"
[ ! -e $workdir ] && log_cmd "mkdir -p $workdir"

# get full paths since changing paths
workdir=$( readlink -f ${workdir} )
outdir=$( readlink -f ${outdir} )
for (( i = 0; i < ${#inputs[@]}; i++ )); do
  inputs[$i]=$( readlink -f ${inputs[$i]} )
done

# recheck inputs
check_inputs ${inputs[@]}

# change directory?
log_cmd2 "cd $workdir"


# Runs
nruns=${#inputs[@]}
runs=(`for x in $(seq 1 $nruns); do echo $x; done`)
pruns=(`for x in $(seq 1 $nruns); do echo $x |awk '{printf "%02d ", $1}'; done`)

#--- MOTION CORRECT ---#
log_echo "===="
log_echo "Motion Correct"

if [ -z $mcdir ]; then
  cmd_str="-o '${outdir}/mc/func' -w '${outdir}/mc_work'"
  [ $keepwdir == false ] && cmd_str="${cmd_str} -k"
  log_cmd "bash ${GUNTHERDIR}/func01_motion_correct.sh ${cmd_str} -i '${inputs[@]}'"
else
  log_tcmd "ln -sf ${mcdir} ${outdir}/mc"
fi

#--- SKULL STRIP ---#
log_echo "===="
log_echo "Skull Strip"

log_tcmd "bet2 ${outdir}/mc/func_mean mask -f 0.3 -n -m"
log_tcmd "immv mask_mask mask1"

log_echo "Apply initial masks"
for run in ${pruns[@]}; do
  log_echo "...run ${run}"
  log_cmd "fslmaths ${outdir}/mc/func_run${run}_volreg${ext} -mas mask1 ${workprefix}_bet_run${run}"
done

log_echo "Get the max of the robust range"
robust_max=0
for run in ${pruns[@]}; do
  temp=`fslstats ${workprefix}_bet_run${run} -p 2 -p 98 | awk '{print $2}'`
  temp2=`echo $temp '>' $robust_max |bc -l`
  if [ $temp2 == 1 ]; then robust_max=$temp; fi
done
log_echo "... robust_max = ${robust_max}"

log_echo "Threshold background signal using 10% of robust range"
robust_max_thr=`echo "$robust_max * 0.1" | bc -l`
for run in ${pruns[@]}; do
  log_cmd "fslmaths ${workprefix}_bet_run${run} -thr ${robust_max_thr} -Tmin -bin mask2_run${run} -odt char"
done
log_tcmd "3dMean -mask_inter -prefix mask2${ext} mask2_run*${ext}"

log_echo "Get median value within the second more constrained mask"

median_vals=()
for run in ${pruns[@]}; do
  median_vals[runs-1]=`fslstats ${workprefix}_bet_run${run} -k mask2 -p 50`
done
median_val=`echo -e "${medians[@]}" | sort -n | awk '{arr[NR]=$1} END { if (NR%2==1) print arr[(NR+1)/2]; else print (arr[NR/2]+arr[NR/2+1])/2}'`
log_echo "... median = ${median_val}"

log_echo "Dilate the constrained mask for the final liberal mask"
log_tcmd "fslmaths mask2 -dilF mask3"

log_echo "Apply final brain mask"
for run in ${pruns[@]}; do
  log_cmd "fslmaths ${outdir}/mc/func_run${run}_volreg${ext} -mas mask3 ${workprefix}_thresh_run${run} -odt float"
done

log_echo "Mean functional"
for run in ${pruns[@]}; do
  log_cmd "fslmaths ${workprefix}_thresh_run${run} -Tmean mean_func_run${run}"
done
log_tcmd "3dMean -overwrite -prefix mean_func${ext} mean_func_run*${ext}"


#--- SMOOTHING ---#
log_echo "===="
log_echo "Smoothing"

if [ $fwhm == 0 ]; then
  log_echo "Skipping smoothing"
  for run in ${pruns[@]}; do
    log_cmd "ln -sf ${workprefix}_thresh_run${run}${ext} ${workprefix}_smooth_run${run}${ext}"
  done
else
  log_echo "Smoothing to ${fwhm}mm"
  brightness_thr=`echo "$median_val * 0.75" |bc -l`
  sigma=`echo "$fwhm / 1.55185 " |bc -l`  # sqrt(8 * log(2))=1.55185
  for run in ${pruns[@]}; do
    log_cmd "susan ${workprefix}_thresh_run${run} ${brightness_thr} ${sigma} 3 1 1 mean_func ${brightness_thr} ${workprefix}_smooth_run${run}"
    log_cmd "fslmaths ${workprefix}_smooth_run${run} -mas mask3 ${workprefix}_smooth_run${run}"
  done
fi


#--- INTENSITY NORMALIZATION ---#
log_echo "===="
log_echo "Intensity Normalization"

log_echo "Mean 4D intensity normalization"
for run in ${pruns[@]}; do
  log_cmd "fslmaths ${workprefix}_smooth_run${run} -ing 10000 ${workprefix}_intnorm_run${run}"
done


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

if [ $hp == -1 -a $lp == "-1" ]; then
  log_echo "Skipping filter"
  log_tcmd "ln -sf ${workprefix}_intnorm_run${run} ${workprefix}_tempfilt_run${run}"
else
  log_echo "Filtering"
  for run in ${pruns[@]}; do
    log_cmd "fslmaths ${workprefix}_intnorm_run${run} -Tmean ${workprefix}_tempMean_run${run}"
    log_cmd "fslmaths ${workprefix}_intnorm_run${run} -bptf ${hp_sigma} ${lp_sigma} -add ${workprefix}_tempMean_run${run} ${workprefix}_tempfilt_run${run}"
  done
fi


#--- End ---#
log_echo "===="
log_echo "Copy output files"

log_echo "Mean Functional (also known here as the example functional)"
log_tcmd "fslmaths mean_func${ext} ${outdir}/mean_func${ext}"
log_tcmd "ln -sf ${outdir}/mean_func${ext} ${outdir}/example_func${ext}"

log_echo "Mask"
log_tcmd "fslmaths mask3 ${outdir}/mask"

log_echo "Preprocessed functional runs"
for run in ${pruns[@]}; do
  log_cmd "fslmaths ${workprefix}_tempfilt_run${run} ${outdir}/filtered_func_run${run}"
done


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

