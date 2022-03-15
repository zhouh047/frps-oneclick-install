#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

[[ $EUID -ne 0 ]] && echo -e "[${red}Error${plain}] 请使用root用户来执行脚本!" && exit 1

disable_selinux(){
    if [ -s /etc/selinux/config ] && grep 'SELINUX=enforcing' /etc/selinux/config; then
        sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
        setenforce 0
    fi
}

check_sys(){
    local checkType=$1
    local value=$2

    local release=''
    local systemPackage=''

    if [[ -f /etc/redhat-release ]]; then
        release="centos"
        systemPackage="yum"
    elif grep -Eqi "debian|raspbian" /etc/issue; then
        release="debian"
        systemPackage="apt"
    elif grep -Eqi "ubuntu" /etc/issue; then
        release="ubuntu"
        systemPackage="apt"
    elif grep -Eqi "centos|red hat|redhat" /etc/issue; then
        release="centos"
        systemPackage="yum"
    elif grep -Eqi "debian|raspbian" /proc/version; then
        release="debian"
        systemPackage="apt"
    elif grep -Eqi "ubuntu" /proc/version; then
        release="ubuntu"
        systemPackage="apt"
    elif grep -Eqi "centos|red hat|redhat" /proc/version; then
        release="centos"
        systemPackage="yum"
    fi

    if [[ "${checkType}" == "sysRelease" ]]; then
        if [ "${value}" == "${release}" ]; then
            return 0
        else
            return 1
        fi
    elif [[ "${checkType}" == "packageManager" ]]; then
        if [ "${value}" == "${systemPackage}" ]; then
            return 0
        else
            return 1
        fi
    fi
}

getversion(){
    if [[ -s /etc/redhat-release ]]; then
        grep -oE  "[0-9.]+" /etc/redhat-release
    else
        grep -oE  "[0-9.]+" /etc/issue
    fi
}

centosversion(){
    if check_sys sysRelease centos; then
        local code=$1
        local version="$(getversion)"
        local main_ver=${version%%.*}
        if [ "$main_ver" == "$code" ]; then
            return 0
        else
            return 1
        fi
    else
        return 1
    fi
}

get_ip(){
    local IP=$( ip addr | egrep -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | egrep -v "^192\.168|^172\.1[6-9]\.|^172\.2[0-9]\.|^172\.3[0-2]\.|^10\.|^127\.|^255\.|^0\." | head -n 1 )
    [ -z ${IP} ] && IP=$( wget -qO- -t1 -T2 ipv4.icanhazip.com )
    [ -z ${IP} ] && IP=$( wget -qO- -t1 -T2 ipinfo.io/ip )
    echo ${IP}
}

download(){
    local filename=${1}
    echo -e "[${green}Info${plain}] ${filename} download now..."
    wget --no-check-certificate -q -t3 -T60 -O ${1} ${2}
    if [ $? -ne 0 ]; then
        echo -e "[${red}Error${plain}] Download ${filename} failed."
        exit 1
    fi
}

error_detect_depends(){
    local command=$1
    local depend=`echo "${command}" | awk '{print $4}'`
    echo -e "[${green}Info${plain}] Starting to install package ${depend}"
    ${command} 
    if [ $? -ne 0 ]; then
        echo -e "[${red}Error${plain}] Failed to install ${red}${depend}${plain}"
        exit 1
    fi
}

install_dependencies(){
    if centosversion 8; then
	    echo "检测到系统为CentOS 8，正在更新源。使用vault.centos.org代替mirror.centos.org..."
        sed -i -e "s|mirrorlist=|#mirrorlist=|g" /etc/yum.repos.d/CentOS-*
	    sed -i -e "s|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g" /etc/yum.repos.d/CentOS-*
    fi
	
	if check_sys packageManager yum; then
		error_detect_depends "yum -y install wget" 
        error_detect_depends "yum -y install expect"
	error_detect_depends "yum -y install net-tools"	
	elif check_sys packageManager apt; then
		error_detect_depends "apt-get -y install wget"
		error_detect_depends "apt-get -y install expect"
		error_detect_depends "apt-get -y install net-tools"	
	fi	
}

hello(){
    echo ""
    echo -e "${yellow}frps自助安装脚本${plain}"
	echo "frp is a fast reverse proxy to help you expose a local server behind a NAT or firewall to the Internet."
	echo "项目地址：https://github.com/fatedier/frp"
    echo ""
}

help(){
    hello
    echo "使用方法：bash $0 [-h] [-i] [u]"
    echo ""
    echo "  -h , --help                显示帮助信息"
    echo "  -i , --install             安装frps"
    echo "  -u , --uninstall           卸载frps"
    echo ""
}

confirm(){
    echo -e "${yellow}是否继续执行?(n:取消/y:继续)${plain}"
    read -e -p "(默认:取消): " selection
    [ -z "${selection}" ] && selection="n"
    if [ ${selection} != "y" ]; then
        exit 0
    fi
}

install_frps(){
    for aport in 7000 7500; do
        netstat -a -n -p | grep LISTEN | grep -P "\d+\.\d+\.\d+\.\d+:${aport}\s+" > /dev/null && echo -e "[${red}Error${plain}] required port ${aport} already in use\n" && exit 1
    done
	echo "安装frps 0.40.0版本..."
	install_dependencies
	bit=`uname -m`
	if [[ ${bit} = "x86_64" ]]; then
		download /usr/bin/frps https://github.com/zhouh047/frps-oneclick-install/raw/main/frp/frps_0.40.0_linux_amd64 
	elif [[ ${bit} = "aarch64" ]]; then
		download /usr/bin/frps https://github.com/zhouh047/frps-oneclick-install/raw/main/frp/frps_0.40.0_linux_arm64 
	elif [[ ${bit} = "aarch32" ]]; then	    
		download /usr/bin/frps https://github.com/zhouh047/frps-oneclick-install/raw/main/frp/frps_0.40.0_linux_arm 
	elif [[ ${bit} = "i386" ]]; then
		download /usr/bin/frps https://github.com/zhouh047/frps-oneclick-install/raw/main/frp/frps_0.40.0_linux_386 
	else
        echo -e "${red}脚本暂不支持${bit}内核！${plain}" && exit 1
	fi
	[ ! -f /usr/bin/frps ] && echo -e "[${red}Error${plain}] 安装frps出现问题，请检查." && exit 1
	chmod +x /usr/bin/frps
	download  /etc/systemd/system/frps.service https://raw.githubusercontent.com/zhouh047/frps-oneclick-install/main/frps.service
	[ ! -d /usr/local/etc/frp/ ] && mkdir /usr/local/etc/frp/
	download /usr/local/etc/frp/frps.ini https://raw.githubusercontent.com/zhouh047/frps-oneclick-install/main/frps.ini
	
	temppasswd=`mkpasswd -l 8`
	sed -i "s/dashboard_pwd =/dashboard_pwd = ${temppasswd}/g"  /usr/local/etc/frp/frps.ini
	echo "frps 0.40.0安装成功..."
	[ -f /usr/bin/frps ] && echo -e "${green}installed${plain}: /usr/bin/frps"
	[ -f /etc/systemd/system/frps.service ] && echo -e "${green}installed${plain}: /etc/systemd/system/frps.service"
	[ -f /usr/local/etc/frp/frps.ini ] && echo  -e "${green}installed${plain}: /usr/local/etc/frp/frps.ini"
	
	echo "启动 frps 服务..."
	systemctl start frps || (echo -e "[${red}Error:${plain}] Failed to start frps." && exit 1)
    systemctl enable frps 
	echo -e "${yellow}仪表盘位置：$(get_ip):7500${plain}"
	echo -e "${yellow}dashboard_user:admin${plain}"
	echo -e "${yellow}dashboard_pwd:${temppasswd}${plain}"
}

uninstall_frps(){
    systemctl stop frps
    systemctl disable frps

	rm -f /usr/bin/frps
	rm -f /etc/systemd/system/frps.service
	rm -rf /usr/local/etc/frp/
	
	if [ ! -f /usr/bin/frps ] && [ ! -f /etc/systemd/system/frps.service ] && [ ! -f /usr/local/etc/frp/frps.ini ];then 
		echo -e "${green}卸载成功${plain}"
	else 
	    echo -e "${red}卸载失败${plain}"
	fi
}

if [[ $# = 1 ]];then
    key="$1"
    case $key in
        -i|--install)
		disable_selinux
        install_frps
        ;;
        -u|--uninstall)
		hello
        echo -e "${yellow}正在执行卸载frps.${plain}"
        confirm
        uninstall_frps
        ;;
        -h|--help|*)
        help
        ;;
    esac
else
    help
fi
