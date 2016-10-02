#!/usr/bin/env bash

#
# For this script, a user should only need to run the following:
#
#     func04_register_to_standard.sh -i func-regdir -a anat-regdir
# 
# All the commands with some useful logging information should all be saved.

#### Usage ####

source ${GUNTHERDIR}/include/cmdarg.sh

cmdarg_info "header" "Script for functional registration to standard space"
cmdarg_info "author" "McCarthy Lab <some address>"
## required inputs
cmdarg "i:" "epireg" "Outputs of previously run func-to-highres registration directory"
cmdarg "a:" "anatreg" "Outputs of previously run highres-to-standard registration directory (for now assumes that non-linear has been run)"
## optional inputs
cmdarg "f" "force" "Will overwrite any existing output" false
cmdarg "l?" "log" "Log file"
## parse
cmdarg_parse "$@"
[ $# == 0 ] && exit

#### Set Variables ####

epi_regdir=${cmdarg_cfg['epireg']}
anat_regdir=${cmdarg_cfg['anatreg']}
overwrite=${cmdarg_cfg['force']}
_LOG_FILE=${cmdarg_cfg['log']}
[ ! -z $_LOG_FILE ] && _LOG_FILE=$( readlink -f ${_LOG_FILE} ) # absolute path (if exists)

ext=".nii.gz"
method="fsl"

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

check_inputs "$epi_regdir" "$anat_regdir"

log_echo "Changing directory to ${epi_regdir}"
log_cmd2 "cd $epi_regdir"


###
# Copy over anat inputs
###

log_echo "Soft-link anatomical inputs"
for x in $( ls ${anat_regdir}/* ); do log_cmd "ln -sf $x ./"; done

###
# Combine transforms
###
log_echo "Combining epi-to-anat and anat-to-std affine transforms"

if [ $method == "afni" ]; then
  log_tcmd "3dNwarpCat -prefix exfunc2standard.1D -warp2 exfunc2highres.1D -warp1 highres2standard.1D"
elif [ $method == "fsl" ]; then
  log_tcmd "convert_xfm -omat exfunc2standard.mat -concat highres2standard.mat exfunc2highres.mat"
  log_tcmd "convertwarp --ref=standard --premat=exfunc2highres.mat --warp1=highres2standard_warp --out=exfunc2standard_warp"
elif [ $method == "ants" ]; then
  log_tcmd "c3d_affine_tool -ref highres.nii.gz -src exfunc.nii.gz exfunc2highres.mat -fsl2ras -oitk fsl2ants_exfunc2highres.txt"
  log_tcmd "antsApplyTransforms -d 3 -o Linear[exfunc2standard.mat] -t highres2standard.mat -t fsl2ants_exfunc2highres.txt -r standard.nii.gz"
  log_tcmd "antsApplyTransforms -d 3 -o [exfunc2standard_warp.nii.gz,1] -t highres2standard_warp.nii.gz -t highres2standard.mat -t fsl2ants_exfunc2highres.txt -r standard.nii.gz"
fi


###
# Invert transform
###
log_echo "Inverting exfunc2standard"

if [ $method == "afni" ]; then
  log_tcmd "3dNwarpCat -prefix standard2exfunc.1D -iwarp -warp1 exfunc2standard.1D"
elif [ $method == "fsl" ]; then
  log_tcmd "convert_xfm -inverse -omat standard2exfunc.mat exfunc2standard.mat"
  log_tcmd "convertwarp --ref=exfunc --postmat=highres2exfunc.mat --warp1=standard2highres_warp --out=standard2exfunc_warp"
elif [ $method == "ants" ]; then
  log_tcmd "antsApplyTransforms -d 3 -o Linear[standard2exfunc.mat,1] -t exfunc2standard.mat"
  log_tcmd "antsApplyTransforms -d 3 -o [standard2exfunc_warp.nii.gz,1] -t [fsl2ants_exfunc2highres.txt,1] -t standard2highres.mat -t standard2highres_warp.nii.gz -r standard.nii.gz"
fi


###
# Apply transforms
###
log_echo "Apply transforms"

log_echo "Linear"
if [ $method == "afni" ]; then
  log_tcmd "3dAllineate -source exfunc${ext} -master standard${ext} -1Dmatrix_apply exfunc2standard.1D -prefix exfunc2standard_linear${ext}"
elif [ $method == "fsl" ]; then
  log_tcmd "applywarp --ref=standard --in=exfunc --out=exfunc2standard_linear --premat=exfunc2standard.mat"
elif [ $method == "ants" ]; then
  log_tcmd "antsApplyTransforms -d 3 -o exfunc2standard_linear.nii.gz -t highres2standard.mat -t fsl2ants_exfunc2highres.txt -r standard${ext} -i exfunc${ext}"
fi

log_echo "Non-Linear"
if [ $method == "afni" ]; then
  log_tcmd "3dNwarpApply -nwarp 'highres2standard_WARP${ext} exfunc2standard.1D' -source exfunc${ext} -master standard${ext} -prefix exfunc2standard${ext}"
elif [ $method == "fsl" ]; then
  log_tcmd "applywarp --ref=standard --in=exfunc --out=exfunc2standard --warp=exfunc2standard_warp"
elif [ $method == "ants" ]; then
  log_tcmd "antsApplyTransforms -d 3 -o exfunc2standard.nii.gz -t highres2standard_warp.nii.gz -t highres2standard.mat -t fsl2ants_exfunc2highres.txt -r standard${ext} -i exfunc${ext}"
fi


#### LINK OVER CERTAIN REG FILES ####

# nii
# exfunc => example_func
ext=".nii.gz"
log_cmd "ln -sf exfunc${ext} example_func${ext}"

# mat
# exfunc2highres => example_func2highres
# exfunc2standard => example_func2standard
ext=".mat"
log_cmd "ln -sf exfunc2highres${ext} example_func2highres${ext}"
log_cmd "ln -sf exfunc2standard${ext} example_func2standard${ext}"

# exfunc2standard_warp => example_func2standard_warp
ext=".nii.gz"
log_cmd "ln -sf exfunc2standard_warp${ext} example_func2standard_warp${ext}"


###
# Pictures
###
log_echo "Pretty Pictures"

if [ $overwrite == true ]; then
  sl_opts=" --force" # for slicer.py
else
  sl_opts=""
fi
ext=".nii.gz"
log_tcmd "$python ${GUNTHERDIR}/slicer.py${sl_opts} --auto -r standard${ext} exfunc2standard_linear${ext} exfunc2standard_linear.png"
log_tcmd "$python ${GUNTHERDIR}/slicer.py${sl_opts} --auto -r standard${ext} exfunc2standard${ext} exfunc2standard.png"


###
# Quality Check
###

log_echo "Correlating highres with standard"

cor_lin=`3ddot -docor -mask standard${ext} exfunc2standard_linear${ext} standard${ext}`
cor_nonlin=`3ddot -docor -mask standard${ext} exfunc2standard${ext} standard${ext}`

log_echo "linear exfunc2standard vs standard: ${cor_lin}"
log_echo "non-linear exfunc2standard vs standard: ${cor_nonlin}"

log_echo "saving quality measure to file: quality_exfunc2standard.txt"
log_cmd "echo '${cor_lin} # linear exfunc2standard vs standard' > quality_exfunc2standard.txt"
log_cmd "echo '${cor_nonlin} # non-linear exfunc2standard vs standard' >> quality_exfunc2standard.txt"


###
# Clean up
###

# Unset AFNI_DECONFLICT
if [ $overwrite == true ]; then
  export AFNI_DECONFLICT=$old_afni_deconflict
fi

