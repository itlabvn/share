#!/bin/bash


INTERVAL="1"  # update interval in seconds

if [ -z "$1" ]; then
        echo
        echo "example: plugin.sh HOSTNAME interface_name time TX_warning_mbit/s TX_critical_mbit/s RX_warning_mbit/s RX_critical_mbit/s total mbit/s;" 
        echo
        echo "./check_bandwidth_linux.sh localhost eth0 15 80 90 40 60 100"
        exit
fi

name=$1
IF=$2
sec=$3
warn=$4
crit=$5
warn_r=$6
crit_r=$7
iface_speed=$8
current_pid=$$

bin_ps=`which ps`
bin_grep=`which grep`
bin_expr=`which expr`
bin_cat=`which cat`
bin_tac=`which tac`
bin_sort=`which sort`
bin_wc=`which wc`
bin_awk=`which awk`

pidfile=/tmp/"$name"_"$IF"_check_bandwidth.pid

if [ -f $pidfile ];
    then
        echo "need to reduce the check duration or increase the interval between checks"
        exit 1
    else
        echo $current_pid > $pidfile
fi

tmpfile_rx=/tmp/"$name"_"$IF"_check_bandwidth_rx.tmp
tmpfile_tx=/tmp/"$name"_"$IF"_check_bandwidth_tx.tmp
reverse_tmpfile_rx=/tmp/"$name"_"$IF"_reverse_check_bandwidth_rx.tmp
reverse_tmpfile_tx=/tmp/"$name"_"$IF"_reverse_check_bandwidth_tx.tmp
deltafile_rx=/tmp/"$name"_"$IF"_delta_check_bandwidth_rx.tmp
deltafile_tx=/tmp/"$name"_"$IF"_delta_check_bandwidth_tx.tmp

warn_kbits=`$bin_expr $warn '*' 1000000`
crit_kbits=`$bin_expr $crit '*' 1000000`

warn_kbits_r=`$bin_expr $warn_r '*' 1000000`
crit_kbits_r=`$bin_expr $crit_r '*' 1000000`

iface_speed_kbits=`$bin_expr $iface_speed '*' 1000000`

START_TIME=`date +%s`
n=0
while [ $n -lt $sec ]
    do
        cat /sys/class/net/$IF/statistics/rx_bytes >> $tmpfile_rx
        cat /sys/class/net/$IF/statistics/tx_bytes >> $tmpfile_tx
        sleep $INTERVAL
        let "n = $n + 1"
    done
FINISH_TIME=`date +%s`
$bin_cat $tmpfile_rx | $bin_sort -nr > $reverse_tmpfile_rx
$bin_cat $tmpfile_tx | $bin_sort -nr > $reverse_tmpfile_tx
while read line;
    do
        if [ -z "$RBYTES" ];
            then
                RBYTES=`cat /sys/class/net/$IF/statistics/rx_bytes`
                $bin_expr $RBYTES - $line >> $deltafile_rx;
            else
                $bin_expr $RBYTES - $line >> $deltafile_rx;
        fi
RBYTES=$line
done < $reverse_tmpfile_rx

while read line;
    do
        if [ -z "$TBYTES" ];
            then
                TBYTES=`cat /sys/class/net/$IF/statistics/tx_bytes`
                $bin_expr $TBYTES - $line >> $deltafile_tx;
            else
                $bin_expr $TBYTES - $line >> $deltafile_tx;
        fi
TBYTES=$line
    done < $reverse_tmpfile_tx

while read line;
    do
        SUM_RBYTES=`$bin_expr $SUM_RBYTES + $line`
    done < $deltafile_rx

while read line;
    do
        SUM_TBYTES=`$bin_expr $SUM_TBYTES + $line`
    done < $deltafile_tx

let "DURATION = $FINISH_TIME - $START_TIME"
let "RBITS_SEC = ( $SUM_RBYTES * 8 ) / $DURATION"
let "TBITS_SEC = ( $SUM_TBYTES * 8 ) / $DURATION"

if [ $RBITS_SEC -gt $crit_kbits_r ]
    then
        data_output_r=`echo "$RBITS_SEC 1000000" | $bin_awk '{ printf ("%.2f", $1/$2); }'`
        data_output_t=`echo "$TBITS_SEC 1000000" | $bin_awk '{ printf ("%.2f", $1/$2); }'`
        percent_output_r=`echo "$RBITS_SEC $iface_speed_kbits 100" | $bin_awk '{ printf ("%.2f", $1/$2*$3); }'`
        percent_output_t=`echo "$TBITS_SEC $iface_speed_kbits 100" | $bin_awk '{ printf ("%.2f", $1/$2*$3); }'`
        nagvis_perfdata_r="InUsage=$percent_output_r%;$warn_kbits;$crit_kbits"
        nagvis_perfdata_t="OutUsage=$percent_output_t%;$warn_kbits;$crit_kbits"
        output="IN $data_output_r Mbit/s OUT $data_output_t Mbit/s RX CRITICAL! period $DURATION sec | $nagvis_perfdata_r $nagvis_perfdata_t inBandwidth="$data_output_r"Mbs outBandwidth="$data_output_t"Mbs $pnp4nagios_perfdata_r $pnp4nagios_perfdata_t"
        exitstatus=2
    elif [ $TBITS_SEC -gt $crit_kbits ]
        then
            data_output_r=`echo "$RBITS_SEC 1000000" | $bin_awk '{ printf ("%.2f", $1/$2); }'`
            data_output_t=`echo "$TBITS_SEC 1000000" | $bin_awk '{ printf ("%.2f", $1/$2); }'`
            percent_output_r=`echo "$RBITS_SEC $iface_speed_kbits 100" | $bin_awk '{ printf ("%.2f", $1/$2*$3); }'`
            percent_output_t=`echo "$TBITS_SEC $iface_speed_kbits 100" | $bin_awk '{ printf ("%.2f", $1/$2*$3); }'`
            nagvis_perfdata_r="InUsage=$percent_output_r%;$warn_kbits;$crit_kbits"
            nagvis_perfdata_t="OutUsage=$percent_output_t%;$warn_kbits;$crit_kbits"
            output="IN $data_output_r Mbit/s OUT $data_output_t Mbit/s TX CRITICAL! period $DURATION sec | $nagvis_perfdata_r $nagvis_perfdata_t inBandwidth="$data_output_r"Mbs outBandwidth="$data_output_t"Mbs $pnp4nagios_perfdata_r $pnp4nagios_perfdata_t"
            exitstatus=2
    elif [ $RBITS_SEC -ge $warn_kbits_r -a $RBITS_SEC -le $crit_kbits_r ];
        then
            data_output_r=`echo "$RBITS_SEC 1000000" | $bin_awk '{ printf ("%.2f", $1/$2); }'`
            data_output_t=`echo "$TBITS_SEC 1000000" | $bin_awk '{ printf ("%.2f", $1/$2); }'`
            percent_output_r=`echo "$RBITS_SEC $iface_speed_kbits 100" | $bin_awk '{ printf ("%.2f", $1/$2*$3); }'`
            percent_output_t=`echo "$TBITS_SEC $iface_speed_kbits 100" | $bin_awk '{ printf ("%.2f", $1/$2*$3); }'`
            nagvis_perfdata_r="InUsage=$percent_output_r%;$warn_kbits;$crit_kbits"
            nagvis_perfdata_t="OutUsage=$percent_output_t%;$warn_kbits;$crit_kbits"
            output="IN $data_output_r Mbit/s OUT $data_output_t Mbit/s RX WARNING! period $DURATION sec | $nagvis_perfdata_r $nagvis_perfdata_t inBandwidth="$data_output_r"Mbs outBandwidth="$data_output_t"Mbs $pnp4nagios_perfdata_r $pnp4nagios_perfdata_t"
            exitstatus=1
    elif [ $TBITS_SEC -ge $warn_kbits -a $TBITS_SEC -le $crit_kbits ];
        then
            data_output_r=`echo "$RBITS_SEC 1000000" | $bin_awk '{ printf ("%.2f", $1/$2); }'`
            data_output_t=`echo "$TBITS_SEC 1000000" | $bin_awk '{ printf ("%.2f", $1/$2); }'`
            percent_output_r=`echo "$RBITS_SEC $iface_speed_kbits 100" | $bin_awk '{ printf ("%.2f", $1/$2*$3); }'`
            percent_output_t=`echo "$TBITS_SEC $iface_speed_kbits 100" | $bin_awk '{ printf ("%.2f", $1/$2*$3); }'`
            nagvis_perfdata_r="InUsage=$percent_output_r%;$warn_kbits;$crit_kbits"
            nagvis_perfdata_t="OutUsage=$percent_output_t%;$warn_kbits;$crit_kbits"
            output="IN $data_output_r Mbit/s OUT $data_output_t Mbit/s TX WARNING! period $DURATION sec | $nagvis_perfdata_r $nagvis_perfdata_t inBandwidth="$data_output_r"Mbs outBandwidth="$data_output_t"Mbs $pnp4nagios_perfdata_r $pnp4nagios_perfdata_t"
            exitstatus=1

    elif [ $RBITS_SEC -lt $warn_kbits_r -o $TBITS_SEC -lt $warn_kbits ]
        then
            data_output_r=`echo "$RBITS_SEC 1000000" | $bin_awk '{ printf ("%.2f", $1/$2); }'`
            data_output_t=`echo "$TBITS_SEC 1000000" | $bin_awk '{ printf ("%.2f", $1/$2); }'`
            percent_output_r=`echo "$RBITS_SEC $iface_speed_kbits 100" | $bin_awk '{ printf ("%.2f", $1/$2*$3); }'`
            percent_output_t=`echo "$TBITS_SEC $iface_speed_kbits 100" | $bin_awk '{ printf ("%.2f", $1/$2*$3); }'`
            nagvis_perfdata_r="InUsage=$percent_output_r%;$warn_kbits;$crit_kbits"
            nagvis_perfdata_t="OutUsage=$percent_output_t%;$warn_kbits;$crit_kbits"
            output="IN $data_output_r Mbit/s OUT $data_output_t Mbit/s - OK, period $DURATION sec | $nagvis_perfdata_r $nagvis_perfdata_t inBandwidth="$data_output_r"Mbs outBandwidth="$data_output_t"Mbs $pnp4nagios_perfdata_r $pnp4nagios_perfdata_t"
            exitstatus=0
    else
        output="unknown status"
        exitstatus=3
fi

rm -f $tmpfile_rx
rm -f $reverse_tmpfile_rx
rm -f $deltafile_rx
rm -f $tmpfile_tx
rm -f $reverse_tmpfile_tx
rm -f $deltafile_tx
rm -f $pidfile

echo "$output"
exit $exitstatus

