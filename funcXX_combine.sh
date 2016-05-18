#!/bin/bash

#
# For this script, a user should only need to run the following:
#
#     func05_combine.sh -i func-file1 [... func-fileN] -k mask-file -o output-directory [--tr 1] [--motion file] [--polort 2] [--njobs 1] [--overwrite]
#  
#  This script combines the imaging data and timing data across runs
#  using 3dDeconvolve (removing run effects) and timing_tool.py, respectively
#
# 

#### Usage ####

source cmdarg.sh

cmdarg_info "header" "Script for combine the imaging data and timing data across runs"
cmdarg_info "author" "McCarthy Lab <some address>"
## required inputs
cmdarg "i:" "inputs" "Path to functional runs to combine"
cmdarg "o:" "outprefix" "Output prefix"
cmdarg "k:" "mask" "Path to mask"
cmdarg "t:" "tr" "TR of data in seconds"
## optional inputs
cmdarg "m:" "motion" "Path to 6 parameter motion time-series file (already concatenated across subjects). If provided, this will regress out motion effects." ""
cmdarg "c:" "covars" "Additional covariate (e.g., compcor). Two arguments must be given: label filepath" "" ""
cmdarg "p:" "polort" "Number of orthogonal polynomials (default of 2 includes mean, linear, and quadratic)" 2
cmdarg "n:" "njobs" "Number of jobs to run in parallel" 1
cmdarg "f" "force" "Will overwrite any existing output" false
cmdarg "l?" "log" "Log file"
## parse
cmdarg_parse "$@"
[ $# == 0 ] && exit

#### Set Variables ####

inputs=(${cmdarg_cfg['inputs']})
outprefix=${cmdarg_cfg['outprefix']}
mask=${cmdarg_cfg['mask']}
tr=${cmdarg_cfg['tr']}
motion=${cmdarg_cfg['motion']}
covars=(${cmdarg_cfg['covars']})
polort=${cmdarg_cfg['polort']}
njobs=${cmdarg_cfg['njobs']}
overwrite=${cmdarg_cfg['force']}
_LOG_FILE=${cmdarg_cfg['log']}

#CDIR="/mnt/nfs/share/guntherxr/bin"
ext=".nii.gz"
nruns=${#inputs[@]}
covar_label=""
covar_fname=""
if [ ${#covars[@]} -gt 1 ]; then
  covar_label=${covars[0]}
  covar_fname=${covars[1]}
fi
hascovar=false
if [ -n "$covar_label" -a -n "$covar_fname" ]; then hascovar=true; fi

# Additional paths
outmat="${outprefix}_design.1D"
outpic="${outprefix}_design.jpg"
outdat="${outprefix}${ext}"
outmean="${outprefix}_mean${ext}"

log_echo "Setup"

old_afni_deconflict=$AFNI_DECONFLICT
if [ $overwrite == true ]; then
  export AFNI_DECONFLICT="OVERWRITE"
fi

#### Log ####

source log.sh

[ -e ${_LOG_FILE} ] && log_echo "WARNING: log file '${_LOG_FILE}' already exists"

log_echo ""
log_echo "RUNNING: $0 $@"

#### Checks/Setup ####

source io.sh

check_inputs "${inputs[@]}" "$mask"
if [ -n "$motion" ]; then check_inputs "$motion"; fi
check_outputs $overwrite "$outdir" "$outmat" "$outpic" "$outdat" "$outmean"
#[ ! -e $outdir ] && mkdir -p $outdir

  ###
  # Combine Runs
  ###

  log_echo "Combine Runs"
  log_echo "Deconvolve"
  log_echo "Generating design matrix"
  log_echo "Running deconvolve"
  
  cmd="3dDeconvolve -input"
  
  # Inputs
  for x in ${inputs[@]}; do
    cmd="$cmd $x"
  done
  cmd="$cmd -mask ${mask} -force_TR ${tr} -polort ${polort} -jobs ${njobs}"
  
  # Motion covariates
  nstims=0
  stim_str=""
  if [ -n "$motion" ]; then
    motion_labels=('roll' 'pitch' 'yaw' 'dS' 'dL' 'dP')
    for i in `seq 0 5`; do
      let ind=$nstims+$i+1
      stim_str="$stim_str -stim_file ${ind} ${motion}'[${i}]' -stim_base ${ind} -stim_label ${ind} ${motion_labels[i]}"
    done
    let nstims=$nstims+6
  fi
  
  # Additional covariates
  if [ $hascovar == true ]; then
    ncovars=`head -n 1 ${covar_fname} | wc -w`
    let ncovars-1=$ncovars-1
    for i in `seq 0 $ncovars_1`; do
      let ind=$nstims+$i+1
      stim_str="$stim_str -stim_file ${ind} ${covar_fname}'[${i}]' -stim_base ${ind} -stim_label ${ind} ${covar_label}_${i}"
    done
    let nstims=$nstims+$ncovars
  fi
  
  # Number of stimulus time-series
  cmd="$cmd -num_stimts ${nstims} $stim_str"
  
  # Output and output options
  cmd="$cmd -noFDR -nobucket -x1D ${outmat} -xjpeg ${outpic} -errts ${outdat}"
  
  # combine and run
  log_tcmd "$cmd"
  
  # Add back mean to residuals
  log_echo "Add back mean"
  log_tcmd "3dTcat -prefix ${outprefix}_tmp_all_runs${ext} ${inputs[@]}"
  log_tcmd "3dTstat -mean -prefix ${outmean} ${outprefix}_tmp_all_runs${ext}"
  log_tcmd "3dcalc -overwrite -a ${outdat} -b ${outmean} -c ${mask} -expr '(a+b)*step(c)' -prefix ${outdat}"
  log_tcmd "rm -f ${outprefix}_tmp_all_runs${ext}"


  ###
  # Finalize
  ###

  log_echo "Cleaning up"
  
  # Unset AFNI_DECONFLICT
  if [ $overwrite == true ]; then
    export AFNI_DECONFLICT=$old_afni_deconflict
  fi

