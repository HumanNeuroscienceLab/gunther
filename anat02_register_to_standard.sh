#!/bin/bash

# Goals
# -----
# 
# For this script, a user should only need to run the following:
#
#     02anat_register_to_standard.sh -i input_image -a anat_head -o output_dir
#
# Environmental defaults for the freesurfer subject directory and task directory
# and each of the output paths should take over.
#
# All the commands with some useful logging information should all be saved.

#### Usage ####

source ${GUNTHERDIR}/include/cmdarg.sh

cmdarg_info "header" "Script for registering to a standard brain"
cmdarg_info "author" "McCarthy Lab <some address>"
## required inputs
cmdarg "i:" "input" "Input brain (skull-stripped)"
cmdarg "o:" "outdir" "Output directory (full path)"
cmdarg "a:" "anat_head" "input anatomical with head"
## optional inputs
cmdarg "t:" "template" "standard image" "$FSLDIR/data/standard/MNI152_T1_2mm_brain.nii.gz"
cmdarg "e:" "template_head" "standard head image" "$FSLDIR/data/standard/MNI152_T1_2mm.nii.gz"
cmdarg "m:" "template_mask" "standard head image" "$FSLDIR/data/standard/MNI152_T1_2mm_brain_mask.nii.gz"
cmdarg "f" "force" "Will overwrite any existing output" false
cmdarg "l?" "log" "Log file"
## parse
cmdarg_parse "$@"
[ $# == 0 ] && exit
# TODO: get cmdarg to exit early when bad inputs

#### Set Variables ####

input=${cmdarg_cfg['input']}
outdir=${cmdarg_cfg['outdir']}
anat_head=${cmdarg_cfg['anat_head']}

template=${cmdarg_cfg['template']}
template_head=${cmdarg_cfg['template_head']}
template_mask=${cmdarg_cfg['template_mask']}
overwrite=${cmdarg_cfg['force']}
_LOG_FILE=${cmdarg_cfg['log']}
[ ! -z $_LOG_FILE ] && _LOG_FILE=$( readlink -f ${_LOG_FILE} ) # absolute path (if exists)

ext=".nii.gz"


#### Log ####

source ${GUNTHERDIR}/include/log.sh

check_logfile # assumes $_LOG_FILE set

log_echo ""
log_echo "RUNNING: $0 $@"


#### Checks/Setup ####

source ${GUNTHERDIR}/include/io.sh

check_inputs "$input" "$template" ${anat_head} ${template_head} ${template_mask}
check_outputs $overwrite $outdir
[ $overwrite == true ] && log_cmd "rm -rf ${outdir}"

# get full paths since changing paths
var_names="input template anat_head template_head template_mask outdir"
for var_name in ${var_names}; do
  path=$( eval "echo \$${var_name}" )
  declare "${var_name}"="$( readlink -f $path )"
done

# recheck inputs
check_inputs "$input" "$template" ${anat_head} ${template_head} ${template_mask}

# change to output directory
log_cmd "mkdir $outdir 2> /dev/null"
log_cmd2 "cd $outdir"


###
# copy all necessary files to ${outdir}
###
log_cmd "3dcopy ${template} standard${ext}"
log_cmd "3dcopy ${input} highres${ext}"
log_cmd "3dcopy ${anat_head} highres_head${ext}"
log_cmd "3dcopy ${template_head} standard_head${ext}"
log_cmd "3dcopy ${template_mask} standard_mask${ext}"
    
    
###
# Do Linear Registration
###
    
log_cmd "flirt -in highres -ref standard -out highres2standard_linear -omat highres2standard.mat -cost corratio -dof 12 -searchrx -90 90 -searchry -90 90 -searchrz -90 90 -interp trilinear"
log_cmd "convert_xfm -inverse -omat standard2highres.mat highres2standard.mat"
    
    
###
# Do Non-Linear Registration
###
log_echo "Non-linear registration"
#log_cmd "fnirt --iout=highres2standard_head --in=highres_head --aff=highres2standard.mat --cout=highres2standard_warp --iout=highres2standard --jout=highres2highres_jac --config=T1_2_MNI152_2mm --ref=standard_head --refmask=standard_mask --warpres=10,10,10"
log_cmd "fnirt --iout=highres2standard_head --in=highres_head --aff=highres2standard.mat --cout=highres2standard_warp --jout=highres2highres_jac --config=T1_2_MNI152_2mm --ref=standard_head --refmask=standard_mask --warpres=10,10,10"
    
log_echo "Apply non-linear registration"
log_cmd "applywarp -i highres -r standard -o highres2standard -w highres2standard_warp"
    
log_echo "Invert non-linear warp"
log_cmd "invwarp -w highres2standard_warp -r highres -o standard2highres_warp"


###
# Pictures
###
log_echo "Pretty pictures"

if [ $overwrite == true ]; then
  sl_opts=" --force" # for slicer.py
else
  sl_opts=""
fi
log_cmd "slicer.py${sl_opts} --auto -r standard${ext} highres2standard_linear${ext} highres2standard_linear.png"
log_cmd "slicer.py${sl_opts} --auto -r standard${ext} highres2standard${ext} highres2standard.png"


###
# Quality Check
###

log_echo "Correlating highres with standard for quality check"

log_cmd2 "cor_lin=`3ddot -docor -mask standard${ext} highres2standard_linear${ext} standard${ext}`"
log_cmd2 "cor_nonlin=`3ddot -docor -mask standard${ext} highres2standard${ext} standard${ext}`"

log_echo "linear highres2standard vs standard: ${cor_lin}"
log_echo "non-linear highres2standard vs standard: ${cor_nonlin}"

log_echo "saving results to file: ${outdir}/quality_highres2standard.txt"
echo "${cor_lin} # linear higres2standard vs standard" > quality_highres2standard.txt
echo "${cor_nonlin} # non-linear higres2standard vs standard" >> quality_highres2standard.txt

