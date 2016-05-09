# DEPENDS on log.sh

function check_inputs {
  while [[ $# -ne 0 ]]; do
    var="$1"; shift
    [ ! -e "$var" ] && log_die "input '${var}' doesn't exist"
  done
}

function check_outputs {
  overwrite=$1; shift
  while [[ $# -ne 0 ]]; do
    var="$1"; shift
    if [ -e ${var} ]; then
      if [ $overwrite == true ]; then
        log_echo "removing existing output '${var}'"
        log_cmd "rm ${var}"
      else
        log_die "output '${var}' already exists"
      fi
    fi
  done
}

# we also load the path for python and R
python="/home/zshehzad/anaconda/bin/python"
rscript="/usr/bin/Rscript"
afnidir="$( dirname $( which afni ) )"
