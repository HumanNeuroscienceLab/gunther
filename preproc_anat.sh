#!/bin/bash

export GUNTHERDIR=/mnt/nfs/share/scripts/gunther # HACK

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

cmdarg_info "header" "Script for preprocessing anatomical image"
cmdarg_info "author" "McCarthy Lab <some address>"
## required inputs
cmdarg "s:" "subject" "Freesurfer subject id"
cmdarg "d:" "studydir" "Study directory"
## optional inputs
cmdarg "c:" "threads" "Number of OpenMP threads to use with FreeSurfer" 1
cmdarg "i:" "input" "Path to high-resolution T1 anatomical"
cmdarg "t?" "t2" "Path to high-resolution T2 anatomical"

## parse
cmdarg_parse "$@"
[ $# == 0 ] && exit
# TODO: get cmdarg to exit early when bad inputs


#### Set User Variables ####

subject=${cmdarg_cfg['subject']}
studydir=${cmdarg_cfg['studydir']}
input=${cmdarg_cfg['input']}
t2=${cmdarg_cfg['t2']}
nthreads=${cmdarg_cfg['threads']}


#### Setup ####

ext=".nii.gz"


#### Paths ####

source ${GUNTHERDIR}/include/paths.sh
create_subject_dirs
set_anat_logfile


#### Log ####

source ${GUNTHERDIR}/include/log.sh

check_logfile

log_echo ""
log_echo "RUNNING: $0 $@"


#### Checks/Setup ####

source ${GUNTHERDIR}/include/io.sh

check_inputs ${input}
[ ! -z ${t2} ] && check_inputs ${t2}

check_outputs ${anat[done]}
# if overwrite, then remove the skullstrip, reg, segment, and atlases, etc folders


###
# Commands
###

### input file
log_echo "=== Copy over main file"
log_tcmd "3dcopy ${input} ${anat[head]}"

### skull-strip
log_echo "=== Skullstrip"
log_cmd "mkdir ${anat[skullstrip]}"
log_tcmd "bash anat01_skullstrip.sh -p -r ${nthreads} -i ${anat[head]} -s ${subject} --sd ${sddir} -o ${anat[skullstrip]}"

### register to standard
log_echo "=== Register to Standard Space"
log_tcmd "bash anat02_register_to_standard.sh -i ${anat[skullstrip_brain]} -a ${anat[head]} -o ${anat[reg]}"

## segment (for now only with freesurfer)
log_echo "=== Segment"
log_tcmd "bash anat03_segment_freesurfer.sh -s ${subject} --sd ${sddir} -r ${nthreads} -o ${anat[segment]}"

### atlases
log_echo "=== Atlases"
if [[ -z ${t2} ]]; then
  log_tcmd "bash anat04_parcellate_freesurfer.sh -s ${subject} --sd ${sddir} -r ${nthreads} -o ${anat[atlases]}"
else
  log_tcmd "bash anat04_parcellate_freesurfer.sh -s ${subject} --sd ${sddir} --t2 ${t2} -r ${nthreads} -o ${anat[atlases]}"
fi

### done
log_echo "=== Let's wrap up here"
log_cmd "touch ${anat[done]}"
