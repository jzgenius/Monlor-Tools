#!/bin/ash /etc/rc.common
monlorpath=$(uci -q get monlor.tools.path)
[ $? -eq 0 ] && source "$monlorpath"/scripts/base.sh || exit

START=95
STOP=95
SERVICE_USE_PID=1
SERVICE_WRITE_PID=1
SERVICE_DAEMONIZE=1

service=KodExplorer
appname=kodexplorer
EXTRA_COMMANDS=" status backup recover"
EXTRA_HELP="        status  Get $appname status"
# port=81
PHPBIN=/opt/bin/spawn-fcgi
NGINXBIN=/opt/sbin/nginx
NGINXCONF=/opt/etc/nginx/nginx.conf
PHPCONF=/opt/etc/php.ini
WWW=/opt/share/nginx/html
CONF="/opt/etc/nginx/vhost/kodexplorer.conf"
LOG=/var/log/$appname.log
path=$(uci -q get monlor.$appname.path) 
port=$(uci -q get monlor.$appname.port) || port=81
opkg_list="php7-cgi php7-mod-curl php7-mod-gd php7-mod-iconv php7-mod-json php7-mod-mbstring php7-mod-opcache php7-mod-session php7-mod-zip nginx spawn-fcgi zoneinfo-core zoneinfo-asia"

set_config() {

	for i in $opkg_list 
	do
		result=$(opkg list-installed | grep -c "^$i")
		[ "$result" == '0' ] && opkg install $i
	done
	
	if [ ! -f "$NGINXCONF".bak ]; then
	 	logsh "【$service】" "检测到nginx未配置, 正在配置..."
		#修改nginx配置文件
		[ ! -x "$NGINXBIN" ] && logsh "【$service】" "nginx未安装" && exit
		[ ! -f "$NGINXCONF" ] && logsh "【$service】" "未找到nginx配置文件！" && exit
		cp $NGINXCONF $NGINXCONF.bak
		cat > "$NGINXCONF" <<-\EOF
		user root;
		pid /opt/var/run/nginx.pid;
		worker_processes auto;
		worker_rlimit_nofile 65535;

		events {

		    use epoll;
		    multi_accept on;
		    worker_connections 51200;

		}

		http {

		    sendfile                        on;
		    tcp_nopush                      on;
		    tcp_nodelay                     on;
		    default_type                    application/octet-stream;
		    server_tokens                   off;
		    keepalive_timeout               60;
		    client_max_body_size            2000m;
		    client_body_temp_path           /opt/tmp/;
		    client_header_buffer_size       8k;
		    large_client_header_buffers     4 32k;
		    server_names_hash_bucket_size   128;
		    gzip                            on;
		    gzip_vary                       on;
		    gzip_proxied                    expired no-cache no-store private no_last_modified no_etag auth;
		    gzip_types                      application/atom+xml application/javascript application/json application/ld+json application/manifest+json application/rss+xml application/vnd.geo+json application/vnd.ms-fontobject application/x-font-ttf application/x-web-app-manifest+json application/xhtml+xml application/xml font/opentype image/bmp image/svg+xml image/x-icon text/cache-manifest text/css text/plain text/vcard text/vnd.rim.location.xloc text/vtt text/x-component text/x-cross-domain-policy;
		    gzip_disable                    "MSIE [1-6]\.";
		    gzip_buffers                    4 16k;
		    gzip_comp_level                 4;
		    gzip_min_length                 1k;
		    gzip_http_version               1.1;
		    fastcgi_buffers                 4 64k;
		    fastcgi_buffer_size             64k;
		    fastcgi_send_timeout            300;
		    fastcgi_read_timeout            300;
		    fastcgi_connect_timeout         300;
		    fastcgi_busy_buffers_size       128k;
		    fastcgi_temp_file_write_size    256k;
		    include                         mime.types;
		    include                         /opt/etc/nginx/vhost/*.conf;

		}
		EOF
	fi
	#生成配置文件
	[ ! -d "/opt/etc/nginx/vhost" ] && mkdir -p /opt/etc/nginx/vhost
	rm -rf $CONF
	cat > "$CONF" <<-\EOF
	server {
	        listen  81;
	        server_name  kodexplorer;

	        location / {
	            root   /opt/share/nginx/html;
	            index  index.php index.html index.htm;
	        }

	        error_page   500 502 503 504  /50x.html;
	        location = /50x.html {
	            root   html;
	        }

	        location ~ \.php$ {
	            root           /opt/share/nginx/html;
	            fastcgi_pass   127.0.0.1:9009;
	            fastcgi_index  index.php;
	            fastcgi_param  SCRIPT_FILENAME  $document_root$fastcgi_script_name;
	            include        fastcgi_params;
	        }
	}
	EOF
	sed -i "s/81/$port/" $CONF
	

	if [ ! -f "$PHPCONF".bak ]; then
		logsh "【$service】" "检测到php未配置, 正在配置..."
		result=$(opkg list-installed | grep -c "^php7-cgi")
		[ "$result" == '0' ] && logsh "【$service】" "php未安装" && exit
		[ ! -f "$PHPCONF" ] && logsh "【$service】" "未找到php配置文件！" && exit
		cp $PHPCONF $PHPCONF.bak
		sed -i "/doc_root/d" $PHPCONF
		sed -i "s#.*open_basedir.*#open_basedir = \"$WWW\"#" $PHPCONF
		sed -i 's/memory_limit = 8M/memory_limit = 20M/' $PHPCONF
		sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 2000M/' $PHPCONF

		echo "<?php phpinfo(); ?>" > $WWW/info.php
		rm -rf $WWW/index.html
	fi
	if [ ! -d $WWW/app/kod/ ]; then
		logsh "【$service】" "未检测到$appname文件，正在下载"
		curl -skLo $WWW/kodexplorer.tar.gz $monlorurl/temp/kodexplorer.tar.gz
		[ $? -ne 0 ] && logsh "【$service】" "$appname文件下载失败" && exit
		tar zxvf $WWW/kodexplorer.tar.gz -C $WWW
		rm -rf $WWW/kodexplorer.tar.gz
	fi
	
	logsh "【$service】" "挂载$appname管理目录"
	if [ ! -z "$path" ]; then
		if [ -d $WWW/data/User/admin/home ]; then
			mount -o blind $path $WWW/data/User/admin/home
		else
			logsh "【$service】" "检测到$appname服务未配置，无法挂载管理目录"
		fi
	fi
}

start () {

	result=$(ps | grep -E 'nginx|php-cgi' | grep -v sysa | grep -v grep | wc -l)
    	if [ "$result" != '0' ] && [ -f "$CONF" ];then
		logsh "【$service】" "$appname已经在运行！"
		exit 1
	fi
	result=$(ps | grep entware.sh | grep -v grep | wc -l)
    	if [ "$result" != '0' ];then
		logsh "【$service】" "检测到【Entware】正在运行，现在启用$appname可能会冲突"
		exit 1
	fi
	logsh "【$service】" "正在启动$appname服务... "
	#检查entware状态
	result1=$(uci -q get monlor.entware)
	result2=$(ls /opt | grep etc)
	if [ -z "$result1" ] || [ -z "$result2" ]; then 
		logsh "【$service】" "检测到【Entware】服务未启动或未安装"
		exit
	else
		result3=$(echo $PATH | grep opt)
		[ -z "$result3" ] && export PATH=/opt/bin/:/opt/sbin:$PATH
	fi

	set_config
	
	iptables -I INPUT -p tcp --dport $port -m comment --comment "monlor-$appname" -j ACCEPT 
	/opt/etc/init.d/S80nginx start >> /tmp/messages 2>&1
	if [ $? -ne 0 ]; then
		logsh "【$service】" "启动nginx服务失败！"
		exit
	fi
	$PHPBIN -a 127.0.0.1 -p 9009 -C 2 -f /opt/bin/php-cgi >> /tmp/messages 2>&1   
	if [ $? -ne 0 ]; then
                logsh "【$service】" "启动php服务失败！"
		exit
    fi
    logsh "【$service】" "$appname服务启动完成"
    logsh "【$service】" "请在浏览器中访问[http://192.168.31.1:$port]配置"

}

stop () {

	logsh "【$service】" "正在停止$appname服务... "
	# /opt/etc/init.d/S80nginx stop >> /tmp/messages 2>&1
	killall php-cgi >> /tmp/messages 2>&1
	kill -9 $(ps | grep 'php-cgi' | grep -v sysa | grep -v grep | awk '{print$1}') > /dev/null 2>&1
	umount $WWW/data/User/admin/home > /dev/null 2>&1
	rm -rf $CONF
	iptables -D INPUT -p tcp --dport $port -m comment --comment "monlor-$appname" -j ACCEPT > /dev/null 2>&1

}

restart () {

	stop
	sleep 1
	start

}

status() {

	result=$(ps | grep -E 'nginx|php-cgi' | grep -v sysa | grep -v grep | wc -l)
	if [ "$result" -lt '5' ] && [ ! -f "$CONF" ]; then
		echo "未运行"
		echo "0"
	else
		echo "运行端口号: $port, 管理目录: $path"
		echo "1"
	fi

}

backup() {
	mkdir -p $monlorbackup/$appname
	echo -n
}

recover() {
	echo -n
}