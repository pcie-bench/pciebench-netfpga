#nf_data     = "real_time_bw.dat"
#plot_title  = ''
#x_axis      = 'Transfer Size (Bytes)'
#y_axis      = 'Bandwidth (Gb/s)'

set terminal pdf enhanced color solid font ',20'
#out_file_eb = "filepdf"
#set output out_file_eb

set term x11

#set terminal dumb

set title  plot_title
set xlabel x_axis
set ylabel y_axis
set key bottom right spacing 1.5

set xrange [:2048]
set yrange [0:60]

set mytics 4
set xtics 256
set mxtics 4
set tics
set grid ytics mytics xtics mxtics lw 0.1 lc rgb 'gray'
set offsets graph 0, 0, 0.01, 0.01

plot nf_data u 3:4 w lp lw 2 dashtype 4 lc rgb 'dark-blue' t 'NetFPGA-HSW'
pause 1
reread
