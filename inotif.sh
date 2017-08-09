#!/bin/sh
# set -x

#load config file
. conf/inotif.conf

branch="$(ifconfig | sed -En 's/127.0.0.1//;s/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p' | head -n1)"
dir_list="$dir_default $(curl $consul_address/v1/kv/inotif/$branch?raw | jq .dir[] | sed "s/\"/ /g")"
if [ ! $? -eq 0 ]; then
	repo_url=$(curl $consul_address/v1/kv/inotif/config?raw | jq .repo_url | sed "s/\"/ /g")
fi

#push change
setup_repo(){
	git checkout -B $branch
	git remote add origin $repo_url || git remote set-url origin $repo_url
	for dir_name in $dir_list; do		
		if [ -d "$HOME/.inotif"$dir_name"" ] || mkdir -p "$HOME/.inotif"$dir_name""; then
			# rsync folder        
		    rsync -aq --delete --max-size=1.0m --exclude=.git* --exclude=.git "$dir_name"/ $HOME/.inotif"$dir_name"/ > /dev/null 2>&1
		fi
	done
	git add -A > /dev/null 2>&1
	git commit -m "auto commit" > /dev/null 2>&1
	git push --set-upstream origin $branch
}

#make dir if not exist
mkdir -p $HOME/.inotif
#go to dir
cd $HOME/.inotif
#if folder .inotif/.git no found
if [ -d "$HOME/.inotif/.git" ]; then
	#pull
	git pull origin $branch
	#stash diff
	git stash
	#rsync
	setup_repo
else
	#delete folder
	rm -rf $HOME/.inotif/*
	#clone repo
	git clone -b $branch $repo_url ./ 
	#if clone success
	if [ $? -eq 0 ]; then
		#rsync
		setup_repo
	#if clone error
	else
		#init
		git init
		#rsync
		setup_repo
	fi
fi
