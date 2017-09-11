#! /bin/sh
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
tar -xf kcptun-linux-amd64* && mv server_linux_amd64 /usr/kcptun/kcp-server && ln -s /usr/kcptun/kcp-server /usr/bin/kcptun

which ssserver || (echo "ssserver install failure..."; exit 1)
which kcptun || (echo "kcptun install failure..."; exit 1)
which supervisord || (echo "supervisord install failure..."; exit 1)