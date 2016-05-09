#!/bin/bash

freedir=
anat_regdir=
dxyz=
sd=`dirname $freedir`
subject=`basename $freedir`
ext=".nii.gz"

###
# RUN COMMANDS
###

# set freesurfer subject dir
echo "Setting SUBJECTS_DIR=${sd}"
export SUBJECTS_DIR=$sd

echo "Checking inputs"
if [ ! -e "${anat_regdir}/highres${ext}" -o ! -e "${freedir}/mri" -o ! -e "${freedir}/surf" ]; then exit; fi

echo "Checking outputs"
if [ -e "${freedir}/SUMA" ]; then exit; fi

echo "Converting freesurfer output to use with SUMA"
# if [ $overwrite == "true" ]; then rm -rf ${freedir}/SUMA; fi

echo "Changing into '${freedir}'"
cd $freedir

@SUMA_Make_Spec_FS -sid ${subject} -GIFTI -inflate 200 -inflate 400 -inflate 600 -inflate 800

echo "To view just the anatomical in SUMA, run the following:"
echo "cd ${freedir}/SUMA"
echo "afni -niml &"
echo "suma -spec tb9226_both.spec -sv tb9226_SurfVol.nii"

echo "Changing into '${anat_regdir}'"
cd $anat_regdir

echo "Align surface to highres"
3dcopy ${anat_regdir}/highres${ext} ${anat_regdir}/highres
@SUMA_AlignToExperiment -exp_anat ${anat_regdir}/highres+orig -surf_anat ${freedir}/SUMA/${subject}_SurfVol.nii \
    -atlas_followers -out_dxyz ${dxyz} -prefix highres2surf
rm -f ${anat_regdir}/highres+orig*
  
