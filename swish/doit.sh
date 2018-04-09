#!/bin/bash
#cd /usr/local/swish
rm -f swish.log
for file in *.conf ; do 
	swish-e -S http -c $file >> swish.log 2>&1
done
