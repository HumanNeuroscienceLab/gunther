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

source cmdarg.sh

cmdarg_info "header" "Script for applying registration to other images"
cmdarg_info "author" "McCarthy Lab <some address>"
## required inputs
cmdarg "i:" "input" "Source image that is to be transformed"
cmdarg "r:" "reg" "Outputs of previously run registration (assumes that non-linear has been run for anat-to-standard)"
cmdarg "w:" "warp" "Type of warp to use, can be: 'exfunc', 'highres', or 'standard' in the form of X-to-Y (e.g., highres-to-standard)"
cmdarg "o:" "output" "Output transformed image"
## optional inputs
cmdarg "n:" "linear" "Only use linear (not non-linear) registration for highres-to-standard (default: false or nonlinear)" false
cmdarg "t:" "interp" "Final interpolation to use and can be nn, linear, sinc, and spline (spline only for non-linear)" "trilinear"
cmdarg "m:" "master" "An image that defines the output grid (default: target image for the registration)" ""
cmdarg "k:" "mask" "Mask to be applied in reference space" ""
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

#CDIR="/mnt/nfs/share/guntherxr/bin"
ext=".nii.gz"

log_echo "Setup"

#### Log ####

source log.sh

[ -e ${_LOG_FILE} ] && log_echo "WARNING: log file '${_LOG_FILE}' already exists"

log_echo ""
log_echo "RUNNING: $0 $@"

#### Checks/Setup ####

source io.sh

check_inputs "${input}" "$regdir"
if [ -n "$master" ]; then check_inputs "$master"; fi
check_outputs $overwrite "$output"

###
# Setup
###

log_echo "Setup"

log_echo "Process warp input"
sourceimg=`echo $warp|awk -F- '{print $1}'`
targetimg=`echo $warp|awk -F- '{print $3}'`
to=`echo $warp|awk -F- '{print $2}'`
if [ -z "$sourceimg" -o -z "$targetimg" -o "$to" != "to" ]; then 
  log_die("Error in parsing ${warp}. Must be X-to-Y.")
fi
if [ "$sourceimg" != "exfunc" -a "$sourceimg" != "highres" -a "$sourceimg" != "standard" ]; then
  log_die("Incorrect sourceimg: ${sourceimg}. Must be exfunc, highres, or standard")
fi
if [ "$targetimg" != "exfunc" -a "$targetimg" != "highres" -a "$targetimg" != "standard" ]; then
  log_die("Incorrect targetimg: ${targetimg}. Must be exfunc, highres, or standard")
fi

log_echo "Changing directory to '${regdir}'"
cd $regdir


###
# Apply Non-Linear (for now) Registration
###

log_echo "Apply registration"
  
if [ $targetimg == "standard" or $sourceimg == "standard" -a $linear == false ]; then
  log_echo "Non-Linear: ${source} => ${target}"
  
  cmd="applywarp -i ${input}"
  
  if [ -z "$master" ]; then
    cmd="$cmd -r ${regdir}/${target}${ext}"
  else
    cmd="$cmd -r ${master}"
  fi
  
  if [ -n "$mask" ]; then cmd="$cmd -m ${mask}"; fi
  
  cmd="$cmd -w ${regdir}/${source}2${target}_warp${ext}"
  
  if [ -n "$interp" ]; then cmd="$cmd --interp=${interp}"; fi
  
  cmd="$cmd -o ${output}"
  
  log_tcmd "$cmd"

else # source/target are func or highres
  log_echo "Linear: ${source} => ${target}"
  
  # actually can use applywarp for linear
  # $FSLDIR/bin/applywarp -i ${vepi} -r ${vrefhead} -o ${vout} --premat=${vout}.mat --interp=spline
  
  cmd="applywarp -i ${input}"
  
  if [ -z "$master" ]; then
    cmd="$cmd -r ${regdir}/${target}${ext}"
  else
    cmd="$cmd -r ${master}"
  fi
  if [ -n "$mask" ]; then cmd="$cmd -m ${mask}"; fi
  cmd="$cmd --premat=${regdir}/${source}2${target}.mat"
  
  if [ -n "$interp" ]; then cmd="$cmd --interp=${interp}"; fi
  cmd="$cmd -o ${output}"
  
  log_tcmd $cmd
fi


