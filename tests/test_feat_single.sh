studydir="/data1/faceloc02"
timedir="${studydir}/command/timing"

#subjects="tb1366 tb3190 tb3222"
#subjects="tb3190 tb3222"
subjects="tb3250"
tasks="static_loc dynamic_loc"
pruns="01 02"


for subject in ${subjects}; do
  echo "SUBJECT: ${subject}"
  
  predir="${studydir}/analysis/preprocessed/${subject}"
  taskdir="${studydir}/analysis/task_activity/${subject}"
  mkdir ${predir} 2> /dev/null
  mkdir ${taskdir} 2> /dev/null
  mkdir ${taskdir}/fsfs 2> /dev/null
  
  for task in ${tasks}; do
    echo "-> ${task}"
    
    for prun in ${pruns}; do
      echo "...${prun}"
      run=$( echo $prun | bc -l )
      
      python feat_model_single.py \
        -i "${predir}/func/${task}/filtered_func_run${prun}.nii.gz" \
        -o "${taskdir}/${task}_run${prun}.feat" \
        --outfile "${taskdir}/fsfs/${task}_run${prun}.fsf" \
        --tr 2 --high-pass 100 \
        --prewhiten \
        --stim face "${timedir}/${task}/${subject}_scan${run}_face.txt" "model=double-gamma, filter=true, derivative=false" \
        --stim scene "${timedir}/${task}/${subject}_scan${run}_nonface.txt" "model=double-gamma, filter=true, derivative=false" \
        --glt face "SYM: +face" \
        --glt scene "SYM: +scene" \
        --glt face_gt_scene "SYM: +face -scene" \
        --glt scene_gt_face "SYM: +scene -face"
      [ ! -e "${taskdir}/${task}_run${prun}.feat" ] && feat "${taskdir}/fsfs/${task}_run${prun}"
      
    done
  done
done


# copies over the reg directory!!!
#subject=tb3222
#subject=tb3190
#indir=/data1/faceloc02/analysis/preprocessed/${subject}/func/reg
#outbase=/data1/faceloc02/analysis/task_activity/${subject}
#dirs=( static_loc_run01 static_loc_run02 dynamic_loc_run01 dynamic_loc_run02 )
#for dir in ${dirs[@]}; do
#	bash func_copy_reg.sh -i ${indir} -o ${outbase}/${dir}.feat -f
#done
