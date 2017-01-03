#!/bin/bash
cd $(dirname ${0})
find raw -iname '*.png' | while read png
do
	name=$(echo ${png} | awk -F'/' '{print $NF}')
	convert ${png} -fuzz 50% -trim -scale 50% -verbose ${name}
done