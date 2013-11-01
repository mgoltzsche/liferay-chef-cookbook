#!/bin/bash

# This runs as root on the server

chef_binary=/var/lib/gems/1.9.1/bin/chef-solo

# Are we on a vanilla system?
if ! test -f "$chef_binary"; then
    export DEBIAN_FRONTEND=noninteractive
    # Upgrade headlessly (this is only safe-ish on vanilla systems)
    apt-get update &&
    apt-get -o Dpkg::Options::="--force-confnew" \
        --force-yes -fuy dist-upgrade &&
    # Install RVM
    apt-get --force-yes install build-essential openssl libreadline6 \
	libreadline6-dev curl git-core zlib1g zlib1g-dev libssl-dev \
	libyaml-dev libsqlite3-0 libsqlite3-dev sqlite3 libxml2-dev \
	libxslt-dev autoconf libc6-dev ncurses-dev automake libtool bison &&
    curl -L https://get.rvm.io | bash -s stable --rails --autolibs=enabled &&
    echo '[[ -s "$HOME/.rvm/scripts/rvm" ]] && . "$HOME/.rvm/scripts/rvm" # Load RVM function' >> ~/.bash_profile &&
    source ~/.bash_profile &&
    # Install Ruby and Chef
    rvm install 2.0.0 \
	--with-openssl-dir=$HOME/.rvm/usr \
	--verify-downloads 1 &&
    rvm use --default 2.0.0 &&
    gem install --no-rdoc --no-ri chef
fi &&

"$chef_binary" -c solo.rb -j solo.json
