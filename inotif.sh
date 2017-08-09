#!/bin/sh
# set -x

exit1() {
	echo "FAIL"
 	echo "$1"
 	exit 1;
}

success1() {
	echo "OK"
 	echo "$1"
}

#load config file
. conf/inotif.conf

branch="$(ifconfig | sed -En 's/127.0.0.1//;s/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p' | head -n1)" > /dev/null 2>&1

dir_list="$dir_default $(curl $consul_address/v1/kv/inotif/$branch?raw | jq .dir[] | sed "s/\"/ /g")" > /dev/null 2>&1
check_repo="$dir_default $(curl $consul_address/v1/kv/inotif/$branch?raw | jq .repo_url | sed "s/\"/ /g")" > /dev/null 2>&1
if [ ! -z $check_repo ]; then
	repo_url=$check_repo
fi

# checking dependency in remote ssh host
hash git > /dev/null 2>&1 || exit1 "git not installed."
hash rsync > /dev/null 2>&1 || exit1 "rsync not installed."
hash curl > /dev/null 2>&1 || exit1 "curl not installed."
hash jq > /dev/null 2>&1 || exit1 "jq not installed."

#push change
setup_repo(){
	git checkout -B $branch > /dev/null 2>&1
	git remote add origin $repo_url > /dev/null 2>&1 || git remote set-url origin $repo_url > /dev/null 2>&1
	for dir_name in $dir_list; do		
		if [ -d "$HOME/.inotif"$dir_name"" ] || mkdir -p "$HOME/.inotif"$dir_name""; then
			# rsync folder        
		    rsync -aq --delete --max-size=1.0m --exclude=.git* --exclude=.git "$dir_name"/ $HOME/.inotif"$dir_name"/ > /dev/null 2>&1
		fi
	done
	git config user.name $USER 
	git config user.email $USER@$branch
	if [ -n "$(git status --porcelain)" ]; then
		git add -A > /dev/null 2>&1
		git commit -m "auto commit" > /dev/null 2>&1
		git push --set-upstream origin $branch > /dev/null 2>&1
		success1 "Pushed"
	else 
	 	success1 "Nothing to commit";
	fi
}

#make dir if not exist
mkdir -p $HOME/.inotif
#go to dir
cd $HOME/.inotif
#if folder .inotif/.git no found
if [ -d "$HOME/.inotif/.git" ]; then
	#pull
	git pull origin $branch > /dev/null 2>&1
	#stash diff
	git stash > /dev/null 2>&1
	#rsync
	setup_repo
else
	#delete folder
	rm -rf $HOME/.inotif/* 
	# clone branch_dir from remote repository if git not installed on branch_dir.
	git clone -b $branch $repo_url ./ > /dev/null 2>&1 
	#if clone success
	if [ $? -eq 0 ]; then
		#rsync
		setup_repo
	#if clone error
	else
		#init
		git init > /dev/null 2>&1
		#rsync
		setup_repo
	fi
fi
