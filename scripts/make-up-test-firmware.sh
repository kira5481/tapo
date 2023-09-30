#!/bin/bash

#only tile 2.0 product need to generate plugin related files
TILE2=
ProductName=$1
CONFIG_DIR=
BIN_DIR=
BIN_DIR_NAME=
PLUGIN_CONFIG_FILE=
VERSION_CONFIG_FILE=
FIRMWARE_CONFIG_FILE=
FIRMWARE_INFO_FILE=
UP_FIRMWARE_INFO_FILE=
FIRMWARE_INFO_FOR_TEST=

function help() {
cat <<EOF
./make-up-test-firmware.sh ProductName

- modify_config_file
	backup config file, increase plugin version, increase firmware version,
	config firmware info to support current firmware to upgrade

- generate_firmware_info_for_test
	generate current firmware and up firmware info for test.

- resume_config_file
	resume config file from backup config file
EOF
}

function gettop
{
    local TOPFILE=feeds.conf
    if [ -n "$TOP" -a -f "$TOP/$TOPFILE" ] ; then
        echo $TOP
    else
        if [ -f $TOPFILE ] ; then
            echo $PWD
        else
            # We redirect cd to /dev/null in case it's aliased to
            # a command that prints something as a side-effect
            # (like pushd)
            local HERE=$PWD
            T=
            while [ \( ! \( -f $TOPFILE \) \) -a \( $PWD != "/" \) ]; do
                cd .. > /dev/null
                T=$PWD
            done
            cd $HERE > /dev/null
            if [ -f "$T/$TOPFILE" ]; then
                echo $T
            fi
        fi
    fi
}

function increase_plugin_version()
{
	local line_num
	local plugin_version

	plgs=`sed -n '/plugins/'p ${PLUGIN_CONFIG_FILE} | awk -F= '{print $2}' | sed 's/,/ /g'`
	for plugin in $plgs
	do
		eval $(awk -F '=' '/\['"$plugin"'\]/{a=1}a==1&&$1~/'"plugin_version"'/\
				{gsub(/^[ \t]+/,"",$2);split($2, version, ".");\
				printf("line_num=%d; plugin_version=\"%s= %d.%d.%d\"", NR, $1, \
				version[1], version[2], version[3] + 1);exit}' ${PLUGIN_CONFIG_FILE})
		sed -i "${line_num}c $plugin_version" ${PLUGIN_CONFIG_FILE}
	done
	return 0
}

function increase_firmware_version()
{
	local line_num
	local soft_version

	eval $(awk -F '=' '/SYS_SOFTWARE_REVISION_MINOR/{gsub(/^[ \t]+/,"",$2);\
			printf("line_num=%d; soft_version=\"%s= 0x00%02x\"", NR, $1, strtonum($2)+1);exit}' ${VERSION_CONFIG_FILE})
	sed -i "${line_num}c $soft_version" ${VERSION_CONFIG_FILE}
	return 0
}

function config_firmware_info()
{
	local firmware_id
	local firmware_version
	local svn_version
	local release_note
	local firmware_num

	sed -i '/put in BL/s/true/false/g' ${FIRMWARE_CONFIG_FILE}
	firmware_num=$(sed -n '/^\[firmware [0-9]*\]$/p' ${FIRMWARE_CONFIG_FILE} | wc -l)

	for key in "firmware ID" "firmware version" "svn version" "release note"
	do
		val=$(awk -F '=' '/'"$key"'/{print $2;exit}' ${FIRMWARE_INFO_FILE})

		case $key in
			"firmware ID")
				firmware_id="$val"
			;;
			"firmware version")
				firmware_version="$val"
			;;
			"svn version")
				svn_version="$val"
			;;
			"release note")
				release_note="$val"
			;;
		esac
	done

	cat <<EOF >> ${FIRMWARE_CONFIG_FILE}

[firmware $[$firmware_num+1]]
firmware ID =$firmware_id
firmware version =$firmware_version
svn version =$svn_version
release note =$release_note
put in FL = true
put in BL = true
EOF
	return 0
}

function backup_config_file()
{
	if [ "${TILE2}" = "y" ]; then
		cp ${PLUGIN_CONFIG_FILE} ${PLUGIN_CONFIG_FILE}".bak"
	fi
	cp ${VERSION_CONFIG_FILE} ${VERSION_CONFIG_FILE}".bak"
	cp ${FIRMWARE_CONFIG_FILE} ${FIRMWARE_CONFIG_FILE}".bak"
	return 0
}

function resume_config_file()
{
	if [ ! -e ${VERSION_CONFIG_FILE}".bak" ] \
		|| [ ! -e ${FIRMWARE_CONFIG_FILE}".bak" ]; then
		echo "there are some modified files not existed. do nothing"
		return 1
	fi

	mv ${VERSION_CONFIG_FILE}".bak" ${VERSION_CONFIG_FILE}
	mv ${FIRMWARE_CONFIG_FILE}".bak" ${FIRMWARE_CONFIG_FILE}

	if [ "${TILE2}" = "y" ]; then
		if [ ! -e ${PLUGIN_CONFIG_FILE}".bak" ]; then
			echo "the ${PLUGIN_CONFIG_FILE}.bak is not existed. do nothing"
		fi
		mv ${PLUGIN_CONFIG_FILE}".bak" ${PLUGIN_CONFIG_FILE}
	fi
	return 0
}

function generate_cur_firmware_info()
{
	local hardwrae_id
	local cur_firmware_config=${FIRMWARE_CONFIG_FILE}".bak"

	rm -f ${FIRMWARE_INFO_FOT_TEST}
	sed -n "1,3p" ${FIRMWARE_INFO_FILE} > ${FIRMWARE_INFO_FOR_TEST}
	hardware_id=$(awk -F '=' '/'"hardware ID"'/{print $2}' ${cur_firmware_config})

	cat <<EOF >> ${FIRMWARE_INFO_FOR_TEST}
hardware id =${hardware_id}
md5 =
EOF

	if [ "${TILE2}" = "y" ]; then
		local plugin_info
		local plugin_id
		local plugin_version
		local cur_plugin_config=${PLUGIN_CONFIG_FILE}".bak"

		plgs=`sed -n '/plugins/'p ${cur_plugin_config} | awk -F= '{print $2}' | sed 's/,/ /g'`
		for plugin in $plgs
		do
			plugin_id=$(awk -F '=' '/\['"$plugin"'\]/{a=1}a==1&&$1~/'"plugin_id"'/\
				{gsub(/[[:blank:]]*/,"",$2);print $2;exit}' $cur_plugin_config)
			plugin_version=$(awk -F '=' '/\['"$plugin"'\]/{a=1}a==1&&$1~/\'"plugin_version"'/\
				{gsub(/[[:blank:]]*/,"",$2);print $2;exit}' $cur_plugin_config)
			plugin_info=${plugin_info}"{\"plugInID\":\"${plugin_id}\", \"plugInVer\":\"${plugin_version}\"}"
		done
		plugin_info=`echo $plugin_info | sed -n 's/}{/}, {/g'p`

		cat <<EOF >> ${FIRMWARE_INFO_FOR_TEST}
plugin = [${plugin_info}]

EOF
	fi

	return 0
}

function generate_up_firmware_info()
{
	local hardwrae_id

	echo "[upgrade firmware]" >> ${FIRMWARE_INFO_FOR_TEST}
	sed -n "2,3p" ${UP_FIRMWARE_INFO_FILE} >> ${FIRMWARE_INFO_FOR_TEST}
	hardware_id=$(awk -F '=' '/'"hardware ID"'/{print $2}' ${FIRMWARE_CONFIG_FILE})

	cat <<EOF >> ${FIRMWARE_INFO_FOR_TEST}
hardware id =${hardware_id}
md5 =
EOF

	if [ "${TILE2}" = "y" ]; then
		local plugin_info
		local plugin_id
		local plugin_version
		plgs=`sed -n '/plugins/'p ${PLUGIN_CONFIG_FILE} | awk -F= '{print $2}' | sed 's/,/ /g'`
		for plugin in $plgs
		do
			plugin_id=$(awk -F '=' '/\['"$plugin"'\]/{a=1}a==1&&$1~/'"plugin_id"'/\
				{gsub(/[[:blank:]]*/,"",$2);print $2;exit}' $PLUGIN_CONFIG_FILE)
			plugin_version=$(awk -F '=' '/\['"$plugin"'\]/{a=1}a==1&&$1~/\'"plugin_version"'/\
				{gsub(/[[:blank:]]*/,"",$2);print $2;exit}' $PLUGIN_CONFIG_FILE)
			plugin_info=${plugin_info}"{\"plugInID\":\"${plugin_id}\", \"plugInVer\":\"${plugin_version}\"}"
		done
		plugin_info=`echo $plugin_info | sed -n 's/}{/}, {/g'p`

		cat <<EOF >> ${FIRMWARE_INFO_FOR_TEST}
plugin = [${plugin_info}]
EOF
	fi

	return 0
}

function generate_firmwate_info_for_test()
{
	generate_cur_firmware_info
	if [ "$?" -ne "0" ]; then
		echo "generate current firmware info error!"
	fi

	generate_up_firmware_info
	if [ "$?" -ne "0" ]; then
		echo "generate up firmware info error!"
	fi
}

function resume_config_file()
{
	if [ ! -e ${VERSION_CONFIG_FILE}".bak" ] \
		|| [ ! -e ${FIRMWARE_CONFIG_FILE}".bak" ]; then
		echo "there are some modified files not existed. do nothing"
		return 1
	fi

	mv ${VERSION_CONFIG_FILE}".bak" ${VERSION_CONFIG_FILE}
	mv ${FIRMWARE_CONFIG_FILE}".bak" ${FIRMWARE_CONFIG_FILE}

	if [ "${TILE2}" = "y" ]; then
		if [ ! -e ${PLUGIN_CONFIG_FILE}".bak" ]; then
			echo "the plugin.config.bak is not existed. not resume it"
			return 1
		fi
		mv ${PLUGIN_CONFIG_FILE}".bak" ${PLUGIN_CONFIG_FILE}
	fi
	return 0
}

function modify_config_file()
{
	if [ ! -e ${VERSION_CONFIG_FILE} ] \
		|| [ ! -e ${FIRMWARE_CONFIG_FILE} ] \
		|| [ ! -e ${FIRMWARE_INFO_FILE} ]; then
		echo "there are some files not existed. do nothing"
		return 1
	fi

	if [ "${TILE2}" = "y" ] && [ ! -e ${PLUGIN_CONFIG_FILE} ]; then
		echo "the plugin.config is not existed. do nothing"
		return 1
	fi

	backup_config_file
	if [ "$?" -ne "0" ]; then
		echo "backup config files error!"
		return 2
	fi

	if [ "${TILE2}" = "y" ]; then
		increase_plugin_version
		if [ "$?" -ne "0" ]; then
			echo "increase plugins version error!"
			return 3
		fi
	fi

	increase_firmware_version
	if [ "$?" -ne "0" ]; then
		echo "increase firmware version error!"
		return 4
	fi

	config_firmware_info
	if [ "$?" -ne "0" ]; then
		echo "config firmware config error!"
		return 5
	fi

	return 0
}

function make_up_test_main()
{
    T_DIR=$PWD
	TARGET_DIR=$(ls -l $T_DIR/build_dir | awk '/target-/ {print $NF}')
	TARGET_DIR=$T_DIR/build_dir/${TARGET_DIR}
	IB_NAME=$(ls -l ${TARGET_DIR} | awk '/SLP_Image_Builder_for_'${ProductName}'/ {print $NF}')

	cd ${TARGET_DIR}/${IB_NAME}

	TILE2=
	BIN_DIR_NAME=bin/$(awk -F '=' '/'"CONFIG_TARGET_BOARD"'/{print $2;exit}' product_config/${ProductName}/buildroot.config)
	BIN_DIR_NAME=$(echo $BIN_DIR_NAME | sed 's/\"//g')
	CONFIG_DIR=product_config/${ProductName}
	BIN_DIR=${T_DIR}/${BIN_DIR_NAME}
	VERSION_CONFIG_FILE=$CONFIG_DIR/version.config
	FIRMWARE_CONFIG_FILE=$CONFIG_DIR/firmware.config

	if [ "${TILE2}" = "y" ]; then
		PLUGIN_CONFIG_FILE=$CONFIG_DIR/plugin.config
	fi
	FIRMWARE_INFO_FILE=$BIN_DIR/current_firmware.config
	UP_FIRMWARE_INFO_FILE=$BIN_DIR/up_test_firmware.config
	FIRMWARE_INFO_FOR_TEST=$BIN_DIR/firmware.config

	modify_config_file

	rm -rf ${BIN_DIR_NAME}

	make PROFILE=${ProductName} image

	UP_BOOT=$(ls -l ./${BIN_DIR_NAME} | awk '/up_boot/ {print $NF}')
	UP_TEST_FIRMWARE=$(echo $UP_BOOT | awk -F 'up_boot' '{printf("%sup_test_firmware%s", $1, $2)}')

	cp ./${BIN_DIR_NAME}/current_firmware.config ${T_DIR}/${BIN_DIR_NAME}/up_test_firmware.config
	cp ./${BIN_DIR_NAME}/${UP_BOOT} ${T_DIR}/${BIN_DIR_NAME}/${UP_TEST_FIRMWARE}
	if [ "${TILE2}" = "y" ]; then
		tar -jcvf ${T_DIR}/${BIN_DIR_NAME}/plugins_for_test.tar.bz2 ./${BIN_DIR_NAME}/plugins
	fi

	generate_firmwate_info_for_test
	resume_config_file
}

make_up_test_main
