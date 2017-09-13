#! /bin/sh
stty -echo

which which || yum install -y which

#function define
function read_default()
{
    read -p "$1[default: $2]:  " read_val
    if [ -z "$read_val" ]; then
        read_val=$2
    fi

    echo "$read_val"
}

function read_pwd()
{
    read -p "$1[default: 88888888]:  " -s read_val
    if [ -z "$read_val" ]; then
    	read_val="88888888"
	fi

    echo "$read_val"
}

function check_install()
{
	which $1 || install_package+="$2 "
}

#read custom setting from user input
shadowsocks_port=$(read_default "shadowsocks_port" 8388)
echo -e "\n"
shadowsocks_localport=$(read_default "shadowsocks_localport" 1080)
echo -e "\n"
shadowsocks_pwd=$(read_pwd "shadowsocks_pwd")
echo -e "\n"
kcptun_port=$(read_default "kcptun_port" 29900)
echo -e "\n"
kcptun_pwd=$(read_pwd "kcptun_pwd")
echo -e "\n"
supervisord_username=$(read_default "supervisord_username" "myuser")
echo -e "\n"
supervisord_passwd=$(read_pwd "supervisord_passwd")
echo -e "\n"

#check and install base package and util
install_package=""
check_install "git" "git"
check_install "httpd" "httpd"
check_install "firewalld" "firewalld"
check_install "wget" "wget"
check_install "openssl" "openssl"
check_install "python" "python"
check_install "tar" "tar"
check_install "bzip2" "bzip2"
check_install "gzip" "gzip"
check_install "easy_install" "python-setuptools"

yum update -y || exit 1

if [ -n "$install_package" ]; then
	yum install -y $install_package || exit 1
fi

which pip || easy_install pip || exit 1
which ssserver || pip install "git+https://github.com/shadowsocks/shadowsocks.git@master" || exit 1
which supervisord || pip install supervisor || exit 1

#kcptun bin update or install
rm -frd /tmp/ss-kcptun; mkdir /tmp/ss-kcptun
pushd /tmp/ss-kcptun
latestUrl=https://github.com$(wget -O- https://github.com/xtaci/kcptun/releases/latest | grep -P 'href=[\s\S]*kcptun-linux-amd64[\s\S]*' | cut -d'"' -f2 | cut -d'"' -f1)
wget $latestUrl
rm -frd /usr/kcptun; mkdir /usr/kcptun;
tar -xf kcptun-linux-amd64* && mv server_linux_amd64 /usr/kcptun/kcp-server && ln -s /usr/kcptun/kcp-server /usr/bin/kcptun
popd
rm -frd /tmp/ss-kcptun

#shadowsocks kcptun config
shadowsocks_bin=$(which ssserver || (echo "ssserver install failure..."; exit 1))
kcptun_bin=$(which kcptun || (echo "kcptun install failure..."; exit 1))
supervisord_bin=$((which supervisord && which echo_supervisord_conf) || (echo "supervisord install failure..."; exit 1))

(wget -O- https://raw.githubusercontent.com/a1991815a/breakwall/master/kcptun.json | sed "s/%kcptun_port%/$kcptun_port/g" | sed "s/%shadowsocks_port%/$shadowsocks_port/g" | sed "s/%kcptun_pwd%/$kcptun_pwd/g") > /etc/kcptun.json
(wget -O- https://raw.githubusercontent.com/a1991815a/breakwall/master/shadowsocks.json | sed "s/%shadowsocks_port%/$shadowsocks_port/g" | sed "s/%shadowsocks_localport%/$shadowsocks_localport/g" | sed "s/%shadowsocks_pwd%/$shadowsocks_pwd/g") > /etc/shadowsocks.json

#supervisord config
wget -O- https://raw.githubusercontent.com/a1991815a/breakwall/master/supervisord.conf | sed "s/%username%/$supervisord_username/g" | sed "s/%password%/$supervisord_passwd/g" | sed "s/%shadowsocks_bin%/$shadowsocks_bin/g" | sed "s/%kcptun_bin%/$kcptun_bin/g" >/etc/supervisord.conf

if [ -z "$(cat /etc/rc.local | grep supervisord)" ]; then
	echo "supervisord -c /etc/supervisord.conf" >> /etc/rc.local
fi

systemctl start firewalld

#firewalld setting
firewall-cmd --remove-service=shadowsocks --permanent
firewall-cmd --remove-service=kcptun --permanent
firewall-cmd --remove-service=supervisord --permanent

firewall-cmd --delete-service=shadowsocks --permanent
firewall-cmd --delete-service=kcptun --permanent
firewall-cmd --delete-service=supervisord --permanent

firewall-cmd --new-service=shadowsocks --permanent
firewall-cmd --new-service=kcptun --permanent
firewall-cmd --new-service=supervisord --permanent

firewall-cmd --service=shadowsocks --add-port=$shadowsocks_port/tcp --permanent
firewall-cmd --service=shadowsocks --add-port=$shadowsocks_port/udp --permanent

firewall-cmd --service=kcptun --add-port=$kcptun_port/udp --permanent

firewall-cmd --service=supervisord --add-port=9001/tcp --permanent

firewall-cmd --add-service=shadowsocks --permanent
firewall-cmd --add-service=kcptun --permanent
firewall-cmd --add-service=supervisord --permanent
firewall-cmd --add-service=http --permanent
firewall-cmd --add-service=https --permanent

stty echo