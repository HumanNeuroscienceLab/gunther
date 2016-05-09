## TODO: add quiet option
if [[ -z ${_LOG_FILE} ]]; then
  function log_echo() {
    echo "$@"
  }
  
  function log_exec() {
    eval "$@"
    return $?
  }
  
  log_exec2 () {
    eval "$@"
    return $?
  }
else
  function log_echo() {
    echo "$@" | tee -a ${_LOG_FILE}
  }
  
  function log_exec() {
    echo "$@" >> ${_LOG_FILE}.cmd # just have commmands in a file
    eval "$@ 2>&1 | tee -a ${_LOG_FILE}"
    return $?
  }
  
  # This is a temporary fix for when you want to cd or set a variable
  # It first checks if it can execute the command locally
  # Then tries to run it for everything
  log_exec2 () {
    echo "$@" >> ${_LOG_FILE}.cmd # just have commmands in a file
    ( set -o pipefail; eval "$@ 2>&1 | tee -a ${_LOG_FILE}" ); ST=$?
    [ $ST -eq 0 ] && eval "$@"
    return $ST
  }
fi

# check for logfile
function check_logfile() {
  if [[ ! -z ${_LOG_FILE} ]]; then
    [[ -e ${_LOG_FILE} ]] && log_echo "WARNING: log file '${_LOG_FILE}' already exists"
    log_echo "Logging to '${_LOG_FILE}'"
    log_echo "Saving commands to '${_LOG_FILE}.cmd'"
  else
    log_echo "No log file set"
  fi
}

function log_cmd() {
  log_echo "$@"
  log_exec "$@"
  ret="$?"
  #[ $ret -ne 0 ] && log_die "Non-zero return from command...time to make a smooth exit"
  return $ret
}

log_cmd2 () {
  log_echo "$@"
  log_exec2 "$@"
  ret="$?"
  return $ret
}

function log_echo() {
  echo "$@" | tee -a ${_LOG_FILE}
}

function log_tcmd {
  log_echo "[$(date +'%b %e %R')]: $@"
  log_exec "$@"
  ret="$?"
  return $ret
}

function log_tcmd2 {
  log_echo "[$(date +'%b %e %R')]: $@"
  log_exec2 "$@"
  ret="$?"
  return $ret
}

function log_die() {
  log_echo "$@"
  exit 1
}

function log_time() {
  log_echo `date +'%b %e %R '`
}
