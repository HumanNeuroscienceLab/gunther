#!/usr/bin/env bash
# 

declare -a inputs
declare -A params


#### Usage ####

source ${GUNTHERDIR}/include/cmdarg.sh

cmdarg_info "header" "Wrapper script for functional preprocessing"
cmdarg_info "author" "McCarthy Lab <some address>"
## required inputs
cmdarg "s:" "subject" "Subject ID"
cmdarg "d:" "studydir" "Study directory"
#cmdarg 'i?[]' 'inputs' 'Input functional files as -i name=path. Can have multiple functionals with the same name.'
cmdarg "p?{}" "params" "Set paramaters: fwhm, high_pass, and/or low_pass"
## optional inputs
cmdarg "f" "force" "Will overwrite any existing output" false
## parse
cmdarg_parse "$@"
[ $# == 0 ] && exit


#### Set Variables ####

subject=( ${cmdarg_cfg['subject']} )
studydir=${cmdarg_cfg['studydir']}
overwrite=${cmdarg_cfg['force']}

ext=".nii.gz"
workprefix="prefunc"

old_afni_deconflict=$AFNI_DECONFLICT
if [ $overwrite == true ]; then
  export AFNI_DECONFLICT="OVERWRITE"
fi


#### Paths ####

source ${GUNTHERDIR}/include/paths.sh
create_subject_dirs
set_func_logfile


#### Log ####

source ${GUNTHERDIR}/include/log.sh

check_logfile

log_echo ""
log_echo "RUNNING: $0 $@"


#### Checks/Setup ####

source ${GUNTHERDIR}/include/io.sh

check_inputs ${list_inputs[@]}


#### Analysis ####

log_echo "=== Registration"
log_echo "Temp hack for getting white matter from freesurfer segmentation"
log_tcmd "3dcalc -a ${anat[segment]}/aseg/left_cerebral_white_matter.nii.gz -b ${anat[segment]}/aseg/right_cerebral_white_matter.nii.gz -expr 'step(a+b)' -prefix ${anat[segment_wm]}" "${anat[segment_wm]}"
log_tcmd "bash func03_register_highres.sh -i '${func[meanfunc]}' -a '${anat[skullstrip_brain]}' -s '${anat[segment_wm]}' --anathead '${anat[head]}' -o '${func[reg]}'"
log_tcmd "bash func04_register_standard.sh --epireg ${func[reg]} --anatreg ${anat[reg]}"
