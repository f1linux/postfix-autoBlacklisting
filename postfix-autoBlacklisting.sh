#!/bin/bash
#
# Author/Developer: Terrence Houlahan Linux Engineer F1Linux.com
# Linkedin:	https://www.linkedin.com/in/terrencehoulahan

# License: GPL 3.0
# Source:  https://github.com/f1linux/postfix-autoBlacklisting.git
# Version: 02.20.00

cat <<'EOF'> /etc/postfix/access-autoBlacklisting.sh
#!/bin/bash
#
# Author/Developer: Terrence Houlahan Linux Engineer F1Linux.com
# Linkedin:	https://www.linkedin.com/in/terrencehoulahan

# License: GPL 3.0
# Source:  https://github.com/f1linux/postfix-autoBlacklisting.git
# Version: 02.20.00

# OPERATION:
# ----------
# This script prepends IP addresses from /var/log/maillog whose PTR record checks fail and also a static list to the /etc/postfix/access file
# ABOVE whitelisted ("OK") IPs. Thus access restrictions are enforced BEFORE permissive access grants.
# Consult README.md file for more granular detail about this script.

# To negate any potential risk of creating an inconsistent state we stop the timer which executes the autoblacklist service before we modify it:
# While the service is stopped however the existing blcklist in /etc/postfix/access will continue to be enforced.

systemctl stop Postfix-AutoBlacklisting.timer

# Capture IP addresses of senders whose PTR check fails from /var/log/maillog. Data condition the list by stripping out semicolons sorting list and deduplicating repeated IPs:
cat /var/log/maillog | grep "does not resolve to address" | awk '{print $14}'|sed 's/://' | sort -u -t . -k 1,1n -k 2,2n -k 3,3n -k 4,4n | sed '/^$/d' > /etc/postfix/access-AutoBlackList.txt

# Create file containing only IPs already present in "access" list:
grep ".*REJECT" /etc/postfix/access | awk '{print $1}' | sort -u -t . -k 1,1n -k 2,2n -k 3,3n -k 4,4n | sed '/^$/d' > /etc/postfix/active-IP-block-list.txt

# Surpress duplicate IP found in "/etc/postfix/active-IP-block-list.txt" and only print unique IPs from it that do not already exist in /etc/postfix/access-AutoBlackList.txt:
# NOTE: Since we are over-riding "comm"s default output by byte order and sorting lexographically- numbers increase in a series- we use "comm"s switch "--nocheck-order":
# Ref: https://unix.stackexchange.com/a/573503/334294
comm -23 --nocheck-order /etc/postfix/access-AutoBlackList.txt /etc/postfix/active-IP-block-list.txt | sort -u -t . -k 1,1n -k 2,2n -k 3,3n -k 4,4n | sed '/^$/d' > /etc/postfix/updated-IP-block-list.txt

# Populate an array with only NEW IPs found in maillog from "/etc/postfix/updated-IP-block-list.txt" that are NOT already present in "/etc/postfix/access":
readarray arrayIPblacklist < /etc/postfix/updated-IP-block-list.txt

# Loop through array and prepend only NEW IPs not being currently blocked:
for i in "${arrayIPblacklist[@]}"; do
        # Write list of IPS from array to TOP of "access" file to enforce restrictions BEFORE processing whitelisted "OK" addresses:
        sed -i "1i $i" /etc/postfix/access
        # Append " REJECT" (with a space prepended in front of it) after each of the IPs added to to the "access" file:
        sed -i '1s/$/ REJECT/' /etc/postfix/access
done

# Data Cleansing: Ensure "access" list is duplicate-free:
awk -i inplace '!seen[$0]++' /etc/postfix/access

# Rebuild the access Berkeley DB:
postmap /etc/postfix/access

# After cycle completes and IPs have been written to /etc/postfix/acces wipe the list and array which will be repopulated anew when script next executes:
unset arrayIPblacklist
rm /etc/postfix/access-AutoBlackList.txt
rm /etc/postfix/active-IP-block-list.txt
rm /etc/postfix/updated-IP-block-list.txt

systemctl restart Postfix-AutoBlacklisting.service
systemctl start Postfix-AutoBlacklisting.timer

EOF

chmod 744 /etc/postfix/access-autoBlacklisting.sh



cat <<EOF> /etc/systemd/system/Postfix-AutoBlacklisting.service
[Unit]
Description=Captures IPs of hosts from maillog who fails PTR test and auto-adds them to the Postfix access file for Blacklisting.

[Service]
User=root
Group=root
Type=simple
ExecStart=/bin/bash /etc/postfix/access-autoBlacklisting.sh

[Install]
WantedBy=multi-user.target

EOF


chmod 644 /etc/systemd/system/Postfix-AutoBlacklisting.service


cat <<EOF> /etc/systemd/system/Postfix-AutoBlacklisting.timer
[Unit]
Description=Executes /etc/postfix/access-autoBlacklisting.sh

[Timer]
# Execute script every 60 seconds which limits to just 1 minute the number of times a spammer can connect before being blocked:
OnUnitInactiveSec=60s
Unit=Postfix-AutoBlacklisting.service

[Install]
WantedBy=timers.target

EOF

chmod 644 /etc/systemd/system/Postfix-AutoBlacklisting.timer


systemctl daemon-reload
systemctl enable Postfix-AutoBlacklisting.service
systemctl enable Postfix-AutoBlacklisting.timer

systemctl start Postfix-AutoBlacklisting.service
systemctl start Postfix-AutoBlacklisting.timer

echo
echo
systemctl status Postfix-AutoBlacklisting.service

echo
echo
systemctl status Postfix-AutoBlacklisting.timer
