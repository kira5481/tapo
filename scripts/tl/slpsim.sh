#!/bin/bash
#####################################################################
# Simulate SLP request, and get response.
# Ver 0.2
# by pax Created@160624
#####################################################################

usage() {
	cat <<EOF
Usage: slpsim.sh (jsonfile | jsonstring)
    e.g. slpsim.sh /path/to/request.json
    e.g. slpsim.sh '{"method":"get","status":{"name":"system_info"}}'
EOF
	exit 1
}

# DUT addr
http="http://192.168.1.254"

# login digest
# Tip: You can use `node slpdigest.js` to generate digest from raw password
digest="0KcgeXhc9TefbwK" # from raw password: 123456

### START ###

# Get auth stok
stok=`curl -e "$http" $http -d '{"method":"do","login":{"username":"admin","password":"'$digest'"}}' 2>/dev/null | egrep -o '"stok"[ ]*:[ ]*"[A-Za-z0-9]+"' | sed 's/"stok"[ ]*:[ ]*"//g' | sed 's/"//g'`;

if [[ "x$stok" == "x" ]]; then
	echo "ERR: stok not gotten!";
	exit;
fi

# Read request json
if [[ -r $1 ]]; then
	# from json file
	request=`cat $1`;
elif [[ -n $1 ]]; then
	# from json string
	request=$1;
else
	usage;
fi

if [[ "x$request" == "x" ]]; then
	echo "ERR: request not gotten!";
	exit;
fi

# Get response json
response=`curl -e "$http" "$http/stok=$stok/ds" -d "$request" 2>/dev/null`;
#response=`curl -e "$http" "$http" -d "$request" 2>/dev/null`;

if [[ "x$response" == "x" ]]; then
	echo "ERR: response not gotten!";
	exit;
fi

# Prettify response json
echo $response | python -m json.tool;

### END ###
