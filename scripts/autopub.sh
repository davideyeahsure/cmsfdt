#!/bin/bash
year=`/usr/bin/date +%y`
cd /var/www/cms50/scripts/
./autopub.pl softland storie/$year
