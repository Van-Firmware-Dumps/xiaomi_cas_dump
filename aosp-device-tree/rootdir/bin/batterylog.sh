#!/system/bin/sh
trap "" PIPE
iteration=5
path=/data/vendor/charge_logger/log
INTERRATION=5
let count=0
LOGPATH='/sys/kernel/debug/dynamic_debug/control'
BATPATH='/sys/class/power_supply'
PMICVOTABLEPATH='/sys/kernel/debug/pmic-votable'

stop vendor.hvdcp_opti
setenforce 0
start vendor.hvdcp_opti

echo 6 > /proc/sys/kernel/printk

echo Y > /sys/module/printk/parameters/ignore_loglevel
echo N > /sys/module/printk/parameters/console_suspend

if [ -d $path ]; then
    	rm $path -rf
	mkdir -p $path
	chmod 777 $path
else
	mkdir -p $path
	chmod 777 $path
fi

if [ ! -d $path/pmic-votable ]; then
    mkdir $path/pmic-votable
    chmod 777 $path/pmic-votable
fi

echo 'file qpnp-smb5.c +p' > /sys/kernel/debug/dynamic_debug/control
echo 'file smb5-lib.c +p' > /sys/kernel/debug/dynamic_debug/control
echo 'file pmic-voter.c +p' > /sys/kernel/debug/dynamic_debug/control
echo 'file smb1398-charger.c +p' > /sys/kernel/debug/dynamic_debug/control
echo 'file pmic-voter.c +p' > /d/dynamic_debug/control
echo 'file smb1398-charger.c +p' > /d/dynamic_debug/control
echo 'file bq25790_charger.c +p' > /d/dynamic_debug/control
echo 'file bq27z561_fg.c +p' > /d/dynamic_debug/control
echo 'max28200.c +p' > /d/dynamic_debug/control
echo 0xFF > /d/charger/debug_mask
echo 0xFF > /d/battery/debug_mask
setprop 'persist.vendor.cp.log_level' 1
setprop 'persist.vendor.vin.log_level' 1
echo 10000 > /proc/sys/kernel/printk_ratelimit
echo 10000 > /proc/sys/kernel/printk_ratelimit_burst
echo "on" >/proc/sys/kernel/printk_devkmsg

cat /dev/kmsg > $path/kernelLogs.txt &

### collecting the kernel, logcat common and logcat event logs
pmidump_peripheral () {
    local base=$1
    local size=$2
    local dump_path=$3
    echo $base > $dump_path/address
    echo $size > $dump_path/count
    cat $dump_path/data >> /$path/PMIDump.txt
}

smb1398master_peripheral () {
    local base=$1
    local size=$2
    local dump_path=$3
    echo $base > $dump_path/address
    echo $size > $dump_path/count
    cat $dump_path/data >> /$path/smb1398_master_dump.txt
}

smb1398slave_peripheral () {
    local base=$1
    local size=$2
    local dump_path=$3
    echo $base > $dump_path/address
    echo $size > $dump_path/count
    cat $dump_path/data >> /$path/smb1398_slave_dump.txt
}

IFS=$'\n'
headings="uptime"

for i in `cat /sys/class/power_supply/*/uevent`
do
heading=`echo $i | cut -f 1 -d "="`
headings="$headings , $heading"
done
IFS=$' '

PMI_ADC_DIR="/sys/bus/iio/devices/iio:device1"
PMI_ADC0_DIR="/sys/bus/iio/devices/iio:device0"
PMI_USB_DIR="/sys/class/power_supply/usb"
PMI_BATT2_DIR="/sys/class/power_supply/battery"
PMI_BATT_DIR="/sys/class/power_supply/bms"
PMI_MAIN_DIR="/sys/class/power_supply/main"
BBC_DIR="/sys/class/power_supply/bbc"
BATT_CLASS_DIR="/sys/class/qcom-battery"
PARALLEL_DIR="/sys/class/power_supply/parallel"
CP_DIR="/sys/class/power_supply/charge_pump_master"
SPMI_DIR="/d/regmap/spmi0-02"
CP_MASTER_REG="/d/regmap/4-0034"
CP_SLAVE_REG="/d/regmap/4-0035"

cat /dev/kmsg > $path/kernelLogs.txt &

LOGDIR=/data/vendor/charge_logger/log
LOGFILE=$LOGDIR"/dmesglog.txt"
MV_FILES_SHELL="/system/bin/mv_files.sh"

while :
do
    uptime=$(cat /proc/uptime)

    echo device Uptime=$uptime >> /$path/pmic-votable/allvotable.txt &&
    echo "$(cat $PMICVOTABLEPATH/*/status)\n**\n" >> /$path/pmic-votable/allvotable.txt &&

    echo device Uptime=$uptime >> /$path/usbpd_pdo.txt &&
    echo "pdo1$(cat /sys/class/usbpd/usbpd0/pdo1)\n" >> /$path/usbpd_pdo.txt &&
    echo "pdo2$(cat /sys/class/usbpd/usbpd0/pdo2)\n" >> /$path/usbpd_pdo.txt &&
    echo "pdo3$(cat /sys/class/usbpd/usbpd0/pdo3)\n" >> /$path/usbpd_pdo.txt &&
    echo "pdo4$(cat /sys/class/usbpd/usbpd0/pdo4)\n" >> /$path/usbpd_pdo.txt &&
    echo "pdo5$(cat /sys/class/usbpd/usbpd0/pdo5)\n" >> /$path/usbpd_pdo.txt &&
    echo "pdo6$(cat /sys/class/usbpd/usbpd0/pdo6)\n" >> /$path/usbpd_pdo.txt &&
    echo "pdo7:$(cat /sys/class/usbpd/usbpd0/pdo7)**\n" >> /$path/usbpd_pdo.txt &&

    ### collecting the USB PD logs
    echo device Uptime=$uptime >> /$path/usbPDLogs.txt &&
    echo "$(cat /sys/kernel/debug/ipc_logging/usb_pd/log)\n**\n" >> /$path/usbPDLogs.txt &&
    ### end of collecting the USB PD logs

    echo device Uptime=$uptime >> /$path/smb1398_master_dump.txt &&
    smb1398master_peripheral 0x2600 0x300 "/sys/kernel/debug/regmap/4-0034";
    echo device Uptime=$uptime >> /$path/smb1398_slave_dump.txt &&
    smb1398slave_peripheral 0x2600 0x300 "/sys/kernel/debug/regmap/4-0035";

    dmesg -c >> $LOGFILE

    LOGSIZE=`du -shm $LOGFILE | sed 's/[[:blank:]].*//g'`

    if [ $LOGSIZE -gt 10 ]; then
	    $MV_FILES_SHELL $LOGFILE $num
    fi

    sleep 5

done
