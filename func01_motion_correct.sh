#!/usr/bin/env bash

#  This script applies motion correction using AFNI's 3dvolreg across runs.
#  Correction is done to the average functional image in two stages.
#
# For this script, a user should only need to run the following:
#
#     $0 -o outprefix -w working-directory -i func-file1 [... func-fileN]
#
#
# All the commands with some useful logging information should all be saved.


#### Usage ####

source ${GUNTHERDIR}/include/cmdarg.sh

cmdarg_info "header" "Script for functional motion correction"
cmdarg_info "author" "McCarthy Lab <some address>"
## required inputs
cmdarg "i:" "inputs" "Path to functional runs to motion correct"
cmdarg "o:" "outprefix" "Output prefix"
cmdarg "w:" "workdir" "Path to working directory"
## optional inputs
cmdarg "m:" "meanfunc" "Path to mean functional. If provided, each scan will be motion corrected to this image skipping any internal generation of a mean functional image" ""
cmdarg "j:" "njobs" "Number of parallel jobs" 1
cmdarg "k" "keepwdir" "Keep working directory" false
cmdarg "f" "force" "Will overwrite any existing output" false
cmdarg "l?" "log" "Log file"
## parse
cmdarg_parse "$@"
[ $# == 0 ] && exit

#### Set Variables ####

inputs=( ${cmdarg_cfg['inputs']} )
outprefix=${cmdarg_cfg['outprefix']}
workdir=${cmdarg_cfg['workdir']}
meanfunc=${cmdarg_cfg['meanfunc']}
njobs=${cmdarg_cfg['njobs']}
keepwdir=${cmdarg_cfg['keepwdir']}
overwrite=${cmdarg_cfg['force']}
_LOG_FILE=${cmdarg_cfg['log']}
[ ! -z $_LOG_FILE ] && _LOG_FILE=$( readlink -f ${_LOG_FILE} ) # absolute path (if exists)

ext=".nii.gz"

nruns=${#inputs[@]}
outdir=$(dirname $outprefix)

old_afni_deconflict=$AFNI_DECONFLICT
if [ $overwrite == true ]; then
  export AFNI_DECONFLICT="OVERWRITE"
fi


#### Log ####

source ${GUNTHERDIR}/include/log.sh

check_logfile

log_echo ""
log_echo "RUNNING: $0 $@"
log_echo "- nruns: $nruns"
log_echo "- njobs: $njobs"


#### Checks/Setup ####

source ${GUNTHERDIR}/include/io.sh

check_inputs ${inputs[@]}
[ ! -z ${meanfunc} ] && check_inputs ${meanfunc}
check_outputs $overwrite "$workdir"
[ ! -e $outdir ] && mkdir -p $outdir
[ ! -e $workdir ] && mkdir -p $workdir

# get full paths since changing paths
workdir=$( readlink -f ${workdir} )
outdir=$( readlink -f ${outdir} )
if [ ! -z ${meanfunc} ]; then
  meanfunc=$( readlink -f ${meanfunc} )
fi
for (( i = 0; i < ${#inputs[@]}; i++ )); do
  inputs[$i]=$( readlink -f ${inputs[$i]} )
done

# recheck inputs
check_inputs ${inputs[@]}
[ ! -z ${meanfunc} ] && check_inputs ${meanfunc}

# Work in the working directory
log_cmd2 "cd $workdir"


###
# First and Second Pass
###

if [[ -z "${meanfunc}" ]]; then
  meanfunc="${workdir}/init_mean_functional${ext}"
  
  log_echo "=== First and Second Passes"
  # We will call another script to get the mean of the functionals
  log_tcmd "func_mean_functionals.sh -i '${inputs[*]}' -w ${workdir}/meaner -o ${meanfunc} -j ${njobs}"  
else
  log_echo "=== Skipping First and Second Passes using provided meanfunc instead"
fi


###
# Third and Final Pass
###

log_echo "=== Third and Final Pass"

# Get the range of scan numbers with padding of 2
ris=()
for i in `seq 1 $nruns`; do
  ri=`echo $i | awk '{printf "%02d", $1}'`
  ris+=($ri)
done

log_echo "...apply motion correction to prior mean EPI"
log_tcmd "parallel --xapply --no-notice -j $njobs --eta 3dvolreg -verbose -zpad 4 -base ${meanfunc} -maxdisp1D iter3_maxdisp_r{1}.1D -1Dfile iter3_dfile_r{1}.1D -1Dmatrix_save iter3_mat_r{1}_vr_aff12.1D -prefix iter3_epi_volreg_r{1}${ext} -twopass -Fourier {2} ::: ${ris[*]} ::: ${inputs[*]}"

log_echo "...new mean EPI of motion-corrected data"
log_tcmd "parallel --xapply --no-notice -j $njobs --eta 3dTstat -mean -prefix iter3_mean_epi_r{1}${ext} iter3_epi_volreg_r{1}${ext} ::: ${ris[*]}"

#for i in `seq 1 $nruns`; do
#  ri=`echo $i | awk '{printf "%02d", $1}'`
#  input=${inputs[i-1]}
#  log_echo "Motion correct run ${ri}"
#  # Apply motion correction to prior mean EPI
#  log_tcmd "3dvolreg -verbose -zpad 4 -base init_mean_functional${ext} -maxdisp1D iter3_maxdisp_r${ri}.1D -1Dfile iter3_dfile_r${ri}.1D -1Dmatrix_save iter3_mat_r${ri}_vr_aff12.1D -prefix iter3_epi_volreg_r${ri}${ext} -twopass -Fourier ${input}"
#  # New mean EPI of motion-corrected data
#  log_tcmd "3dTstat -mean -prefix iter3_mean_epi_r${ri}${ext} iter3_epi_volreg_r${ri}${ext}"
#done

# Combine mean EPIs from each run
log_echo "Combine mean EPIs"
log_tcmd "3dTcat -prefix iter3_mean_epis${ext} iter3_mean_epi_r*${ext}"

# Get mean EPI across runs
log_echo "Get mean EPI across runs"
log_tcmd "3dTstat -mean -prefix iter3_mean_mean_epi${ext} iter3_mean_epis${ext}"


###
# Save
###

log_echo "=== Saving"

# This takes as input a filename in the working directory
# and then an output file
# It will mv the file 
# and then create a soft-link from old to new location
function move_file { 
  #(infile, outfile)
  log_cmd "mv $1 $2"
  log_cmd "ln -s $2 $1"
}

# Here we move the relevant outputs and then create a soft-link in the working directory
log_echo "Save output files"
for i in `seq 1 $nruns`; do
  ri=`echo $i | awk '{printf "%02d", $1}'`
  log_echo "== run ${ri}"
  move_file "iter3_maxdisp_r${ri}.1D" "${outprefix}_run${ri}_maxdisp.1D"
  move_file "iter3_dfile_r${ri}.1D" "${outprefix}_run${ri}_dfile.1D"
  move_file "iter3_mat_r${ri}_vr_aff12.1D" "${outprefix}_run${ri}_mat_vr_aff12.1D"
  move_file "iter3_epi_volreg_r${ri}${ext}" "${outprefix}_run${ri}_volreg${ext}"
done
# make a single file of registration params and get mean
log_tcmd "cat iter3_dfile_r??.1D > ${outprefix}_runall_dfile.1D"
move_file "iter3_mean_mean_epi${ext}" "${outprefix}_mean${ext}"


###
# Framewise Displacement
###

log_echo "=== Calculate framewise displacement"

for i in `seq 1 $nruns`; do
  ri=`echo $i |awk '{printf "%02d", $1}'`
  log_echo "== run ${ri}"
  log_tcmd "$python ${GUNTHERDIR}/func_motion_fd.py ${outprefix}_run${ri}_mat_vr_aff12.1D ${outprefix}_run${ri}_fd"
done
log_tcmd "cat ${outprefix}_run??_fd_abs.1D > ${outprefix}_runall_fd_abs.1D"
log_tcmd "cat ${outprefix}_run??_fd_rel.1D > ${outprefix}_runall_fd_rel.1D"


###
# Visualization
###

log_echo "=== Plot Motion"

# get range of 6 motion parameters
rot_max=`3dBrickStat -absolute -max -slow ${outprefix}_runall_dfile.1D'[0..2]'\'`
disp_max=`3dBrickStat -absolute -max -slow ${outprefix}_runall_dfile.1D'[3..5]'\'`
rot_max=`echo $rot_max | awk '{print 1.025*$1}'` # pad by 5%
disp_max=`echo $disp_max | awk '{print 1.025*$1}'` # pad by 5%
log_echo "setting rotations range to ${rot_max} radians"
log_echo "setting displacements range to ${disp_max} mm"

# get range of fd
abs_max=`3dBrickStat -absolute -max -slow ${outprefix}_runall_fd_abs.1D\'`
abs_max=`echo $abs_max|awk '{print 1.025*$1}'`
log_echo "setting absolute fd range to ${abs_max} mm"
# note that the relative fd will always be set to a minimum max range of 2mm
rel_max=`3dBrickStat -absolute -max -slow ${outprefix}_runall_fd_rel.1D\'`
temp=`echo "$rel_max" '<' 2 | bc -l`
if [ $temp == 1 ]; then rel_max=2.0; fi
rel_max=`echo $rel_max | awk '{print 1.025*$1}'`
log_echo "setting relative fd range to ${rel_max} mm"
# adjust the height of relative fd relative to the max
rel_height=`echo $rel_max | awk '{printf "%d", $1*144.0/2.05}'`

for i in `seq 1 $nruns`; do
  ri=`echo $i | awk '{printf "%02d", $1}'`
  log_echo "\n== run ${ri}"
  log_cmd "fsl_tsplot -i ${outprefix}_run${ri}_dfile.1D -t 'Run ${ri} - Rotations (radians)' --ymin=-${rot_max} --ymax=${rot_max} -u 1 --start=1 --finish=3 -a roll,pitch,yaw -w 640 -h 144 -o ${outprefix}_run${ri}_plot_rot.png"
  log_cmd "fsl_tsplot -i ${outprefix}_run${ri}_dfile.1D -t 'Run ${ri} - Translations (mm)' --ymin=-${disp_max} --ymax=${disp_max} -u 1 --start=4 --finish=6 -a dS,dL,dP -w 640 -h 144 -o ${outprefix}_run${ri}_plot_trans.png"
  log_cmd "fsl_tsplot -i ${outprefix}_run${ri}_fd_abs.1D -t 'Run ${ri} - Mean Displacement (mm) - Absolute' -u 1 -w 640 -h 144 -o ${outprefix}_run${ri}_plot_fd_abs.png"
  log_cmd "fsl_tsplot -i ${outprefix}_run${ri}_fd_rel.1D --ymin=0 --ymax=${rel_max} -t 'Run ${ri} - Mean Displacement (mm) - Relative' -u 1 -w 640 -h ${rel_height} -o ${outprefix}_run${ri}_plot_fd_rel.png"
done


###
# Covariates For Later Regressions
###

log_echo "=== Create Files For Later Regressionzzz"

log_echo "collecting the run lengths"
srunlengths=()
for i in `seq 1 $nruns`; do
  ri=`echo $i | awk '{printf "%02d", $1}'`
  nvols=`fslnvols ${outprefix}_run${ri}_volreg${ext}`
  srunlengths[$((i-1))]=$nvols
done

log_echo "compute de-meaned motion parameters (for use in regression)"
log_tcmd "${python} ${afnidir}/1d_tool.py -infile ${outprefix}_runall_dfile.1D -set_run_lengths ${srunlengths[*]} -demean -write ${outprefix}_motion_demean.1D"

log_echo "compute motion parameter derivatives (just to have)"
log_tcmd "${python} ${afnidir}/1d_tool.py -infile ${outprefix}_runall_dfile.1D -set_run_lengths ${srunlengths[*]} -derivative -demean -write ${outprefix}_motion_deriv_demean.1D"

log_echo "create file for censoring motion"
log_tcmd "${python} ${afnidir}/1d_tool.py -infile ${outprefix}_runall_dfile.1D -set_run_lengths ${srunlengths[*]} -show_censor_count -censor_prev_TR -censor_motion 1.25 ${outprefix}_motion" 

# TODO: demean each run separately as well?


###
# Finalize
###

log_echo "=== Clean up"
if [ $keepwdir == false ]; then
  log_echo "Removing working directory"
  log_cmd "cd $outdir"
  log_cmd "rm ${workdir}/*"
  log_cmd "rmdir ${workdir}"
fi

# Unset AFNI_DECONFLICT
if [ $overwrite == true ]; then
  export AFNI_DECONFLICT=$old_afni_deconflict
fi
