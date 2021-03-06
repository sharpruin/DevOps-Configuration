#!/bin/bash
#获取宿主机ip地址
hostip=`ifconfig enp0s3 | grep "inet " | awk -F " " '{print $2}'`

if [ "x$hostip" == "x" ]; then
    echo "cann't resolve host ip address"
    exit 1
fi

mkdir -p log

case "$1" in
dashboard) #启动dashboard
    docker rm -f      "Codis-D28080" &> /dev/null
    docker run --name "Codis-D28080" -d \
         -v `realpath config/dashboard.toml`:/codis/dashboard.toml \
                    -v `realpath log`:/codis/log \
        -p 28080:18080 \
         --privileged=true \
        lzw2006/codis \
        codis-dashboard -l /codis/log/dashboard.log -c /codis/dashboard.toml --host-admin ${hostip}:28080
    ;;

proxy)  #启动proxy
    docker rm -f      "Codis-P29000" &> /dev/null
    docker run --name "Codis-P29000" -d \
        --read-only -v `realpath config/proxy.toml`:/codis/proxy.toml \
                    -v `realpath log`:/codis/log \
        -p 29000:19000 -p 21080:11080 \
    --privileged=true \
        lzw2006/codis \
        codis-proxy -l /codis/log/proxy.log -c /codis/proxy.toml --host-admin ${hostip}:29000 --host-proxy ${hostip}:21080
    ;;

server) #启动4个redis实例
    for ((i=0;i<4;i++)); do
        let port="26379 + i"
        docker rm -f      "Codis-S${port}" &> /dev/null
        docker run --name "Codis-S${port}" -d \
            -v `realpath log`:/codis/log \
            -p $port:6379 \
        --privileged=true \
            lzw2006/codis \
            codis-server --logfile /codis/log/${port}.log
    done
    ;;

fe) #启动监控页面
    docker rm -f      "Codis-F8080" &> /dev/null
    docker run --name "Codis-F8080" -d \
         -v `realpath log`:/codis/log \
         -v `realpath config/codis.json`:/codis/codis.json \
         -p 8080:8080 \
     -privileged=true \
     lzw2006/codis \
      /gopath/src/github.com/CodisLabs/codis/bin/codis-fe -l /codis/log/fe.log --dashboard-list=/codis/codis.json --listen=0.0.0.0:8080
    ;;


cleanup)
    docker rm -f      "Codis-D28080" &> /dev/null
    docker rm -f      "Codis-P29000" &> /dev/null
    for ((i=0;i<4;i++)); do
        let port="26379 + i"
        docker rm -f      "Codis-S${port}" &> /dev/null
    done
    ;;

*)
    echo "wrong argument(s)"
    ;;

esac
