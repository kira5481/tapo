#!/bin/bash

#*******************************************************************
# 在制作文件系统之前,根据plugin.config的内容，制作并拷贝插件<预安装>
#*******************************************************************
#$1: config file name, like: plugin.config(format: ini)
#$2: package directory, like: /disk1/ap135/torchlight/bin/ar71xx/packages
#$3: plugin directory, like: /disk1/ap135/torchlight/plugin
#$4: plugin tool's parent path, like: /disk1/ap135/torchlight/staging_dir/host/bin
#$5: ipkg-tar path, like: /disk1/ap135/torchlight/scripts/ipkg-tar
#$6: data plugin directory, like: /disk1/ap135/torchlight/build_dir/target-mips_r2_uClibc-0.9.33.2/root-ar71xx
#$7: bin directory, like: /disk1/ap135/torchlight/bin/ar71xx
#*******************************************************************

CONFIG_FILE=$1
PKG_DIR=$2
PLUGIN_DIR=$3
HOST_BIN_DIR=$4
SCRIPTS_DIR=$5
DATA_PLUGIN_DIR=$6/data/plugin
PLUGIN_FACTORY_CONFIG=$6/etc/config/plugin_fac
PRE_STORED_PLUGIN_LIST_FILE=$3/plugin.pre
BIN_PRODUCT_DIR=$7
PLUGIN_BIN_DIR=$7/plugins
BOARD_NAME=$8

# according to plugin.config, make factory plugins
make_factory_plugin()
{
	local plugin_id

	# get plugin list from product_config/hardware_type/plugin.config, and make plugins
	plgs=`sed -n '/plugins/'p ${CONFIG_FILE} | awk -F= '{print $2}' | sed 's/,/ /g'`
	for plugin in $plgs
	do
		# make plugin
		${HOST_BIN_DIR}/ipkg-buildplugin ${CONFIG_FILE} ${PKG_DIR} ${PLUGIN_DIR} ${HOST_BIN_DIR} ${SCRIPTS_DIR} ${plugin}
		
		# get plugin_id
		plugin_id=$(awk -F '=' '/\['"$plugin"'\]/{a=1}a==1&&$1~/'"plugin_id"'/{gsub(/[[:blank:]]*/,"",$2);print $2;exit}' $CONFIG_FILE)
		
		# copy plugin_bin to plugin_dir
		cp ${PLUGIN_DIR}/${plugin}_${plugin_id}/${plugin}_${plugin_id}_*.bin ${DATA_PLUGIN_DIR}
	done
	
	return 0
}

# init plugin environment
init_plugin_environment()
{
	# initialize preinstall plugin list
	rm -rf ${PRE_STORED_PLUGIN_LIST_FILE}
	
	# make directory for saving plugin bin files
	mkdir -p ${PLUGIN_BIN_DIR}
	
	# clean/create config file [plugin_fac]
	cat /dev/null > ${PLUGIN_FACTORY_CONFIG}
	
	return 0
}

# generate factory config file[plugin_fac]
generate_factory_config()
{
	local pre_installed=0
	plugin_ids=$(cat ${PRE_STORED_PLUGIN_LIST_FILE})
	for plugin_id in ${plugin_ids}
	do
		if [[ "${plugin_id}" != "#"* ]]; then
			cat ${PLUGIN_DIR}/*${plugin_id}/factory.config >> ${PLUGIN_FACTORY_CONFIG}
			let "pre_installed+=1" 
		fi
	done

	cat <<EOF >> ${PLUGIN_FACTORY_CONFIG}

config plugin_profile 'plugin'
        option pre_installed '${pre_installed}'
        option can_update '0'
        option manual_installed '0'
        option not_installed '0'
EOF

	return 0
}

# copy plugin bin files and calc md5, prepare for releasing.
prepare_release_plugin()
{
	# copy plugin bin files to ${BIN_DIR}/plugins, prepare for releasing.
	cp -R ${DATA_PLUGIN_DIR}/* ${PLUGIN_BIN_DIR}/
	
	( cd ${PLUGIN_BIN_DIR} ; \
		find -maxdepth 1 -type f \! -name 'md5sums'  -printf "%P\n" | sort | xargs \
		md5sum --binary > md5sums \
	)
	
	( cd ${BIN_PRODUCT_DIR}; \
		find ./ -iname SLP_Plugins_${BOARD_NAME}_*.tar.bz2 | xargs rm -rf; \
		tar -jcvf  ${BIN_PRODUCT_DIR}/SLP_Plugins_${BOARD_NAME}_$(date "+%y%m%d").tar.bz2 plugins/ \
	)
}

plugin_main()
{
	# do not preinstall plugins, return immediately.
	if [ ! -e ${CONFIG_FILE} ]; then
		echo "There are no plugins to be preinstalled, do nothing."
		return 0
	fi

	init_plugin_environment
	if [ "$?" -ne "0" ]; then         
		echo "init plugin environment error!"                                                    
		return 1                                                    
	fi
	
	make_factory_plugin
	if [ "$?" -ne "0" ]; then         
		echo "make factory plugins error!"                                                    
		return 2                                                    
	fi
	
	generate_factory_config
	if [ "$?" -ne "0" ]; then         
		echo "generate factory config error!"                                                    
		return 3                                                    
	fi
	
	prepare_release_plugin
	if [ "$?" -ne "0" ]; then         
		echo "prepare release plugin error!"                                                    
		return 4                                                    
	fi
	
	return 0
}

plugin_main

