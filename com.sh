#!/bin/bash
printcom() {
	xavg=$(awk '{if(NR==FNR){n[FNR]=$1}else{ total += $1*n[FNR]; count+=n[FNR] }} END { print total/count }' "masses.csv" "$1")
	yavg=$(awk '{if(NR==FNR){n[FNR]=$1}else{ total += $2*n[FNR]; count+=n[FNR] }} END { print total/count }' "masses.csv" "$1")
	echo "$1: $xavg, $yavg"
}
export -f printcom

parallel 'printcom "{}"' ::: ktick*.csv
