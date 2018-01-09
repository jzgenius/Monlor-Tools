#!/bin/ash
#copyright by monlor
monlorpath=$(uci -q get monlor.tools.path)
[ $? -eq 0 ] && source "$monlorpath"/scripts/base.sh || exit

wgetfilepath="$1"
wgetfilename=$(basename $1)
wgeturl="$2"

logsh "【Tools】" "下载程序中..."
curl -skLo /tmp/md5.txt $monlorurl/md5.txt
curl -skLo "$wgetfilepath" "$wgeturl"
if [ $? -eq 0 ]; then
	result1=0
else
	result1=1
fi
logsh "【Tools】" "校验MD5文件信息"
local_md5=$(md5sum "$wgetfilepath" | cut -d' ' -f1)
origin_md5=$(cat /tmp/md5.txt | grep "$wgetfilename" | cut -d' ' -f4)
[ ${#origin_md5} -lt 32 ] && origin_md5=$(cat /tmp/md5.txt | grep "$wgetfilename" | cut -d' ' -f1)
if [ "$local_md5" == "$origin_md5" ]; then
	result2=0
else
	rm -rf $wgetfilepath
	result2=1
fi

if [ "$result1" == '0' -a "$result2" == '0' ]; then
	echo -n 0
else
	echo -n 1
fi
