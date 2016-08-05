#!/usr/bin/env bash
# 

# temp
#export GUNTHERDIR=$(pwd)


#### Usage ####

source ${GUNTHERDIR}/include/cmdarg.sh

declare -a array
declare -A hash

cmdarg_info "header" "Wrapper script for functional preprocessing"
cmdarg_info "author" "McCarthy Lab <some address>"
## required inputs
#cmdarg "s:" "subject" "Subject ID"
#cmdarg "d:" "studydir" "Study directory"
#cmdarg "i:" ""
cmdarg 'i?[]' 'inputs' 'Some array you can set indexes in'
#cmdarg 'H?{}' 'hash' 'Some hash you can set keys in'
## optional inputs
cmdarg "f" "force" "Will overwrite any existing output" false
cmdarg "l?" "log" "Log file"
## parse
cmdarg_parse "$@"
[ $# == 0 ] && exit


# Parse the inputs
declare -a list_names
declare -a list_inputs
for (( i = 0; i < ${#inputs[@]}; i++ )); do
  list_names[i]=$( echo ${inputs[i]} | awk -F'=' '{print $1}' )
  list_inputs[i]=$( echo ${inputs[i]} | awk -F'=' '{print $2 }' )
done

echo ${list_names[@]}
echo ${list_inputs[@]}

#your_script -a 32 --array something -H key=value --hash other_key=value
