
subject=
studydir="/data1/faceloc02"
datadir="${studydir}/data/nifti/${subject}"

bash preproc_anat.sh -s ${subject} -d ${studydir}\
  -c 8 \
  -i ${datadir}/${subject}_t1w.nii.gz \
  -t ${datadir}/${subject}_t2w.nii.gz

bash preproc_func.sh -s ${subject} -d ${studydir} \
  -p fwhm=4 -p high_pass=100 \
  -i rest=${datadir}/${subject}_rest.nii.gz \
  -i static_loc=${datadir}/${subject}_static_loc_run01.nii.gz \
  -i static_loc=${datadir}/${subject}_static_loc_run02.nii.gz \
  -i dynamic_loc=${datadir}/${subject}_dynamic_loc_run01.nii.gz \
  -i dynamic_loc=${datadir}/${subject}_dynamic_loc_run02.nii.gz \
  -i raiders=${datadir}/${subject}_raiders_movie_run01.nii.gz \
  -i raiders=${datadir}/${subject}_raiders_movie_run02.nii.gz \
  -i raiders=${datadir}/${subject}_raiders_movie_run03.nii.gz



====

subject=tb1366
studydir="/data1/faceloc02"
datadir="${studydir}/data/nifti/${subject}"

bash preproc_anat.sh -s ${subject} -d ${studydir}\
  -c 8 \
  -i ${datadir}/${subject}_t1w.nii.gz \
  -t ${datadir}/${subject}_t2w.nii.gz

bash preproc_func.sh -s ${subject} -d ${studydir} \
  -p fwhm=4 -p high_pass=100 \
  -i rest=${datadir}/${subject}_rest.nii.gz \
  -i static_loc=${datadir}/${subject}_static_loc_run01.nii.gz \
  -i static_loc=${datadir}/${subject}_static_loc_run02.nii.gz \
  -i dynamic_loc=${datadir}/${subject}_dynamic_loc_run01.nii.gz \
  -i dynamic_loc=${datadir}/${subject}_dynamic_loc_run02.nii.gz \
  -i raiders=${datadir}/${subject}_raiders_movie_run01.nii.gz \
  -i raiders=${datadir}/${subject}_raiders_movie_run02.nii.gz \
  -i raiders=${datadir}/${subject}_raiders_movie_run03.nii.gz

====

subject=tb3190
studydir="/data1/faceloc02"
datadir="${studydir}/data/nifti/${subject}"

bash preproc_anat.sh -s ${subject} -d ${studydir}\
  -c 8 \
  -i ${datadir}/${subject}_t1w.nii.gz \
  -t ${datadir}/${subject}_t2w.nii.gz

bash preproc_func.sh -s ${subject} -d ${studydir} \
  -i rest=${datadir}/${subject}_rest.nii.gz \
  -p fwhm=4 -p high_pass=100 \
  -i static_loc=${datadir}/${subject}_static_loc_run01.nii.gz \
  -i static_loc=${datadir}/${subject}_static_loc_run02.nii.gz \
  -i dynamic_loc=${datadir}/${subject}_dynamic_loc_run01.nii.gz \
  -i dynamic_loc=${datadir}/${subject}_dynamic_loc_run02.nii.gz

# TODO: preprocess the raiders data for this subject

====

subject=tb3222
studydir="/data1/faceloc02"
datadir="${studydir}/data/nifti/${subject}"

bash preproc_anat.sh -s ${subject} -d ${studydir}\
  -c 8 \
  -i ${datadir}/${subject}_t1w.nii.gz \
  -t ${datadir}/${subject}_t2w.nii.gz

bash preproc_func.sh -s ${subject} -d ${studydir} \
  -i rest=${datadir}/${subject}_rest.nii.gz \
  -p fwhm=4 -p high_pass=100 \
  -i static_loc=${datadir}/${subject}_static_loc_run01.nii.gz \
  -i static_loc=${datadir}/${subject}_static_loc_run02.nii.gz \
  -i dynamic_loc=${datadir}/${subject}_dynamic_loc_run01.nii.gz \
  -i dynamic_loc=${datadir}/${subject}_dynamic_loc_run02.nii.gz \
  -i raiders=${datadir}/${subject}_raiders_movie_run01.nii.gz \
  -i raiders=${datadir}/${subject}_raiders_movie_run02.nii.gz \
  -i raiders=${datadir}/${subject}_raiders_movie_run03.nii.gz


tb1366	tb3056	tb3190	tb3222
