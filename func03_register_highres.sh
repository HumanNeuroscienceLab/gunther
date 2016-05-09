#!/usr/bin/env bash

#
# For this script, a user should only need to run the following:
#
#     func03_register_to_highres.sh -i example_func_brain.nii.gz -a highres_brain.nii.gz -o output-directory -t highres_head.nii.gz [-w highres_wmseg.nii.gz]"
# 
# All the commands with some useful logging information should all be saved.


#### Usage ####

source ${GUNTHERDIR}/include/cmdarg.sh

cmdarg_info "header" "Script for functional registration to high res subject image"
cmdarg_info "author" "McCarthy Lab <some address>"
## required inputs
cmdarg "i:" "epi" "Input functional brain (must be skull stripped)"
cmdarg "o:" "outdir" "Path to output directory"
cmdarg "a:" "anat" "Input anatomical brain (must be skull stripped)"
## inputs with defaults
cmdarg "d:" "dof" "Degrees of Freedom: shift_only (3), shift_rotate (6), shift_rotate_scale (9), or affine_general (12)" 6
cmdarg "f" "force" "Will overwrite any existing output" false
## optional inputs
cmdarg "s?" "wmseg" "White matter segmentation"
cmdarg "t?" "anathead" "Input anatomical head"
cmdarg "l?" "log" "Log file"
## parse
cmdarg_parse "$@"
[ $# == 0 ] && exit


#### Set Variables ####

epi=${cmdarg_cfg['epi']}
outdir=${cmdarg_cfg['outdir']}
anat=${cmdarg_cfg['anat']}
dof=${cmdarg_cfg['dof']}
wmseg=${cmdarg_cfg['wmseg']}
anathead=${cmdarg_cfg['anathead']}
overwrite=${cmdarg_cfg['force']}
_LOG_FILE=${cmdarg_cfg['log']}
[ ! -z $_LOG_FILE ] && _LOG_FILE=$( readlink -f ${_LOG_FILE} ) # absolute path (if exists)

ext=".nii.gz"

# check inputs
[[ ! -z ${wmseg} ]] && [[ -z ${anathead} ]] && log_die "You must --anathead with --wmseg"
[[ -z ${wmseg} ]] && [[ ! -z ${anathead} ]] && log_die "You must --wmseg with --anathead"

# afni overwrite
old_afni_deconflict=$AFNI_DECONFLICT
if [ $overwrite == true ]; then
  export AFNI_DECONFLICT="OVERWRITE"
fi


#### Log ####

source ${GUNTHERDIR}/include/log.sh

check_logfile

log_echo ""
log_echo "RUNNING: $0 $@"


#### Checks/Setup ####

source ${GUNTHERDIR}/include/io.sh

check_inputs "$epi" "$anat" "$anathead"
check_outputs $overwrite "$outdir"
[ ! -e $outdir ] && mkdir -p $outdir

# get full paths since changing paths
epi=$( readlink -f ${epi} )
anat=$( readlink -f ${anat} )
anathead=$( readlink -f ${anathead} )
outdir=$( readlink -f ${outdir} )


###
# RUN COMMANDS
###
cmd='fsl'
method=$cmd

log_echo "Changing directory to ${outdir}"
log_cmd2 "cd $outdir"

log_echo "Copy files"
log_tcmd "3dcalc -a ${epi} -expr a -prefix ${outdir}/exfunc${ext} -datum float"
log_tcmd "3dcalc -a ${anat} -expr a -prefix ${outdir}/highres${ext} -datum float"


###
# AFNI - deleted
###

###
# FSL
###
if [ -z ${wmseg} ]; then
  # If no bbreg then do a simple flirt command
  log_echo "Transforming exfunc to highres without BBR"
  log_tcmd  "flirt -in ${epi} -ref ${anat} -dof 6 -omat ${outdir}/exfunc2highres.mat -out ${outdir}/exfunc2highres.nii.gz"
else
  log_echo "Transforming exfunc to highres with BBR"
  log_tcmd "epi_reg --epi=${epi} --t1=${anathead} --t1brain=${anat} --out=${outdir}/exfunc2highres --wmseg=${wmseg}"
fi
log_echo "Inverting affine matrix (highres -> func)"
log_tcmd "convert_xfm -inverse -omat ${outdir}/highres2exfunc.mat ${outdir}/exfunc2highres.mat"


###
# Pictures
###
log_echo "Pretty Pictures"

if [ $overwrite == true ]; then
  sl_opts=" --force" # for slicer.py
else
  sl_opts=""
fi

log_tcmd "$python ${GUNTHERDIR}/slicer.py${sl_opts} --auto -r ${outdir}/highres${ext} ${outdir}/exfunc2highres${ext} ${outdir}/exfunc2highres.png"
if [ ! -z ${wmseg} ]; then
  ## exfunc2highres
  log_tcmd "$python ${GUNTHERDIR}/slicer.py${sl_opts} --crop -s axial -w 4 -l 3 --overlay ${outdir}/exfunc2highres_fast_wmseg${ext} 1 1 ${outdir}/exfunc2highres${ext} ${outdir}/exfunc2highres_wmseg.png"
  log_tcmd "$python ${GUNTHERDIR}/slicer.py${sl_opts} --crop -s axial -w 4 -l 3 --overlay ${outdir}/exfunc2highres_fast_wmedge${ext} 1 1 -t ${outdir}/exfunc2highres${ext}  ${outdir}/exfunc2highres_wmedge.png"
  ## highres
  log_tcmd "$python ${GUNTHERDIR}/slicer.py${sl_opts} --crop -s axial -w 4 -l 3 --overlay ${outdir}/exfunc2highres_fast_wmseg${ext} 1 1 ${outdir}/highres${ext} ${outdir}/highres_wmseg.png"
  log_tcmd "$python ${GUNTHERDIR}/slicer.py${sl_opts} --crop -s axial -w 4 -l 3 --overlay ${outdir}/exfunc2highres_fast_wmedge${ext} 1 1 -t ${outdir}/highres${ext}  ${outdir}/highres_wmedge.png"
fi


###
# Quality Check
###
log_echo "Correlating highres with exfunc2highres"

log_cmd2 "cor_lin=`3ddot -docor -mask ${outdir}/highres${ext} ${outdir}/exfunc2highres${ext} ${outdir}/highres${ext}`"

log_echo "linear exfunc2highres vs highres: ${cor_lin}"
log_echo "saving this to file: ${outdir}/quality_exfunc2highres.txt"
log_cmd "echo '${cor_lin} # exfunc2highres vs highres' > quality_exfunc2highres.txt"

