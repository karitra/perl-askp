#!/bin/bash
# -*- coding: koi8-r-unix -*-
#

echo Installing ASKP perl utils
if [ ! -d ~/scripts ]; then
	echo Creating scripts directory
	mkdir ~/scripts
fi

echo Copying scripts
cp -Rf p-utils/* ~/scripts

pushd pASKP
make clean
perl Makefile.PL
make
make test
su -c 'make install'
popd


echo Done!
