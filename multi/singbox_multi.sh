#!/bin/bash

version_tag=$(wget -qO- -t1 -T2 "https://api.github.com/repos/SagerNet/sing-box/releases" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g')
download_tag=$(echo $version_tag | sed "s/v//g")
filename=$(echo sing-box-$download_tag-linux-amd64.tar.gz)
folder=$(echo sing-box-$download_tag-linux-amd64)
wget -N --no-check-certificate https://github.com/SagerNet/sing-box/releases/download/$version_tag/sing-box-"$download_tag"-linux-amd64.tar.gz

tar zxvf $filename
mv $folder sing-box
cd sing-box

# generate keys and uuid
uuid=$(uuidgen)
ps=$(openssl rand -base64 16)
reality_keys=$(./sing-box generate reality-keypair)
private_key=$(echo $reality_keys | awk '{print $2}')
public_key=$(echo $reality_keys | awk '{print $4}')

echo -n "境外白名单网站:"                   
read  handshake_web
echo -n "shadowTLS 端口:"                   
read  stls_port
echo -n "vmess 端口:"                   
read  vmess_port

# get config
wget --no-check-certificate -O vmess_stls.json https://raw.githubusercontent.com/KYLELI1991/singbox/main/multi/vmess-stls.json

# get ip
wgcfv6status=$(curl -s6m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2) 
wgcfv4status=$(curl -s4m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
if [[ $wgcfv4status =~ "on"|"plus" ]] || [[ $wgcfv6status =~ "on"|"plus" ]]; then
        wg-quick down wgcf >/dev/null 2>&1
        systemctl stop warp-go >/dev/null 2>&1
        v6=$(curl -s6m8 api64.ipify.org -k)
        v4=$(curl -s4m8 api64.ipify.org -k)
        wg-quick up wgcf >/dev/null 2>&1
        systemctl start warp-go >/dev/null 2>&1
else
        v6=$(curl -s6m8 api64.ipify.org -k)
        v4=$(curl -s4m8 api64.ipify.org -k)
fi


sed -i "s/uuid_pass/$uuid/g" vmess_stls.json
sed -i "s/stls_pass/${ps}/g" vmess_stls.json
sed -i "s/handshake_web/$handshake_web/g" vmess_stls.json
sed -i "s/stls_port/$stls_port/g" vmess_stls.json
sed -i "s/vmess_port/$vmess_port/g" vmess_stls.json
sed -i "s/pri_key/$private_key/g" vmess_stls.json

nohup ./sing-box run -c vvmess_stls.json >/dev/null 2>&1 &

clash_proxy=$(echo -e "{name: singbox_vmess, type: vmess, server: $v4, port: $vmess_port, uuid: $uuid, alterId: 0, cipher: none, network: tcp, udp: true, servername: $handshake_web, reality-opts: {public-key: $public_key}} \n - {name: singbox_stls, type: ss, server: $v4, port: $stls_port, cipher: 2022-blake3-aes-128-gcm, password: $ps, plugin: shadow-tls, plugin-opts: {host: $handshake_web, password: $ps}}")
echo $reality_keys $clash_proxy >>clash_proxy.txt
echo -e "已完成安装singbox shadowTLS vmess reality clash meta 代理设置 \n $clash_proxy"
