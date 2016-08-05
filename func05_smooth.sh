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
cmdarg "i:" "input" "Path to functional runs to preprocess"
cmdarg "o:" "output" "Output smoothed file"
cmdarg "m:" "mask" "Brain mask"
cmdarg "e:" "meanfunc" "Mean or some example functional to base smoothing area"
## optional inputs
cmdarg "b:" "brightness" "Brightness threshold to smooth within (default will be the 75% of the median value)."
cmdarg "s:" "fwhm" "Smoothness level in mm (0 = skip)" "0"
cmdarg "f" "force" "Will overwrite any existing output" false
cmdarg "l?" "log" "Log file"
## parse
cmdarg_parse "$@"
[ $# == 0 ] && exit

#### Set Variables ####

input=( ${cmdarg_cfg['input']} )
output=${cmdarg_cfg['output']}
mask=${cmdarg_cfg['mask']}
meanfunc=${cmdarg_cfg['meanfunc']}
brightness_thr=${cmdarg_cfg['brightness']}
fwhm=${cmdarg_cfg['fwhm']}
overwrite=${cmdarg_cfg['force']}
_LOG_FILE=${cmdarg_cfg['log']}
[ ! -z $_LOG_FILE ] && _LOG_FILE=$( readlink -f ${_LOG_FILE} ) # absolute path (if exists)

ext=".nii.gz"

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

check_inputs ${input} ${mask} ${meanfunc}
check_outputs ${output}

# get full paths since changing paths
input=$( readlink -f ${input} )
mask=$( readlink -f ${mask} )
meanfunc=$( readlink -f ${meanfunc} )
output=$( readlink -f ${output} )

# recheck inputs
check_inputs ${input} ${mask} ${meanfunc}
check_outputs ${output}


#--- SMOOTHING ---#

log_echo "===="
log_echo "Smoothing"

if [[ -z ${brightness_thr} ]]; then
  log_echo "Calculate median value for thresholding"
  median_val=`fslstats ${input} -k ${mask} -p 50`
  log_echo "... median = ${median_val}"
  brightness_thr=`echo "$median_val * 0.75" | bc -l`
fi
log_echo "... brightness_thr = ${brightness_thr}"

log_echo "Smoothing to ${fwhm}mm"
sigma=`echo "$fwhm / 1.55185 " | bc -l`  # sqrt(8 * log(2))=1.55185
log_tcmd "susan ${input} ${brightness_thr} ${sigma} 3 1 1 $( remove_ext ${meanfunc} ) ${brightness_thr} $( remove_ext ${output} )" "${output}"
log_tcmd "fslmaths ${output} -mas ${mask} ${output}" "${output}"

# Unset AFNI_DECONFLICT
if [ $overwrite == true ]; then
  export AFNI_DECONFLICT=$old_afni_deconflict
fi

