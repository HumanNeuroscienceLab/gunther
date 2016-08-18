declare -A anat
declare -A func

# General
preprocdir="${studydir}/analysis/preprocessed/${subject}"
sddir="${studydir}/analysis/freesurfer"
freesurferdir="${studydir}/analysis/freesurfer/${subject}"

# Anatomical files
anatdir="${preprocdir}/anat"
anat['_dir']="${anatdir}"
anat['log']="${anatdir}/log_anat_preproc_$(date +'%Y-%m-%d')_time-$(date +'%H-%M-%S').txt"
## input
anat['head']="${anatdir}/head.nii.gz"
anat['t2_head']="${anatdir}/t2_head.nii.gz"
## skull-strip script
anat['skullstrip']="${anatdir}/skullstrip"
anat['skullstrip_prefix']="${anatdir}/skullstrip/brain"
anat['skullstrip_brain']="${anatdir}/skullstrip/brain.nii.gz"
anat['skullstrip_brainmask']="${anatdir}/skullstrip/brain_mask.nii.gz"
## registration script
anat['reg']="${anatdir}/reg" # TODO: name individual registration files?
## segmentation script
anat['segment']="${anatdir}/segment"
anat['segment_wm']="${anatdir}/segment/white_matter.nii.gz"
## atlases script
anat['atlases']="${anatdir}/atlases"
## done text
anat['done']="${anatdir}/done"

# Functional files
funcdir="${preprocdir}/func"
func['_dir']="${funcdir}"
func['log']="${funcdir}/log_func_preproc_$(date +'%Y-%m-%d')_time-$(date +'%H-%M-%S').txt"
# General
func['mask']="${funcdir}/mask.nii.gz"
func['meanfunc']="${funcdir}/mean_func.nii.gz"
func['exfunc']="${funcdir}/example_func.nii.gz"
# Motion correct
func['mc']="${funcdir}/mc"
func['mc_prefix']="${funcdir}/mc/func"
func['mc_work']="${funcdir}/mc_work"
# Skull Strip
func['skullstrip']="${funcdir}/skullstrip"
func['skullstrip_work']="${funcdir}/skullstrip_work"
func['skullstrip_prefix']="${funcdir}/skullstrip/func"
func['skullstrip_meanfunc']="${funcdir}/skullstrip/func_mean.nii.gz"
func['skullstrip_mask']="${funcdir}/skullstrip/func_mask.nii.gz"
# Registration
func['reg']="${funcdir}/reg"


function create_subject_dirs {
  [ ! -e ${preprocdir} ] && mkdir ${preprocdir} 2> /dev/null
  [ ! -e ${anat[_dir]} ] && mkdir ${anat[_dir]} 2> /dev/null
  [ ! -e ${func[_dir]} ] && mkdir ${func[_dir]} 2> /dev/null
}

function set_anat_logfile {
  _LOG_FILE=${anat[log]}
  echo "Setting log path to ${_LOG_FILE}"
}

function set_func_logfile {
  _LOG_FILE=${func[log]}
  echo "Setting log path to ${_LOG_FILE}"
}
