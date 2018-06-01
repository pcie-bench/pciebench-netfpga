#!/bin/bash


# Variables: See HOST/bin/benchmark to inspect the different options
PATTERN="FIX 0"
CACHE=warm
ITER_PER_POINT=1


# Script
mkdir -p data
ts=$(date +%s)

# R stands for Device 2 Host
# W stands for Host 2 Device
declare -A label
label["R"]="Device to Host"
label["W"]="Host to Device"
label["RW"]="Device to Host+Host to Device"
for DIR in R W RW; do
    ofile="data/real_time_bw_${DIR}_$ts.dat"
    plot_title="Bandwidth test (DIR ${label[$DIR]}) at $(date -d @$ts)"

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
            ./bin/benchmark -t bw -d $DIR -c $CACHE -p $PATTERN -n $size -l ${ITER_PER_POINT} 2>&1 | awk 'NR!=1{print $0}' | sed 's/,/ /g'  >> scripts/$ofile
        )

    done 

    if [ "$DIR" != "R" ]; then
        plot_title="Latency test (DIR ${label[$DIR]}) at $(date -d @$ts)"
        ofile="data/real_time_lat_${DIR}_$ts.dat"
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
                ./bin/benchmark -t lat -d $DIR -c $CACHE -p $PATTERN -n $size -l ${ITER_PER_POINT} 2>&1 | awk 'NR!=1{print $0}' | sed 's/,/ /g'  >> scripts/$ofile
            )

        done 
    fi

done
echo "Press Enter to terminate gnuplot"
read a
killall gnuplot
