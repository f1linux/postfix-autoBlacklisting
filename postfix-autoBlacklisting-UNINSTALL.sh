#!/bin/bash
#
# Author/Developer: Terrence Houlahan Linux Engineer F1Linux.com
# Linkedin:	https://www.linkedin.com/in/terrencehoulahan

# License: GPL 3.0
# Source:  https://github.com/f1linux/postfix-autoBlacklisting.git
# Version: 02.20.00

cat<<'EOF'> /etc/postfix/postfix-autoBlacklisting-UNINSTALL.sh
#!/bin/bash
#
# Author/Developer: Terrence Houlahan Linux Engineer F1Linux.com
# Linkedin:	https://www.linkedin.com/in/terrencehoulahan

# License: GPL 3.0
# Source:  https://github.com/f1linux/postfix-autoBlacklisting.git
# Version: 02.20.00

systemctl stop Postfix-AutoBlacklisting.service
systemctl stop Postfix-AutoBlacklisting.timer

systemctl disable Postfix-AutoBlacklisting.service
systemctl disable Postfix-AutoBlacklisting.timer

systemctl daemon-reload

rm /etc/systemd/system/Postfix-AutoBlacklisting.service
rm /etc/systemd/system/Postfix-AutoBlacklisting.timer
rm /etc/postfix/access-autoBlacklisting.sh

unset arrayIPblacklist

echo
echo 'Delete any scratch files used to build the block list:'
if [ -f /etc/postfix/access-AutoBlackList.txt ]; then
	rm /etc/postfix/access-AutoBlackList.txt
	echo 'Deleted/etc/postfix/access-AutoBlackList.txt'
fi

if [ -f /etc/postfix/active-IP-block-list.txt ]; then
	rm /etc/postfix/active-IP-block-list.txt
	echo 'Deleted /etc/postfix/active-IP-block-list.txt'
fi

if [ -f /etc/postfix/updated-IP-block-list.txt ]; then
	rm /etc/postfix/updated-IP-block-list.txt
	echo 'Deleted /etc/postfix/updated-IP-block-list.txt'
fi

echo
echo 'Current IPs being blocked in /etc/postfix/access'
echo 'Have NOT been cleared. If you wish to clear them.'
echo 'Execute the below command to clear them en masse:'
echo
echo "sed -i '/.*REJECT/d' /etc/postfix/access"
echo

echo
echo 'postfix-autoBlacklisting-UNINSTALL.sh Completed'
echoecho
EOF

chmod 744 /etc/postfix/postfix-autoBlacklisting-UNINSTALL.sh