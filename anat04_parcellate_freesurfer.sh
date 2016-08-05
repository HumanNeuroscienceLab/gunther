#!/bin/bash

#### Usage ####

source ${GUNTHERDIR}/include/cmdarg.sh

cmdarg_info "header" "Script for running freesurfer"
cmdarg_info "author" "McCarthy Lab <some address>"
## required inputs
cmdarg "s:" "subject" "Freesurfer subject id"
cmdarg "o:" "outdir" "Output directory"
## optional inputs
cmdarg "d:" "sd" "Freesurfer subjects directory" "${SUBJECTS_DIR}"
#cmdarg "e:" "extra" "Extra arguments should be within quotes"
cmdarg "t:" "t2" "Path to additional T2 or flair volume"
cmdarg "r:" "threads" "Number of OpenMP threads to use with FreeSurfer" $OMP_NUM_THREADS
cmdarg "f" "force" "Will overwrite any existing output" false
cmdarg "l?" "log" "Log file"
## parse
cmdarg_parse "$@"
[ $# == 0 ] && exit
# TODO: get cmdarg to exit early when bad inputs

subject=${cmdarg_cfg['subject']}
outdir=${cmdarg_cfg['outdir']}
#extra_args=${cmdarg_cfg['extra']}
t2=${cmdarg_cfg['t2']}
sd=${cmdarg_cfg['sd']}
autorecon2=${cmdarg_cfg['autorecon2']}
autorecon3=${cmdarg_cfg['autorecon3']}
threads=${cmdarg_cfg['threads']}
if [ -z $threads ]; then threads=1; fi
overwrite=${cmdarg_cfg['force']}
_LOG_FILE=${cmdarg_cfg['log']}
[ ! -z $_LOG_FILE ] && _LOG_FILE=$( readlink -f ${_LOG_FILE} ) # absolute path (if exists)

freedir=$sd/$subject
ext=".nii.gz"


### SETUP LOG ###

source ${GUNTHERDIR}/include/log.sh

# set freesurfer SUBJECTS_DIR
log_echo "Setting SUBJECTS_DIR=${sd}"
log_cmd2 "export SUBJECTS_DIR=$sd"
  

### CHECK INPUTS AND OUTPUTS ###  

source ${GUNTHERDIR}/include/io.sh

log_echo "Checking inputs"
check_inputs "$freedir" "${freedir}/mri" 
check_outputs $overwrite "${outdir}/aseg${ext}", "${outdir}/aparc", "${outdir}/misc"

log_cmd "mkdir -p ${outdir}"


### RUN FREESURFER ###

log_time
if [ ! -e "${freedir}/mri/aparc+aseg.mgz" -o ! -e "${freedir}/mri/wmparc.mgz" -o $overwrite == "true" ]; then
  if [[ ! -z ${t2} ]]; then
    log_cmd "recon-all -s ${subject} -sd ${sd} -no-isrunning -T2 ${t2} -T2pial -autorecon3 -openmp ${threads}"
  else
    log_cmd "recon-all -s ${subject} -sd ${sd} -no-isrunning -autorecon3 -openmp ${threads}"
  fi
else 
  log_echo "Freesurfer autorecon3 output already exists, skipping!"
fi


### FREESURFER TO NATIVE NIFTI SPACE ###

log_echo "Copy freesurfer outputs to our output folder"
  
log_echo "Convert volume space labels from mgz to individual nifti files"
log_cmd "mri_convert -rl ${freedir}/mri/rawavg.mgz -rt nearest ${freedir}/mri/aparc.a2009s+aseg.mgz ${outdir}/aparc.a2009s+aseg${ext}"
log_cmd "mri_convert -rl ${freedir}/mri/rawavg.mgz -rt nearest ${freedir}/mri/aparc+aseg.mgz ${outdir}/aparc+aseg${ext}"
log_cmd "mri_convert -rl ${freedir}/mri/rawavg.mgz -rt nearest ${freedir}/mri/aseg.mgz ${outdir}/aseg${ext}"
log_cmd "$python ${GUNTHERDIR}/bin/anat_freesurfer_split.py ${outdir}/aseg${ext} ${outdir}/volume"

log_echo "Generate atlas to native volume space transform"
log_cmd "tkregister2 --mov ${freedir}/mri/rawavg.mgz --noedit --s ${subject} --sd ${sd} --regheader --reg ${freedir}/mri/register.dat"
  
atlas_names=( "aparc" "aparc_a2009s" "aparc_DKTatlas40" )
for atlas_name in ${atlas_names[@]}; do
    log_cmd2 "atlas_name2=${atlas_name/_/.}" # freesurfer file format
    
    log_echo "Convert labels from the ${atlas_name} to native volume space"
    log_cmd "mkdir ${freedir}/label_${atlas_name} 2> /dev/null"
    log_cmd "mkdir ${outdir}/${atlas_name} 2> /dev/null"
    
    log_echo "changing directory to ${freedir}/label_${atlas_name}"
    log_cmd2 "cd ${freedir}/label_${atlas_name}"
    
    for hemi in "lh" "rh"; do
      log_echo "annotation to labels for ${hemi}"
      log_cmd "mri_annotation2label --subject ${subject} --sd ${sd} --hemi ${hemi} --annotation "${atlas_name2}" --outdir ${freedir}/label_${atlas_name}"
      
      log_echo "labels to volumes"
      files=( `ls -1 ${freedir}/label_${atlas_name}/${hemi}.*.label` )
      for file in ${files[@]}; do basename $file | awk -F . '{print $2}'; done
      for file in ${files[@]}; do echo 
        region=`basename $file | awk -F . '{print $2}'`
        log_echo "...${region}"
        log_cmd "mri_label2vol --label ${hemi}.${region}.label --temp ${freedir}/mri/rawavg.mgz --subject ${subject} --hemi ${hemi} \
          --o ${outdir}/${atlas_name}/${hemi}_${region}${ext} --proj frac 0 1 .1 --fillthresh .3 --reg ${freedir}/mri/register.dat"
      done
    done
done
  
log_echo "Miscellaneous labels in ${freedir}/label"
log_cmd "mkdir ${outdir}/misc 2> /dev/null"

log_echo "changing directory to ${freedir}/label"
log_cmd2 "cd ${freedir}/label"

for hemi in "lh" "rh"; do
    log_echo "Convert miscellaneous labels to native volume space for ${hemi}"
    files=( `ls -1 ${freedir}/label/${hemi}.*.label` )
    for file in ${files[@]}; do
      region=`basename $file | awk -F . '{print $2}'`
      log_echo "...${region}"
      log_cmd "mri_label2vol --label ${hemi}.${region}.label --temp ${freedir}/mri/rawavg.mgz --subject ${subject} --hemi ${hemi} \
        --o ${outdir}/misc/${hemi}_${region}${ext} --proj frac 0 1 .1 --fillthresh .3 --reg ${freedir}/mri/register.dat"
    done
done
