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

cmdarg_info "header" "Script for temporal filtering"
cmdarg_info "author" "McCarthy Lab <some address>"
## required inputs
cmdarg "i:" "input" "Path to functional runs to preprocess"
cmdarg "o:" "output" "Output temporally filtered file"
## optional inputs
cmdarg "g:" "hp" "High-pass filter in seconds (-1 = skip)" "-1"
cmdarg "p:" "lp" "Low-pass filter in seconds (-1 = skip)" "-1"
cmdarg "f" "force" "Will overwrite any existing output" false
cmdarg "l?" "log" "Log file"
## parse
cmdarg_parse "$@"
[ $# == 0 ] && exit


#### Set Variables ####

input=( ${cmdarg_cfg['input']} )
output=${cmdarg_cfg['output']}
hp=${cmdarg_cfg['hp']}
lp=${cmdarg_cfg['lp']}
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

check_inputs ${input}
check_outputs ${output}

# get full paths since changing paths
input=$( readlink -f ${input} )
output=$( readlink -f ${output} )

# recheck inputs
check_inputs ${input}
check_outputs ${output}


#--- Band-Pass Filter ---#

log_echo "===="
log_echo "Band-Pass Filter"

if [ $hp == -1 ]; then
  hp_sigma=-1
else
  hp_sigma=`echo "$hp/2.0" | bc -l`
fi

if [ $lp == -1 ]; then
  lp_sigma=-1
else
  lp_sigma=`echo "$lp/2.0" | bc -l`
fi

# Not sure if this is needed?
log_echo "Filtering"
tmpMean=`mktemp --suffix '.nii.gz' 'tempMean.XXXXXXXX'`
log_tcmd "fslmaths ${input} -Tmean ${tmpMean}"
log_tcmd "fslmaths ${input} -bptf ${hp_sigma} ${lp_sigma} -add ${tmpMean} ${output}" "${output}"
log_tcmd "rm ${tmpMean}"


#--- End ---#

# Unset AFNI_DECONFLICT
if [ $overwrite == true ]; then
  export AFNI_DECONFLICT=$old_afni_deconflict
fi

