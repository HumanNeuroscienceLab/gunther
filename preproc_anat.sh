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

source cmdarg.sh

cmdarg_info "header" "Script for preprocessing anatomical image"
cmdarg_info "author" "McCarthy Lab <some address>"
## required inputs
cmdarg "s:" "subject" "Freesurfer subject id"
cmdarg "p:" "project" "Project directory"
## optional inputs
cmdarg "r:" "threads" "Number of OpenMP threads to use with FreeSurfer" 1
cmdarg "i?" "input" "Path to optional high-resolution anatomical"

## parse
cmdarg_parse "$@"
[ $# == 0 ] && exit
# TODO: get cmdarg to exit early when bad inputs


#### Set User Variables ####

subject=${cmdarg_cfg['subject']}
studydir=${cmdarg_cfg['project']}
input=${cmdarg_cfg['input']}
nthreads=${cmdarg_cfg['threads']}


#### Set Semi-Auto Variables ####

# TODO: move these to another script

# Raw/Original files
rawdir="${studydir}/data/nifti/${subject}"
raw['dir']="${rawdir}"
raw['highres']="${rawdir}/${subject}_t1w.nii.gz"
raw['t2']="${rawdir}/${subject}_t2w.nii.gz"

# General
preprocdir="${studydir}/analysis/preprocessed/${subject}"
sddir="${studydir}/analysis/freesurfer"
freesurferdir="${studydir}/analysis/freesurfer/${subject}"

# Anatomical files
anatdir="${preprocdir}/anat"
declare -a anat
anat['_dir']="${anatdir}"
anat['log']="${anatdir}/log_date-$(date +'%Y-%m-%d')_time-$(date +'%H-%M-%s').txt"
## input
anat['head']="${anatdir}/head.nii.gz"
## skull-strip script
anat['skullstrip']="${anatdir}/skullstrip"
anat['skullstrip_prefix']="${anatdir}/skullstrip/brain"
anat['skullstrip_brain']="${anatdir}/skullstrip/brain.nii.gz"
anat['skullstrip_brainmask']="${anatdir}/skullstrip/brain_mask.nii.gz"
## registration script
anat['reg']="${anatdir}/reg" # TODO: name individual registration files?
## segmentation script
anat['segment']="${anatdir}/segment"
## atlases script
anat['atlases']="${anatdir}/atlases"
## done text
anat['done']="${anatdir}/done"


#### Set Default Variables if Needed ####

if [ -z ${input} ]; then
  input=${raw[highres]}
fi


#### Setup ####

[ ! -e ${preprocdir} ] && log_cmd "mkdir ${preprocdir}"
[ ! -e ${freesurferdir} ] && log_cmd "mkdir ${freesurferdir}"
[ ! -e ${preprocdir} ] && log_cmd "mkdir ${anat[_dir]}"
log_cmd2 "_LOG_FILE=${anat[log]}"

ext=".nii.gz"


#### Log ####

source ${GUNTHERDIR}/include/log.sh

check_logfile

log_echo ""
log_echo "RUNNING: $0 $@"


#### Checks/Setup ####

source ${GUNTHERDIR}/include/io.sh

check_inputs ${input}
check_outputs ${anat[done]}
# if overwrite, then remove the skullstrip, reg, segment, and atlases, etc folders


###
# Commands
###

### input file
log_echo "=== Copy over main file"
log_cmd "3dcopy ${input} ${anat[head]}"

### skull-strip
log_echo "=== Skullstrip"
log_cmd "mkdir ${anat[skullstrip]}"
log_cmd "bash anat01_skullstrip.sh -i ${anat[head]} -s ${subject} --sd ${sddir} -o ${anat[skullstrip]}"

### register to standard
log_echo "=== Register to Standard Space"
log_cmd "bash anat02_register_to_standard.sh -i ${anat[skullstrip_brain]} -a ${anat[head]} -o ${anat[reg]}"

### segment (for now only with freesurfer)
log_echo "=== Segment"
log_cmd "bash anat03_segment_freesurfer.sh -s ${subject} --sd ${sddir} -r ${nthreads} -o ${anat[atlases]}"

### atlases
log_echo "=== Atlases"
if [[ -z ${raw['t2']} ]]; then
  log_cmd "bash anat04_parcellate_freesurfer.sh -s ${subject} --sd ${sddir} -r ${nthreads} -o ${anat[atlases]}"
else
  log_cmd "bash anat04_parcellate_freesurfer.sh -s ${subject} --sd ${sddir} --t2 ${raw['t2']} -r ${nthreads} -o ${anat[atlases]}"
fi

### done
log_echo "=== Let's wrap up here"
log_cmd "touch ${anat[done]}"
