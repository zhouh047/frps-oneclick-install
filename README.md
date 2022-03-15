# frps-oneclick-install

### 脚本用法
```
frps自助安装脚本
frp is a fast reverse proxy to help you expose a local server behind a NAT or firewall to the Internet.
项目地址：https://github.com/fatedier/frp

使用方法：bash frps.sh [-h] [-i] [u]

  -h , --help                显示帮助信息
  -i , --install             安装frps
  -u , --uninstall           卸载frps
```

### 脚本安装的文件
```
installed: /usr/bin/frps
installed: /etc/systemd/system/frps.service
installed: /usr/local/etc/frp/frps.ini
```

### 安装
```
bash <(curl -L https://raw.githubusercontent.com/zhouh047/frps-oneclick-install/main/frps.sh) -i
```

### 卸载
```
bash <(curl -L https://raw.githubusercontent.com/zhouh047/frps-oneclick-install/main/frps.sh) -u
```
