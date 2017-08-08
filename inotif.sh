#!/bin/sh
# set -x
consul_address="192.168.114.35:8500"
branch="$(ifconfig  | grep 'inet addr:'| grep -v '127.0.0.1' | cut -d: -f2 | awk '{ print $1}')"
repo_url=$(curl $consul_address/v1/kv/inotif/config?raw | jq .repo_url | sed "s/\"/ /g")
dir_list="/etc $(curl $consul_address/v1/kv/inotif/$branch?raw | jq .dir[] | sed "s/\"/ /g")"

setup_repo(){
	git checkout -B $branch
	git remote add origin $repo_url || git remote set-url origin $repo_url
	for dir_name in $dir_list; do		
		if [ -d "$HOME/.inotif"$dir_name"" ] || mkdir -p "$HOME/.inotif"$dir_name""; then
			# rsync folder        
		    rsync -aq --delete --max-size=1.0m --exclude=.git* --exclude=.git "$dir_name"/ ~/.inotif"$dir_name"/ > /dev/null 2>&1
		fi
	done
	git add -A > /dev/null 2>&1
	git commit -m "auto commit" > /dev/null 2>&1
	git push --set-upstream origin $branch
}

execution(){
	mkdir -p $HOME/.inotif
	cd $HOME/.inotif
	if [ -d "$HOME/.inotif/.git" ]; then
		git pull origin $branch
		git stash
		setup_repo
	else
		rm -rf $HOME/.inotif/*
		git clone -b $branch $repo_url ./ 
		if [ $? -eq 0 ]; then #if true
			setup_repo
		else
			git init
			setup_repo
		fi
	fi
}

execution
