#!/usr/bin/env bash

#  This script gets the mean across a set of functional images by
#  first getting a mean for each motion corrected run
#  and then getting the mean of the motion corrected means
#
# For this script, a user should only need to run the following:
#
#     $0 -o outprefix -w working-directory -i func-file1 [... func-fileN]
#
#
# All the commands with some useful logging information should all be saved.


#### Usage ####

source ${GUNTHERDIR}/include/cmdarg.sh

cmdarg_info "header" "Script for functional motion correction"
cmdarg_info "author" "McCarthy Lab <some address>"
## required inputs
cmdarg "i:" "inputs" "Path to functional runs to motion correct"
cmdarg "o:" "output" "Output mean functional file"
cmdarg "w:" "workdir" "Path to working directory"
## optional inputs
cmdarg "n" "njobs" "Number of parallel jobs" 1
cmdarg "k" "keepwdir" "Keep working directory" false
cmdarg "f" "force" "Will overwrite any existing output" false
cmdarg "l?" "log" "Log file"
## parse
cmdarg_parse "$@"
[ $# == 0 ] && exit

#### Set Variables ####

inputs=( ${cmdarg_cfg['inputs']} )
output=${cmdarg_cfg['output']}
workdir=${cmdarg_cfg['workdir']}
keepwdir=${cmdarg_cfg['keepwdir']}
overwrite=${cmdarg_cfg['force']}
njobs==${cmdarg_cfg['njobs']}
_LOG_FILE=${cmdarg_cfg['log']}
[ ! -z $_LOG_FILE ] && _LOG_FILE=$( readlink -f ${_LOG_FILE} ) # absolute path (if exists)

ext=".nii.gz"

nruns=${#inputs[@]}
outdir=$(dirname $outprefix)
echo "$nruns runs"

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
check_outputs $overwrite "$workdir" "$output"
[ ! -e $workdir ] && mkdir -p $workdir

# get full paths since changing paths
workdir=$( readlink -f ${workdir} )
output=$( readlink -f ${output} )
for (( i = 0; i < ${#inputs[@]}; i++ )); do
  inputs[$i]=$( readlink -f ${inputs[$i]} )
done

# recheck inputs
check_inputs ${inputs[@]}

# Work in the working directory
log_cmd2 "cd $workdir"


###
# First Pass
###

log_echo "=== First Pass" 

# Get the range of scan numbers with padding of 2
ris=()
for i in `seq 1 $nruns`; do
  ri=`echo $i | awk '{printf "%02d", $1}'`
  ris+=($ri)
done

log_echo "Generate motion-corrected mean EPIs"

log_echo "...mean EPI of non-motion corrected data"
log_tcmd "parallel --xapply --no-notice -j $njobs --eta 3dTstat -mean -prefix iter0_mean_epi_r{1}${ext} {2} ::: ${ris[*]} ::: ${inputs[*]}"

log_echo "...apply motion correction to mean EPI"
log_tcmd "parallel --xapply --no-notice -j $njobs --eta 3dvolreg -verbose -zpad 4 -base iter0_mean_epi_r{1}${ext} -prefix iter0_epi_volreg_r{1}${ext} -cubic {2} ::: ${ris[*]} ::: ${inputs[*]}"

log_echo "...new mean EPI of motion-corrected data"
log_tcmd "parallel --xapply --no-notice -j $njobs --eta 3dTstat -mean -prefix iter1_mean_epi_r{1}${ext} {2} ::: ${ris[*]} ::: ${inputs[*]}"

#for i in `seq 1 $nruns`; do
#  ri=`echo $i | awk '{printf "%02d", $1}'`
#  input=${inputs[i-1]}
#  log_echo "Generate motion-corrected mean EPI for run ${ri}"
#  # Mean EPI of non-motion-corrected data
#  log_tcmd "3dTstat -mean -prefix iter0_mean_epi_r${ri}${ext} ${input}"
#  # Apply motion correction to mean EPI
#  log_tcmd "3dvolreg -verbose -zpad 4 -base iter0_mean_epi_r${ri}${ext} -prefix iter0_epi_volreg_r${ri}${ext} -cubic ${input}"
#  # New mean EPI of motion-corrected data
#  log_tcmd "3dTstat -mean -prefix iter1_mean_epi_r${ri}${ext} iter0_epi_volreg_r${ri}${ext}"
#done

# Combine mean EPIs from each run
log_echo "Combine mean EPIs from each run"
log_tcmd "3dTcat -prefix iter1_mean_epis${ext} iter1_mean_epi_r*${ext}"

# Get mean EPI across runs
log_echo "Get mean EPI across runs"
log_tcmd "3dTstat -mean -prefix iter1_mean_mean_epi${ext} iter1_mean_epis${ext}"


###
# Second Pass
##

log_echo "=== Second Pass"
# Register mean EPIs from each run to each other
log_echo "Motion correct the mean EPIs"
log_tcmd "3dvolreg -verbose -zpad 4 -base iter1_mean_mean_epi${ext} -prefix iter2_mean_epis_volreg${ext} -cubic iter1_mean_epis${ext}"

# Take the mean of motion-corrected mean EPIs
log_echo "Get mean EPI across the mean EPIs"
log_tcmd "3dTstat -mean -prefix iter2_mean_mean_epi${ext} iter2_mean_epis_volreg${ext}"


###
# Wrap Up
##

log_echo "=== Clean up"

log_tcmd "3dcopy iter2_mean_mean_epi${ext} ${output}"

if [ ${keepwdir} == false ]; then
  log_echo "Removing working directory"
  log_cmd "rm ${workdir}/*"
  log_cmd "rmdir ${workdir}"
fi

# Unset AFNI_DECONFLICT
if [ $overwrite == true ]; then
  export AFNI_DECONFLICT=$old_afni_deconflict
fi

