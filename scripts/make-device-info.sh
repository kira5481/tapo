#!/bin/bash

#*************************************************
# 在制作文件系统之前,根据version与device_info的配置文件生成device_info的UCI文件
#*************************************************

sw_ver_major=""
sw_ver_minor=""
sw_ver_rev=""
sw_version=""

function write_sw_version()
{
    if ([ "$1" == "" ] || [ "$2" == "" ] || [ "$3" == "" ]); then 
        echo err: lack of sw version parameters!
    fi
    
    firsthalf="\toption sw_version "
    buildtime=$(expr `date +%H` \* 3600 + `date +%M` \* 60 + `date +%S`)
    date=$(date +%y%m%d)
    sw_version=$1"."$2"."$3" Build "$date" Rel."$buildtime"n"
    echo -e $firsthalf \"$sw_version\" >> $UCI_FILE
}

function parse_line()
{
    local line="$1"

    # ignore comment line and space line
    if (!(echo "$line" | grep -n '^#' > /dev/null) && !(echo "$line" | grep -n '^$' > /dev/null) && !(echo "$line" | grep -n '^IMG_' > /dev/null)); then
        firsthalf=`echo $line | awk '{print "\toption" " " $1 " "}' | tr '[A-Z]' '[a-z]'`
        secondhalf=`echo $line | sed 's/^[[:alnum:]_[:blank:]]*=[:blank:]*//g'`
        echo "$firsthalf$secondhalf" >> $UCI_FILE

        # find sys_softwar_revision and save to var for sw_version making
        if ([ $(echo $line | awk '{print $1}' | tr '[A-Z]' '[a-z]') == "sys_software_revision" ]); then
            ((sw_ver_major="0x"$(echo $secondhalf | awk '{print substr($1, length($1) -3, 2)}')))
            ((sw_ver_minor="0x"$(echo $secondhalf | awk '{print substr($1, length($1) -1, 2)}')))
        fi
        if ([ $(echo $line | awk '{print $1}' | tr '[A-Z]' '[a-z]') == "sys_software_revision_minor" ]); then
            ((sw_ver_rev="0x"$(echo $secondhalf | awk '{print substr($1, length($1) -1, 2)}')))
        fi
    fi
}

VER_FILE=$1
INFO_FILE=$2
UCI_FILE=$3
GEN_FILE=$4

if [ -z $VER_FILE ] || [ -z $INFO_FILE ] || [ -z $UCI_FILE ] || [ -z $GEN_FILE ]; then
    echo "lack of file parameters"
    exit 1
fi

if [ ! -f $VER_FILE ] || [ -z $INFO_FILE ]; then
    echo "verison file or uci file not exist"
    exit 1
fi

touch $UCI_FILE
# delete uci file contents
cat /dev/null > $UCI_FILE

echo "config info info" > $UCI_FILE

while read line
do
    parse_line "$line"
done < $VER_FILE

while read line
do
    parse_line "$line"
done < $INFO_FILE

# make and add sw_version
write_sw_version $sw_ver_major $sw_ver_minor $sw_ver_rev

# clean generated firmware list file and write sw_version to it
touch $GEN_FILE
cat /dev/null > $GEN_FILE
echo $sw_version > $GEN_FILE
