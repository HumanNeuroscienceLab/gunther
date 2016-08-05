#!/bin/bash
# 
#
# For this script, a user should only need to run the following:
#
#     gen_applywarp.sh -i input.nii.gz -r regdir -w transform_string -o output.nii.gz [--interp mode] [--overwrite] [--master reference.nii.gz] [--mask ref_mask.nii.gz] [--log log_outprefix]
#  
#  This script applies linear or non-linear registration to images
#  using FSL applywarp
#
# 

#### Usage ####

source ${GUNTHERDIR}/include/cmdarg.sh

cmdarg_info "header" "Script for applying registration to other images"
cmdarg_info "author" "McCarthy Lab <some address>"
## required inputs
cmdarg "i:" "input" "Source image that is to be transformed"
cmdarg "r:" "reg" "Outputs of previously run registration (assumes that non-linear has been run for anat-to-standard)"
cmdarg "w:" "warp" "Type of warp to use, can be: 'exfunc', 'highres', or 'standard' in the form of X-to-Y (e.g., highres-to-standard)"
cmdarg "o:" "output" "Output transformed image"
## optional inputs
cmdarg "m?" "master" "An image that defines the output grid (default: target image for the registration)" ""
cmdarg "k?" "mask" "Mask to be applied in reference space" ""
cmdarg "n" "linear" "Only use linear (not non-linear) registration for highres-to-standard (default: false or nonlinear)" false
cmdarg "t:" "interp" "Final interpolation to use and can be nn, linear, sinc, and spline (spline only for non-linear)" "trilinear"
cmdarg "f" "force" "Will overwrite any existing output" false
cmdarg "l?" "log" "Log file"
## parse
cmdarg_parse "$@"
[ $# == 0 ] && exit

#### Set Variables ####

input=(${cmdarg_cfg['input']})
regdir=${cmdarg_cfg['reg']}
warp=${cmdarg_cfg['warp']}
output=${cmdarg_cfg['output']}
linear=${cmdarg_cfg['linear']}
interp=(${cmdarg_cfg['interp']})
master=${cmdarg_cfg['master']}
mask=${cmdarg_cfg['mask']}
overwrite=${cmdarg_cfg['force']}
_LOG_FILE=${cmdarg_cfg['log']}
[ ! -z $_LOG_FILE ] && _LOG_FILE=$( readlink -f ${_LOG_FILE} ) # absolute path (if exists)

#CDIR="/mnt/nfs/share/guntherxr/bin"
ext=".nii.gz"


#### Log ####

source ${GUNTHERDIR}/include/log.sh

check_logfile

log_echo ""
log_echo "RUNNING: $0 $@"


#### Checks/Setup ####

source ${GUNTHERDIR}/include/io.sh

log_echo "Setup"

source=`echo $warp | awk -F- '{print $1}'`
to=`echo $warp | awk -F- '{print $2}'`
target=`echo $warp | awk -F- '{print $3}'`
log_echo "${source} => ${target}"

log_echo "Process warp input"
if [ -z "$source" -o -z "$target" -o "$to" != "to" ]; then 
  log_die "Error in parsing ${warp}. Must be X-to-Y."
fi
if [ "$source" != "exfunc" -a "$source" != "highres" -a "$source" != "standard" ]; then
  log_die "Incorrect source: ${source}. Must be exfunc, highres, or standard"
fi
if [ "$target" != "exfunc" -a "$target" != "highres" -a "$target" != "standard" ]; then
  log_die "Incorrect target: ${target}. Must be exfunc, highres, or standard"
fi

log_echo "Check paths"

check_inputs "${input}" "$regdir"
[ -z "$master" ] && master="${regdir}/${target}${ext}"
check_inputs "$master"

check_outputs $overwrite "$output"

log_echo "Changing directory to '${regdir}'"
cd $regdir


###
# Apply Non-Linear (for now) Registration
###

log_echo "Apply registration"

[ $target != "standard" -a $source != "standard" ] && linear=true

if [ $linear == false ]; then
  log_echo "Non-Linear: ${source} => ${target}"
  
  cmd="applywarp -i ${input}"
  cmd="$cmd -r ${master}"
  cmd="$cmd -w ${regdir}/${source}2${target}_warp${ext}"
  
  [ -n "$mask" ] && cmd="$cmd -m ${mask}"
  [ -n "$interp" ] && cmd="$cmd --interp=${interp}"
  
  cmd="$cmd -o ${output}"
  
  log_tcmd "$cmd"

else # source/target are func or highres
  log_echo "Linear: ${source} => ${target}"
  
  # actually can use applywarp for linear
  # $FSLDIR/bin/applywarp -i ${vepi} -r ${vrefhead} -o ${vout} --premat=${vout}.mat --interp=spline
  
  cmd="applywarp -i ${input}"
  cmd="$cmd -r ${master}"
  cmd="$cmd --premat=${regdir}/${source}2${target}.mat"
  
  [ -n "$mask" ] && cmd="$cmd -m ${mask}"
  [ -n "$interp" ] && cmd="$cmd --interp=${interp}"
  cmd="$cmd -o ${output}"
  
  log_tcmd "$cmd"
fi
