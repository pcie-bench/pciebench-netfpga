#!/bin/bash


# Variables: See HOST/bin/benchmark to inspect the different options
DIR=RW
PATTERN="FIX 0"
CACHE=warm


# Script
mkdir -p data
ts=$(date +%s)
ofile="data/real_time_bw_$ts.dat"

plot_title="Bandwidth test at $(date -d @$ts)"

echo "0 0 0 0" > $ofile
gnuplot \
    -e "nf_data='$ofile'" \
    -e "plot_title='${plot_title}'" \
    -e "x_axis='Transfer Size (Bytes)'" \
    -e "y_axis='Bandwidth (Gb/s)'" \
    live_bw.gp &

for size in 8 16 32 64 128 132 192 256 260 320 384 448 512 516 520 576 640 704 768 772 776 832 896 960 1024 1028 1032 1276 1280 1284 1532 1536 1540 1788 1792 1796 2048
do
    (
        cd ..
        sh restart.sh 2>&1 > /dev/null
        ./bin/benchmark -t bw -d $DIR -c $CACHE -p $PATTERN -n $size -l 1 2>&1 | awk 'NR!=1{print $0}' | sed 's/,/ /g'  >> scripts/$ofile
    )

done 

plot_title="Latency test at $(date -d @$ts)"
ofile="data/real_time_lat_$ts.dat"
echo "0 0 0 0" > $ofile
gnuplot \
    -e "nf_data='$ofile'" \
    -e "plot_title='${plot_title}'" \
    -e "x_axis='Transfer Size (Bytes)'" \
    -e "y_axis='Latency (ns)'" \
    live_lat.gp &

for size in 8 16 32 64 128 132 192 256 260 320 384 448 512 516 520 576 640 704 768 772 776 832 896 960 1024 1028 1032 1276 1280 1284 1532 1536 1540 1788 1792 1796 2048
do
    (
        cd ..
        sh restart.sh 2>&1 > /dev/null
        ./bin/benchmark -t lat -d $DIR -c $CACHE -p $PATTERN -n $size -l 1 2>&1 | awk 'NR!=1{print $0}' | sed 's/,/ /g'  >> scripts/$ofile
    )

done 


echo "Press Enter to terminate gnuplot"
read a
killall gnuplot
