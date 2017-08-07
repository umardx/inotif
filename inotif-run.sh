#!/bin/bash
#set -x
DIR=$(dirname $0)
inotif_cfg="$DIR/conf/inotif.cfg"
inotif_dir="$DIR/conf/inotif.dir"
inotig_log="$DIR/log"

addlog(){
  # COMMAND | addlog >> logfile
  infix="$ssh_host $ssh_dir"
  while IFS= read -r line; do
    echo "$(date) $infix $line"
  done
}

exit1() {
  echo "$1"
  exit 1;
}

setup() {
  [ -f $inotif_cfg ] || exit1 "File $inotif_cfg not found!"
  [ -f $inotif_dir ] || exit1 "File $inotif_dir not found!"
  # Load inotif_cfg File.
  source $inotif_cfg;
  # Load inotif_dir File.
  while IFS=':' read -r ssh_host ssh_dir ssh_user ssh_port; do
    [[ $ssh_host = \#* || -z $ssh_host || -z $ssh_dir || -z $ssh_user || -z ssh_port ]] && continue
    echo "$ssh_host * $ssh_dir * $ssh_user * $ssh_port"
    echo "$repo_name * $repo_host * $repo_user * $repo_pass"
    nohup ssh -o StrictHostKeychecking=no -p ${ssh_port} ${ssh_user}@${ssh_host} -T 'sh -s' < $DIR/inotif-ssh.sh "$repo_name" "$repo_host" "$repo_user" "$repo_pass" "$ssh_host" "$ssh_dir" | addlog >> $inotig_log/run.log 2>&1 &
  done  < "$inotif_dir"
}

setup;