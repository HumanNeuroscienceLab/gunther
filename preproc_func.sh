#!/usr/bin/env bash
# 

export GUNTHERDIR=/mnt/nfs/share/scripts/gunther # HACK

declare -a inputs
declare -A params


#### Usage ####

source ${GUNTHERDIR}/include/cmdarg.sh

cmdarg_info "header" "Wrapper script for functional preprocessing"
cmdarg_info "author" "McCarthy Lab <some address>"
## required inputs
cmdarg "s:" "subject" "Subject ID"
cmdarg "d:" "studydir" "Study directory"
cmdarg 'i?[]' 'inputs' 'Input functional files as -i name=path. Can have multiple functionals with the same name.'
cmdarg "p?{}" "params" "Set paramaters: fwhm, high_pass, and/or low_pass"
## optional inputs
cmdarg "f" "force" "Will overwrite any existing output" false
## parse
cmdarg_parse "$@"
[ $# == 0 ] && exit

# Parse the inputs
declare -a list_names
declare -a list_inputs
echo
echo "Will Preprocess:"
for (( i = 1; i <= ${#inputs[@]}; i++ )); do
  echo "${i}: ${inputs[i]}"
  list_names[i-1]=$( echo -e "${inputs[i]}" | awk -F'=' '{print $1}' )
  list_inputs[i-1]=$( echo -e "${inputs[i]}" | awk -F'=' '{print $2}' )
done
echo

# Set defaults for the params
[ -z ${params[fwhm]} ] && params[fwhm]=0
[ -z ${params[high_pass]} ] && params[high_pass]=-1
[ -z ${params[low_pass]} ] && params[low_pass]=-1

#echo ${list_names[@]}
#echo ${list_inputs[@]}
#exit
#
## Specific Paths
#list_names=( "rest" "static_loc" "static_loc" "dynamic_loc" "dynamic_loc" "raiders_movie" "raiders_movie" "raiders_movie" )
#list_inputs=( "/data1/faceloc02/data/nifti/tb3056/tb3056_rest.nii.gz" "/data1/faceloc02/data/nifti/tb3056/tb3056_static_loc_run01.nii.gz" "/data1/faceloc02/data/nifti/tb3056/tb3056_static_loc_run02.nii.gz" "/data1/faceloc02/data/nifti/tb3056/tb3056_dynamic_loc_run01.nii.gz" "/data1/faceloc02/data/nifti/tb3056/tb3056_dynamic_loc_run02.nii.gz" "/data1/faceloc02/data/nifti/tb3056/tb3056_raiders_movie_run01.nii.gz" "/data1/faceloc02/data/nifti/tb3056/tb3056_raiders_movie_run02.nii.gz" "/data1/faceloc02/data/nifti/tb3056/tb3056_raiders_movie_run03.nii.gz" )


#### Set Variables ####

#subject="tb3056"
#studydir=/data1/faceloc02

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


#### Analysis ####

log_cmd "mkdir ${func[_dir]} 2> /dev/null"

log_echo "=== Motion Correct"
log_tcmd "bash func01_motion_correct.sh -i '${list_inputs[@]}' -o '${func[mc_prefix]}' -w '${func[mc_work]}' -k"

log_echo "=== Skull Strip"
mc_inputs=( $( ls ${func[mc_prefix]}_run*_volreg.nii.gz ) )
log_tcmd "bash func02_skull_strip.sh -p -i '${mc_inputs[@]}' -o ${func[skullstrip_prefix]} -w ${func[skullstrip_work]}"
log_echo "Soft link the mean and example functionals"
log_tcmd "ln -sf '${func[skullstrip_meanfunc]}' '${func[meanfunc]}'" "${func[meanfunc]}"
log_tcmd "ln -sf '${func[skullstrip_mask]}' '${func[mask]}'" "${func[mask]}"
log_tcmd "ln -sf '${func[skullstrip_meanfunc]}' '${func[exfunc]}'"

log_echo "=== Registration"
log_echo "Temp hack for getting white matter from freesurfer segmentation"
log_tcmd "3dcalc -a ${anat[segment]}/aseg/left_cerebral_white_matter.nii.gz -b ${anat[segment]}/aseg/right_cerebral_white_matter.nii.gz -expr 'step(a+b)' -prefix ${anat[segment_wm]}" "${anat[segment_wm]}"
log_tcmd "bash func03_register_highres.sh -i '${func[meanfunc]}' -a '${anat[skullstrip_brain]}' -s '${anat[segment_wm]}' --anathead '${anat[head]}' -o '${func[reg]}'"
log_tcmd "bash func04_register_standard.sh --epireg ${func[reg]} --anatreg ${anat[reg]}"


log_echo "=== Threshold for Smoothing"
median_vals=()
for (( i = 0; i < ${#mc_inputs[@]}; i++ )); do
  median_vals[i]=`fslstats ${mc_inputs[i]} -k ${func[mask]} -p 50`
done
median_val=`echo -e "${median_vals[@]}" | sort -n | awk '{arr[NR]=$1} END { if (NR%2==1) print arr[(NR+1)/2]; else print (arr[NR/2]+arr[NR/2+1])/2}'`
brightness_thr=`echo "$median_val * 0.75" | bc -l`
log_echo "... median_val = ${median_val}"
log_echo "... brightness_thr = ${brightness_thr}"

log_echo "=== Go through each functional scan for remaining preprocessing"
for (( i = 0; i < ${#list_names[@]}; i++ )); do
  name=${list_names[i]}
  infile=${list_inputs[i]}
  
  log_echo "=== Scan: ${name}"
  scandir="${func[_dir]}/${name}" # maybe have some function that sets all the variables
  log_cmd "mkdir ${scandir} 2> /dev/null"
  
  log_echo "== Soft link the relevant functional files"
  log_tcmd "ln -sf ${func[mask]} ${scandir}/mask.nii.gz" "${scandir}/mask.nii.gz"
  log_tcmd "ln -sf ${func[meanfunc]} ${scandir}/mean_func.nii.gz" "${scandir}/mean_func.nii.gz"
  log_tcmd "ln -sf ${func[reg]} ${scandir}/reg"
  # See how many functionals in the output folder to track the current run number
  nruns=$( ls ${scandir}/filtered_func_run*.nii.gz | wc -l )
  nruns=$(( $nruns + 1 ))
  pad_nruns=$( echo $nruns | awk '{printf "%02d", $1}' )
  pad_i=$(( $i + 1 ))
  pad_i=$( echo ${pad_i} | awk '{printf "%02d", $1}' )
  log_tcmd "ln -sf ${func[skullstrip_prefix]}_run${pad_i}.nii.gz ${scandir}/prefiltered_func_run${pad_nruns}.nii.gz" "${scandir}/prefiltered_func_run${pad_nruns}.nii.gz"
  
  log_echo "== Smooth"
  log_tcmd "bash func05_smooth.sh -i ${scandir}/prefiltered_func_run${pad_nruns}.nii.gz --fwhm ${params[fwhm]} -o ${scandir}/prefiltered_func_smooth_run${pad_nruns}.nii.gz --mask ${func[mask]} --meanfunc ${func[meanfunc]} --brightness ${brightness_thr}"
  
  log_echo "== Intensity Normaization"
  log_tcmd "bash func06_inorm.sh -i ${scandir}/prefiltered_func_smooth_run${pad_nruns}.nii.gz -o ${scandir}/prefiltered_func_smooth_inorm_run${pad_nruns}.nii.gz"
  
  log_echo "== Band-Pass Filter"
  log_tcmd "bash func07_filter.sh --lp ${params[low_pass]} --hp ${params[high_pass]} -i ${scandir}/prefiltered_func_smooth_inorm_run${pad_nruns}.nii.gz -o ${scandir}/filtered_func_run${pad_nruns}.nii.gz"  
  
done
