#!/bin/ash /etc/rc.common
monlorpath=$(uci -q get monlor.tools.path)
[ $? -eq 0 ] && source "$monlorpath"/scripts/base.sh || exit

START=95
STOP=95
SERVICE_USE_PID=1
SERVICE_WRITE_PID=1
SERVICE_DAEMONIZE=1

service=HttpFile
appname=httpfile
EXTRA_COMMANDS=" status backup recover"
EXTRA_HELP="        status  Get $appname status"
port=1688
BIN=/opt/sbin/nginx
NGINXCONF=/opt/etc/nginx/nginx.conf
CONF=/opt/etc/nginx/vhost/httpfile.conf
LOG=/var/log/$appname.log
lanip=$(uci get network.lan.ipaddr)
path=$(uci -q get monlor.$appname.path) || path="$userdisk"
port=$(uci -q get monlor.$appname.port) || port=88

set_config() {

	result=$(opkg list-installed | grep -c "^nginx")
	[ "$result" == '0' ] && opkg install nginx
	if [ ! -f "$NGINXCONF".bak ]; then
	 	logsh "【$service】" "检测到nginx未配置, 正在配置..."
		#修改nginx配置文件
		[ ! -x "$BIN" ] && logsh "【$service】" "nginx未安装" && exit
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
	# 生成配置文件
	[ ! -d "/opt/etc/nginx/vhost" ] && mkdir -p /opt/etc/nginx/vhost
	rm -rf $CONF
	cat > "$CONF" <<-\EOF
	server {
	        listen  88;
	        server_name  httpfile;
	        charset utf-8;
	        location / {
	            root   directory;
	            index  index.php index.html index.htm;
	            autoindex on;
	            autoindex_exact_size on;
	            autoindex_localtime on;
	        }	     
	}
	EOF
	sed -i "s/88/$port/" $CONF
	sed -i "s#directory#$path#" $CONF

}

start () {

	result=$(ps | grep nginx |  grep -v sysa | grep -v grep | wc -l)
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
	# 检查entware
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
	[ ! -f "/opt/etc/init.d/S80nginx" ] && logsh "【$service】" "未找到启动脚本！" && exit
	/opt/etc/init.d/S80nginx restart >> /tmp/messages 2>&1
	if [ $? -ne 0 ]; then
        logsh "【$service】" "启动$appname服务失败！"
		exit
    fi
    logsh "【$service】" "启动$appname服务完成！"
    logsh "【$service】" "请在浏览器中访问[http://$lanip:$port]"

}

stop () {

	logsh "【$service】" "正在停止$appname服务... "
	# /opt/etc/init.d/S80nginx stop > /dev/null 2>&1
	rm -rf $CONF
	iptables -D INPUT -p tcp --dport $port -m comment --comment "monlor-$appname" -j ACCEPT > /dev/null 2>&1

}

restart () {

	stop
	sleep 1
	start

}

status() {

	result=$(ps | grep nginx | grep -v sysa | grep -v grep | wc -l)
	if [ "$result" == '0' ] || [ ! -f "$CONF" ]; then
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