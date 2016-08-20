#!/bin/bash

# I want to document using shocco: http://rtomayko.github.io/shocco/. It 
# reads shell scripts and produces annotated source documentation in HTML 
# format. So watch for it!

# Goals
# -----
# 
# For this script, a user should only need to run the following:
#
#     01anat_skullstrip.bash -i input_image -s subjectID -o output_dir
#
# Environmental defaults for the freesurfer subject directory and task directory
# and each of the output paths should take over.
#
# All the commands with some useful logging information should all be saved.

#### Usage ####

declare -a inputs

source ${GUNTHERDIR}/include/cmdarg.sh

cmdarg_info "header" "Script for skull stripping"
cmdarg_info "author" "McCarthy Lab <some address>"
## required inputs
cmdarg 'i?[]' 'inputs' "Input head file (not skull-stripped). Can use multiple -i for multiple inputs."
cmdarg "s:" "subject" "Freesurfer subject id"
cmdarg "o:" "outdir" "Output directory"
## optional inputs
cmdarg "d:" "sd" "Freesurfer subjects directory" "${SUBJECTS_DIR}"
cmdarg "p" "plot" "Generate plots of skull-stripping" false
cmdarg "r:" "threads" "Number of OpenMP threads to use with FreeSurfer" $OMP_NUM_THREADS
cmdarg "f" "force" "Will overwrite any existing output" false
cmdarg "l?" "log" "Log file"
## parse
cmdarg_parse "$@"
[ $# == 0 ] && exit
# TODO: get cmdarg to exit early when bad inputs

## for joining together array
## from: http://stackoverflow.com/questions/1527049/bash-join-elements-of-an-array
function join { local d=$1; shift; echo -n "$1"; shift; printf "%s" "${@/#/$d}"; }


#### Set Variables ####

#head=${cmdarg_cfg['input']}
subject=${cmdarg_cfg['subject']}
outdir=${cmdarg_cfg['outdir']}
sd=${cmdarg_cfg['sd']}
threads=${cmdarg_cfg['threads']}
if [ -z $threads ]; then threads=1; fi
plot=${cmdarg_cfg['plot']}
overwrite=${cmdarg_cfg['force']}
_LOG_FILE=${cmdarg_cfg['log']}

export SUBJECTS_DIR=$sd
ext=".nii.gz"

# outputs
bias="${outdir}/brain_biascorrected${ext}"
brain="${outdir}/brain${ext}"
mask="${outdir}/brain_mask${ext}"


#### Log ####

# functions...should source this part
source ${GUNTHERDIR}/include/log.sh

check_logfile # assumes $_LOG_FILE set

log_echo ""
log_echo "RUNNING: $0 $@"


#### Checks/Setup ####

source ${GUNTHERDIR}/include/io.sh

check_inputs ${inputs[@]}
check_outputs $overwrite "$brain" "$mask" "$bias"

# Create the main freesurfer directory with all the subjects in it if not exist
[ ! -e $sd ] && mkdir -p $sd

# Create output directory
mkdir ${outdir} 2> /dev/null

# Remove the subject freesurfer directory if overwriting
# TODO: Maybe want something to not overwrite this...?
[ $overwrite == true ] && log_cmd "rm -rf ${sd}/${subject}"


#### Run ####

# Run freesurfer - step 1
## TODO: check for the output...only run if output doesn't exist?
head=$( join " -i " ${inputs[*]} )
log_cmd "recon-all -i ${head} -s ${subject} -sd ${sd} -autorecon1 -openmp ${threads}"

# Copy over head
tmphead=$(mktemp --suffix .nii.gz); rm ${tmphead}
log_cmd "mri_convert ${sd}/${subject}/mri/rawavg.mgz ${tmphead}"

# Convert the freesurfer space brain into native space
log_tcmd "mri_convert -rl ${sd}/${subject}/mri/rawavg.mgz -rt nearest ${sd}/${subject}/mri/brainmask.mgz ${bias}"
log_tcmd "3dcalc -a ${bias} -expr 'step(a)' -prefix ${mask}"
log_tcmd "3dcalc -a ${tmphead} -b ${mask} -expr 'a*b' -prefix ${brain}"


#### Plot ####

if [ ${plot} == true ]; then
  headname="head" #`${FSLDIR}/bin/remove_ext $(basename ${tmphead})`
  maskname=`${FSLDIR}/bin/remove_ext $(basename ${mask})`
  log_tcmd "slicer.py --crop -w 5 -l 4 -s axial ${tmphead} ${outdir}/${headname}_axial.png"
  log_tcmd "slicer.py --crop -w 5 -l 4 -s sagittal ${tmphead} ${outdir}/${headname}_sagittal.png"
  log_tcmd "slicer.py --crop -w 5 -l 4 -s axial --overlay ${mask} 1 1 -t ${tmphead} ${outdir}/${maskname}_axial.png"
  log_tcmd "slicer.py --crop -w 5 -l 4 -s sagittal --overlay ${mask} 1 1 -t ${tmphead} ${outdir}/${maskname}_sagittal.png"
fi

# remove tmphead
log_tcmd "rm ${tmphead}"
