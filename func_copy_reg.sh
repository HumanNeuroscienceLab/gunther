#!/usr/bin/env bash

#### Usage ####

source ${GUNTHERDIR}/include/cmdarg.sh

cmdarg_info "header" "Script for functional skull-strip"
cmdarg_info "author" "McCarthy Lab <some address>"
## required inputs
cmdarg "i:" "input" "Input registration directory"
cmdarg "o:" "output" "Output feat directory"
## optional inputs
cmdarg "f" "force" "Will overwrite any existing output" false
cmdarg "l?" "log" "Log file"
## parse
cmdarg_parse "$@"
[ $# == 0 ] && exit


#### Set Variables ####

indir=( ${cmdarg_cfg['input']} )
featdir=${cmdarg_cfg['output']}
overwrite=${cmdarg_cfg['force']}
_LOG_FILE=${cmdarg_cfg['log']}
[ ! -z $_LOG_FILE ] && _LOG_FILE=$( readlink -f ${_LOG_FILE} ) # absolute path (if exists)

outdir="${featdir}/reg"

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

[ -e ${outdir} ] && [ $overwrite == true ] && log_cmd "rm ${outdir}"
[ -e ${outdir} ] && [ $overwrite == true ] && log_cmd "rm ${outdir}/*; rmdir ${outdir}"

check_inputs ${indir} ${featdir}
check_outputs ${outdir}

# get full paths since changing paths
indir=$( readlink -f ${indir} )
featdir=$( readlink -f ${featdir} )
outdir="${featdir}/reg"

# recheck inputs
check_inputs ${indir} ${featdir}

# create output directory
[ ! -e $outdir ] && log_cmd "mkdir $outdir"


#### COPY OVER REG FILES ####

# nii
# exfunc => example_func
# highres => highres
# standard => standard
ext=".nii.gz"
log_cmd "cp ${indir}/exfunc${ext} ${outdir}/example_func${ext}"
log_cmd "cp ${indir}/highres${ext} ${outdir}/highres${ext}"
log_cmd "cp ${indir}/standard${ext} ${outdir}/standard${ext}"

# mat
# exfunc2highres => example_func2highres
# highres2standard => highres2standard
ext=".mat"
log_cmd "cp ${indir}/exfunc2highres${ext} ${outdir}/example_func2highres${ext}"
log_cmd "cp ${indir}/highres2standard${ext} ${outdir}/highres2standard${ext}"
log_cmd "cp ${indir}/exfunc2standard${ext} ${outdir}/example_func2standard${ext}"

# warp
# highres2standard_warp => highres2standard_warp
# exfunc2standard_warp => example_func2standard_warp
ext=".nii.gz"
log_cmd "cp ${indir}/highres2standard_warp${ext} ${outdir}/highres2standard_warp${ext}"
log_cmd "cp ${indir}/exfunc2standard_warp${ext} ${outdir}/example_func2standard_warp${ext}"


# Unset AFNI_DECONFLICT
if [ $overwrite == true ]; then
  export AFNI_DECONFLICT=$old_afni_deconflict
fi
