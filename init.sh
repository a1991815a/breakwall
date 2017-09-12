#! /bin/sh
function read_default()
{
    read -p "$1[default: $2]" read_val
    if [ -z "$read_val" ]; then
        read_val=$2
    fi
    return $read_val
}

yum update -y
yum install -y vim git httpd firewalld wget openssl python tar bzip2 gzip
yum install -y python-setuptools && easy_install pip
pip install git+https://github.com/shadowsocks/shadowsocks.git@master
pip install supervisor

mkdir /tmp/tmp
pushd /tmp/ss-kcptun && rm -frd *

latestUrl=https://github.com$(wget -O- https://github.com/xtaci/kcptun/releases/latest | grep -P 'href=[\s\S]*kcptun-linux-amd64[\s\S]*' | cut -d'"' -f2 | cut -d'"' -f1)
wget -O- $latestUrl

rm -frd /usr/kcptun
mkdir /usr/kcptun
rm -frd /usr/shadowsocks
mkdir /usr/shadowsocks

tar -xf kcptun-linux-amd64* && mv server_linux_amd64 /usr/kcptun/kcp-server && ln -s /usr/kcptun/kcp-server /usr/bin/kcptun

shadowsocks_bin=$(which ssserver || (echo "ssserver install failure..."; exit 1))
kcptun_bin=$(which kcptun || (echo "kcptun install failure..."; exit 1))
supervisord_bin=$(which supervisord && which echo_supervisord_conf || (echo "supervisord install failure..."; exit 1))

shadowsocks_port=$(read_default "shadowsocks_port" 8388)
shadowsocks_localport=$(read_default "shadowsocks_localport" 1080)
shadowsocks_localport=$(read_default "shadowsocks_localport" 1080)
shadowsocks_localport=$(read_default "kcptun_port" 29900)
shadowsocks_localport=$(read_default "kcptun_pwd" 123123)

wget -O- https://raw.githubusercontent.com/a1991815a/breakwall/master/kcptun.json > /etc/kcptun.json
wget -O- https://raw.githubusercontent.com/a1991815a/breakwall/master/shadowsocks.json > /etc/shadowsocks.json


read -p "supervisord control username: " username
read -p "supervisord control password: " -s password


newline=$'\n'

supervisord_script=""
supervisord_script+="[unix_http_server]$newline"
supervisord_script+="file=/tmp/supervisor.sock$newline"
supervisord_script+="chmod=0700$newline"
supervisord_script+="chown=root:root$newline"
supervisord_script+="username=$username$newline"
supervisord_script+="password=$password$newline"

supervisord_script+="[inet_http_server]$newline"
supervisord_script+="port=0.0.0.0:9001$newline"
supervisord_script+="username=$username$newline"
supervisord_script+="password=$password$newline"

supervisord_script+="[program:shadowsocks]$newline"
supervisord_script+="command=$shadowsocks_bin -c /etc/shadowsocks.json$newline"
supervisord_script+="process_name=%(program_name)s$newline"
supervisord_script+="numprocs=1$newline"
supervisord_script+="directory=/usr/shadowsocks$newline"
supervisord_script+="umask=022$newline"
supervisord_script+="priority=999$newline"
supervisord_script+="autostart=true$newline"
supervisord_script+="startsecs=1$newline"
supervisord_script+="startretries=3$newline"
supervisord_script+="autorestart=true$newline"
supervisord_script+="stopwaitsecs=10$newline"
supervisord_script+="user=root$newline"

supervisord_script+="[program:kcptun]$newline"
supervisord_script+="command=$kcptun_bin -c /etc/kcptun.json$newline"
supervisord_script+="process_name=%(program_name)s$newline"
supervisord_script+="numprocs=1$newline"
supervisord_script+="directory=/usr/kcptun$newline"
supervisord_script+="umask=022$newline"
supervisord_script+="priority=998$newline"
supervisord_script+="autostart=true$newline"
supervisord_script+="startsecs=1$newline"
supervisord_script+="startretries=3$newline"
supervisord_script+="autorestart=true$newline"
supervisord_script+="stopwaitsecs=10$newline"
supervisord_script+="user=root$newline"

echo_supervisord_conf > /etc/supervisord.conf
after_line=$(cat /etc/supervisord.conf | grep -n unix_http_server | head -n 1 | cut -d ":" -f1)
after_line=$[after_line + 7]

echo $(cat /etc/supervisord.conf | sed -n "$after_line,\$p") >/etc/supervisord.conf

echo $supervisord_script >>/etc/supervisord.conf

firewall-cmd --new-service=shadowsocks --permanent
firewall-cmd --service=shadowsocks --add-port= --permanent