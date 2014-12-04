#!/bin/bash
makepng() {
	#xavg=$(awk '{if(NR==FNR){n[FNR]=$1}else{ total += $1*n[FNR]; count+=n[FNR] }} END { print total/count }' "masses.csv" "$1")
	#yavg=$(awk '{if(NR==FNR){n[FNR]=$1}else{ total += $2*n[FNR]; count+=n[FNR] }} END { print total/count }' "masses.csv" "$1")
	xavg=0
	yavg=0
	basename=$(basename $1 .csv)
	gnuplot <<- EOF
		set xrange [-5e+6+${xavg}:5e+6+${xavg}]
		set yrange [-5e+6+${yavg}:5e+6+${yavg}]
		set size square
		set term png size 1200,1080 giant
		set output "${basename}.png"
		plot "<paste ${1} masses.csv | sed -n '0~171p'" using 1:2:(sqrt(\$3)/5) with points pointsize variable title "${basename}"
EOF
}
export -f makepng

parallel --progress 'makepng "{}"' ::: ktick*.csv
rm animation.avi
ffmpeg -r 12 -i ktick%010d.png -c:v libx264 -preset slow -crf 0 animation.avi
rm ktick*.png
