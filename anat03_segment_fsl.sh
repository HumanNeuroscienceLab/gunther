#!/bin/bash

# Goals
# -----
# 
# For this script, a user should only need to run the following:
#
#     03anat_segment_fsl.sh -i input_image -a anat_head -o output_dir
#
# Environmental defaults for the freesurfer subject directory and task directory
# and each of the output paths should take over.
#
# All the commands with some useful logging information should all be saved.

#### Usage ####

source ${GUNTHERDIR}/include/cmdarg.sh

cmdarg_info "header" "Script to segment anat brain"
cmdarg_info "author" "McCarthy Lab <some address>"
## required inputs
cmdarg "i:" "input" "Input brain (skull-stripped)"
cmdarg "o:" "outdir" "Output directory (full path)"
## optional inputs
cmdarg "a:" "args" "Other arguments to supply manually (note: -B -g -p are already used)" ""
cmdarg "f" "force" "Will overwrite any existing output" false
cmdarg "l?" "log" "Log file"
## parse
cmdarg_parse "$@"
[ $# == 0 ] && exit
# TODO: get cmdarg to exit early when bad inputs

input=${cmdarg_cfg['input']}
regdir=${cmdarg_cfg['regdir']}
outdir=${cmdarg_cfg['outdir']}

args=${cmdarg_cfg['args']}
overwrite=${cmdarg_cfg['force']}
_LOG_FILE=${cmdarg_cfg['log']}

ext=".nii.gz"
highres="${outdir}/highres.nii.gz"
outprefix="${outdir}/highres"

#### Log ####

source ${GUNTHERDIR}/include/log.sh

[ -e ${_LOG_FILE} ] && log_echo "WARNING: log file '${_LOG_FILE}' already exists"

log_echo ""
log_echo "RUNNING: $0 $@"

#### Checks/Setup ####

source ${GUNTHERDIR}/include/io.sh

check_inputs "$input" 
check_outputs $overwrite 
[ $overwrite == true ] && log_cmd "rm -rf ${outdir}"

[ ! -e ${outdir} ] && mkdir -p ${outdir}

log_cmd "cd $outdir"

log_echo "Soft-link inputs"
log_cmd "ln -sf ${input} highres.nii.gz"

# Should be able to take this or the freesurfer output

log_echo "Segment"
if [[ -z ${args} ]]; then # TODO: check if this flag works
  log_cmd "fast -B -g -p -o ${outprefix} ${highres}"
else
  log_cmd "fast -B -g -p ${args} -o ${outprefix} ${highres}"
fi

# TODO: add first into the mix here!

ind_gray=1
ind_white=2
ind_csf=0
log_echo "Soft-linking gray = ${ind_gray}, white = ${ind_white}, csf = ${ind_csf}"
## probability maps
log_cmd "ln -sf ${outdir}/highres_prob_${ind_gray}.nii.gz ${outdir}/highres_gray_prob.nii.gz"
log_cmd "ln -sf ${outdir}/highres_prob_${ind_white}.nii.gz ${outdir}/highres_white_prob.nii.gz"
log_cmd "ln -sf ${outdir}/highres_prob_${ind_csf}.nii.gz ${outdir}/highres_csf_prob.nii.gz"
## segmentations
log_cmd "ln -sf ${outdir}/highres_seg_${ind_gray}.nii.gz ${outdir}/highres_gray_seg.nii.gz"
log_cmd "ln -sf ${outdir}/highres_seg_${ind_white}.nii.gz highres_white_seg.nii.gz"
log_cmd "ln -sf ${outdir}/highres_seg_${ind_csf}.nii.gz ${outdir}/highres_csf_seg.nii.gz"

