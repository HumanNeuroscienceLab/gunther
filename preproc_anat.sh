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

declare -a inputs
declare -a t2s

source ${GUNTHERDIR}/include/cmdarg.sh

cmdarg_info "header" "Script for preprocessing anatomical image"
cmdarg_info "author" "McCarthy Lab <some address>"
## required inputs
cmdarg "s:" "subject" "Freesurfer subject id"
cmdarg "d:" "studydir" "Study directory"
## optional inputs
cmdarg "c:" "threads" "Number of OpenMP threads to use with FreeSurfer" 1
cmdarg 'i?[]' 'inputs' 'Input high-resolution T1 anatomicals. Can have multiple anatomical files such as -i anat1.nii.gz -i anat2.nii.gz'
cmdarg 't?[]' 't2s' 'Path to high-resolution T2 anatomicals. Can have multiple anatomical files such as -i anat1.nii.gz -i anat2.nii.gz'


## parse
cmdarg_parse "$@"
[ $# == 0 ] && exit
# TODO: get cmdarg to exit early when bad inputs

## for joining together array
## from: http://stackoverflow.com/questions/1527049/bash-join-elements-of-an-array
function join { local d=$1; shift; echo -n "$1"; shift; printf "%s" "${@/#/$d}"; }


#### Set User Variables ####

subject=${cmdarg_cfg['subject']}
studydir=${cmdarg_cfg['studydir']}
#input=${cmdarg_cfg['input']}
#t2=${cmdarg_cfg['t2']}
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

check_inputs ${inputs[@]}
[ ! -z ${#t2s[@]} ] && check_inputs ${t2s[@]}

check_outputs ${anat[done]}
# if overwrite, then remove the skullstrip, reg, segment, and atlases, etc folders


###
# Commands
###

## what to do with more than one output?
## for t2s, we should average them together but to do that we first need to register them to each other and than average
## so i suppose could just do some motion correction

### process t2s
if [[ ${#t2s[@]} -gt 1 ]]; then
  # register everything to the first scan
  t2dir="${anat[_dir]}/t2s"
  log_tcmd "mkdir ${t2dir} 2> /dev/null"
  log_tcmd "3dTcat -prefix ${t2dir}/t2s.nii.gz ${t2s[*]}"
  log_tcmd "3dvolreg -verbose -zpad 4 -base 0 -maxdisp1D ${t2dir}/maxdisp.1D -1Dfile ${t2dir}/dfile.1D -1Dmatrix_save ${t2dir}/mat_vr_aff12.1D -prefix ${anat[t2_head]} -twopass -Fourier ${t2dir}/t2s.nii.gz"  
elif [[ ${#t2s[@]} -eq 1 ]]; then
  log_tcmd "3dcopy ${t2s[@]} ${anat[t2_head]}"
fi

### skull-strip
log_echo "=== Skullstrip"
log_cmd "mkdir ${anat[skullstrip]}"
input=$( join " -i " "${inputs[*]}" )
log_tcmd "bash anat01_skullstrip.sh -p -r ${nthreads} -i ${input} -s ${subject} --sd ${sddir} -o ${anat[skullstrip]}"

## copy over the head to folder
log_echo "=== Copy over main file"
log_tcmd "mri_convert ${sddir}/${subject}/mri/rawavg.mgz ${anat[head]}"

### register to standard
log_echo "=== Register to Standard Space"
log_tcmd "bash anat02_register_to_standard.sh -i ${anat[skullstrip_brain]} -a ${anat[head]} -o ${anat[reg]}"

## segment (for now only with freesurfer)
log_echo "=== Segment"
log_tcmd "bash anat03_segment_freesurfer.sh -s ${subject} --sd ${sddir} -r ${nthreads} -o ${anat[segment]}"

### atlases
log_echo "=== Atlases"
if [[ -z ${#t2s[@]} ]]; then
  log_tcmd "bash anat04_parcellate_freesurfer.sh -s ${subject} --sd ${sddir} -r ${nthreads} -o ${anat[atlases]}"
else
  log_tcmd "bash anat04_parcellate_freesurfer.sh -s ${subject} --sd ${sddir} --t2 ${anat[t2_head]} -r ${nthreads} -o ${anat[atlases]}"
fi

### done
log_echo "=== Let's wrap up here"
log_cmd "touch ${anat[done]}"
