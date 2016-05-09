#!/usr/bin/env bash


#### Usage ####

source ${GUNTHERDIR}/include/cmdarg.sh

cmdarg_info "header" "Script for running tissue and subcortical segmentation using freesurfer"
cmdarg_info "author" "McCarthy Lab <some address>"
## required inputs
cmdarg "s:" "subject" "Freesurfer subject id"
cmdarg "o:" "outdir" "Output directory for aseg and tissue segmentations in nifti native space"
## optional inputs
cmdarg "d:" "sd" "Freesurfer subjects directory" "${SUBJECTS_DIR}"
cmdarg "r:" "threads" "Number of OpenMP threads to use with FreeSurfer" $OMP_NUM_THREADS
cmdarg "f" "force" "Will overwrite any existing output" false
cmdarg "l?" "log" "Log file"
## parse
cmdarg_parse "$@"
[ $# == 0 ] && exit
# TODO: get cmdarg to exit early when bad inputs

subject=${cmdarg_cfg['subject']}
outdir=${cmdarg_cfg['outdir']}
sd=${cmdarg_cfg['sd']}
threads=${cmdarg_cfg['threads']}
if [ -z $threads ]; then threads=1; fi
overwrite=${cmdarg_cfg['force']}
_LOG_FILE=${cmdarg_cfg['log']}
[ ! -z $_LOG_FILE ] && _LOG_FILE=$( readlink -f ${_LOG_FILE} ) # absolute path (if exists)

freedir=$sd/$subject
ext=".nii.gz"


#### LOG ####

source ${GUNTHERDIR}/include/log.sh

check_logfile # assumes $_LOG_FILE set

# set freesurfer SUBJECTS_DIR
log_echo "Setting SUBJECTS_DIR=${sd}"
log_cmd2 "export SUBJECTS_DIR=$sd"
  

### CHECK INPUTS ###  

source ${GUNTHERDIR}/include/io.sh

log_echo "Checking inputs"
check_inputs "${freedir}/mri" 
check_outputs $overwrite "${outdir}/aseg${ext}"

log_cmd "mkdir -p ${outdir} 2> /dev/null"


#### Run Freesurfer ####

if [ ! -e "${freedir}/mri/aseg.mgz" -o ! -e "${freedir}/surf/lh.inflated" -o $overwrite == "true" ]; then
  log_tcmd "recon-all -s ${subject} -sd ${sd} -no-isrunning -autorecon2 -openmp ${threads}"
else
  log_echo "Freesurfer autorecon2 output already exists, skipping!"
fi


#### Freesurfer Space to Native Space ####

log_echo "Copy freesurfer outputs to our output folder"
log_echo "and convert volume space labels from mgz to individual nifti files"

log_tcmd "mri_convert -rl ${freedir}/mri/rawavg.mgz -rt nearest ${freedir}/mri/aseg.mgz ${outdir}/aseg${ext}"
log_tcmd "$python ${GUNTHERDIR}/anat_freesurfer_split.py ${outdir}/aseg${ext} ${outdir}/subcortical"


# TODO: soft-link the relevant tissues into the main output directory
# TODO: also might want to soft-link the relevant subcortical files into some other directory? or maybe that would be into another parcel directory
