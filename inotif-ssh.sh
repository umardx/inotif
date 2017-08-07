#!/bin/sh
#set -x
: '
./inotif-ssh.sh \
-n inotif.git \
-h 192.168.114.30 \
-u git \
-p passwordforgit \
-b 192.168.20.138 \
-d /etc/

repo_name="inotif.git"
repo_host="192.168.114.30"
repo_user="git"
repo_pass="passwordforgit"
branch_host="192.168.20.138"
branch_dir="/etc"
'

# Capture required variables
# METHOD 1
repo_name="${1}"
repo_host="${2}"
repo_user="${3}"
repo_pass="${4}"
branch_host="${5}"
branch_dir="${6%/}"

# Capture required variables
# METHOD 2
: '
while getopts ":n:h:u:p:b:d:" opt; do
  case $opt in
    n)	repo_name="${OPTARG}"
    ;;
    h)	repo_host="${OPTARG}"
    ;;
    u)	repo_user="${OPTARG}"
    ;;
    p)	repo_pass="${OPTARG}"
    ;;
    b)	branch_host="${OPTARG}"
    ;;
    d)	branch_dir="${OPTARG%/}"
    ;;
    \?) echo "invalid option -$OPTARG"
		how_to_use;
    ;;
  esac
done
'

how_to_use() {
	echo "./inotif-ssh.sh"
	echo "[-n repo_name]"
	echo "[-h repo_host:port]"
	echo "[-u repo_user]"
	echo "[-p repo_pass]"
	echo "[-b branch_host]"
	echo "[-d branch_dir]"
	exit 0
}

exit1() {
  echo "$1"
  exit 1;
}

setup_comm_git() {
	rsync -aq --delete --max-size=1.0m --exclude=.git* --exclude=.git $branch_dir/ ~/.inotif$branch_dir/ > /dev/null 2>&1
}

check_requirements() {
	# checking required variables
	if [ -z $repo_name ] || [ -z $repo_host ] || [ -z $repo_user ] || [ -z $repo_pass ] || [ -z $branch_host ] || [ -z $branch_dir ]; then
		exit1 "input variable not completed."
	fi

	# checking dependency in remote ssh host
	hash git > /dev/null 2>&1 || exit1 "git not installed."
	hash rsync > /dev/null 2>&1 || exit1 "rsync not installed."
	hash sshpass > /dev/null 2>&1 || exit1 "sshpass not installed."

	# checking branch_dir
	[ -d $branch_dir > /dev/null 2>&1 ] || exit1 "The $branch_dir directory doesn't exist."
}

setup_repo_git() {
	# Test connection
	sshpass -p $repo_pass ssh -o StrictHostKeychecking=no ${repo_user}@${repo_host} -t ':' > /dev/null 2>&1 || echo "The connection to repo_host error."
	# Create branch_dir if doesn't exist.
	[ -d ~/.inotif$branch_dir > /dev/null 2>&1 ] || (mkdir -p ~/.inotif$branch_dir)
	cd ~/.inotif$branch_dir
	# Clone branch_dir from remote repository if git not installed on branch_dir.
	if [ ! -d ~/.inotif$branch_dir/.git > /dev/null 2>&1 ]; then
		sshpass -p $repo_pass git clone -b "$branch_host$branch_dir" ssh://${repo_user}@${repo_host}/git/${repo_name} ./ > /dev/null 2>&1
		# It looks like branch_dir doesn't exist on the remote repository, so doing git init.
		if [ ! $? -eq 0 ]; then
			git init > /dev/null
			echo "$branch_host:$branch_dir" > ~/.inotif$branch_dir/.git/description
			git checkout -b "$branch_host$branch_dir" > /dev/null 2>&1
			git remote add origin ssh://${repo_user}@${repo_host}/git/${repo_name} > /dev/null > /dev/null 2>&1
			setup_comm_git;
			setup_push_git "initial-commit";
		# Branch_dir exist on remote repository.
		else
			setup_comm_git;
			setup_push_git "auto-commit";
		fi
	# Git installed before.
	else
		echo "$branch_host:$branch_dir" > ~/.inotif$branch_dir/.git/description
		git checkout -b "$branch_host$branch_dir" > /dev/null 2>&1
		git remote add origin ssh://${repo_user}@${repo_host}/git/${repo_name} > /dev/null > /dev/null 2>&1 || git remote set-url origin ssh://${repo_user}@${repo_host}/git/${repo_name} > /dev/null > /dev/null 2>&1
		rsync -aq --delete --max-size=1.0m --exclude=.git* --exclude=.git $branch_dir/ ~/.inotif$branch_dir/ > /dev/null 2>&1
		setup_push_git "auto-commit"
	fi
}

setup_push_git() {
	messages="$1"
	cd ~/.inotif$branch_dir
	git config user.name "$USER"
	git config user.email "$USER@$branch_host"
	if [ -n "$(git status --porcelain)" ]; then
		git add . > /dev/null
		git commit -m "$messages" > /dev/null
		sshpass -p $repo_pass git push -u origin "$branch_host$branch_dir" > /dev/null
	else 
	  echo "Nothing to commit";
	fi
}

#echo "$repo_name|$repo_host|$repo_user|$repo_pass|$branch_host|$branch_dir"
echo "Inotif on started."
check_requirements;
setup_repo_git;
