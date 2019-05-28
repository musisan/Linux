#/usr/bin/env bash
#Time:2019-05-28 06:03:23
set -e
shopt -s extglob

precwd=$(pwd -P)
version=${1:-"1.16.0"}
nginx_url="http://nginx.org/download/nginx-${version}.tar.gz"
nginx_file=`basename $nginx_url`

if [[ -f /etc/redhat-release ]]; then
    sudo yum install gcc pcre pcre-devel zlib zlib-devel openssl-devel perl-devel perl-ExtUtils-Embed -y

elif grep -Eqi "ubuntu" /etc/issue; then
    sudo apt-get install libpcre3 libpcre3-dev zlib1g-dev openssl libssl-dev libperl-dev -y
fi

if test ! -e $nginx_file; then
    wget -c -S $nginx_url
fi

test $(grep '^nginx' /etc/passwd | wc -l) -eq 0 \
    && sudo useradd -M -s /sbin/nologin nginx

test -x /bin/mktemp && tmpdir=$(mktemp -d tmp.XXX)

tar zxf $nginx_file -C $tmpdir

cd $tmpdir/${nginx_file%.tar.gz}

./configure --user=nginx --group=nginx \
    --prefix=/opt/nginx --with-http_ssl_module \
    --with-http_addition_module --with-http_dav_module \
    --with-http_gzip_static_module --with-http_perl_module \
    --with-mail --with-mail_ssl_module
make -j $(nproc) && sudo make install

cd /opt/nginx

sudo sed -i -e "2c user nginx;" -e "/processes/s/1/$(nproc)/" \
    -e "/events/a use epoll;" conf/nginx.conf

sudo sbin/nginx -t && sudo sbin/nginx -c conf/nginx.conf || { echo "Config file check failed."; exit 3; }

cd - && { mkdir ~/.vim &>/dev/null; cp -rf contrib/vim/* ~/.vim/; }
cd $precwd && rm -rf $tmpdir ${nginx_file}

[[ $(pidof nginx | wc -l) -eq 1 ]] && echo -e "[\033[0;32m OK \033[0m] Nginx Success." \
    || { echo -e "[\033[0;31m Error \033[0m] Nginx Failed."; exit 3; }
