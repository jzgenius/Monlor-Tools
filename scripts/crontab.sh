#!/bin/ash
#copyright by monlor
monlorpath=$(uci -q get monlor.tools.path)
[ $? -eq 0 ] && source "$monlorpath"/scripts/base.sh || exit

logsh "【Tools】" "定时任务crontab.sh启动..."
logger -s -t "【Tools】" "获取更新插件列表"
rm -rf /tmp/applist.txt
[ "$model" == 'arm' ] && applist="applist.txt"
[ "$model" == 'mips' ] && applist="applist_mips.txt"
curl -skLo /tmp/applist.txt $monlorurl/config/"$applist"
if [ $? -eq 0 ]; then
	rm -rf $monlorpath/config/applist*.txt
	mv /tmp/applist.txt $monlorpath/config
else 
	logsh "【Tools】" "获取失败，检查网络问题！"
fi

logger -s -t "【Tools】" "获取插件版本信息"
rm -rf /tmp/tools_version.txt
curl -skLo /tmp/tools_version.txt $monlorurl/config/version.txt 
mkdir -p /tmp/version > /dev/null 2>&1
cat $monlorpath/config/applist.txt | while read line
do
	[ ! -z $line ] && curl -skLo /tmp/version/$line.txt $monlorurl/apps/$line/config/version.txt 
done