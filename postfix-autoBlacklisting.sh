#!/bin/bash
#
# Author/Developer: Terrence Houlahan, Linux Engineer F1Linux.com
# Linkedin:	https://www.linkedin.com/in/terrencehoulahan

# License: GPL 3.0
# Source:  https://github.com/f1linux/postfix-autoBlacklisting.git
# Version: 02.10.01

cat <<'EOF'> /etc/postfix/access-autoBlacklisting.sh
#!/bin/bash

# OPERATION:
# ----------
# This script prepends IP addresses from /var/log/maillog whose PTR record checks fail and also a static list to the /etc/postfix/access file
# ABOVE whitelisted ("OK") IPs. Thus access restrictions are enforced BEFORE permissive access grants.
# Consult README.md file for more granular detail about this script.


# Capture IP addresses of senders whose PTR check fails from /var/log/maillog. Data condition the list by stripping out semicolons sorting list and deduplicating repeated IPs:
cat /var/log/maillog | grep "does not resolve to address" | awk '{print $14}'|sed 's/://' | sort -t . -k 1,1n -k 2,2n -k 3,3n -k 4,4n | uniq -u | sed '/^$/d' >> /etc/postfix/access-AutoBlackList.txt

# Create file containing only IPsalready present in "access" list:
grep ".*REJECT" /etc/postfix/access | awk '{print $1}' | sort -t . -k 1,1n -k 2,2n -k 3,3n -k 4,4n | uniq | sed '/^$/d' >> /etc/postfix/active-IP-block-list.txt

# Strip-out IPs from 2nd file "active-IP-block-list.txt" so only NEW offenders will be added to /etc/postfix/access on each subsequent execution:
comm -3 /etc/postfix/access-AutoBlackList.txt /etc/postfix/active-IP-block-list.txt | sort -t . -k 1,1n -k 2,2n -k 3,3n -k 4,4n | uniq | sed '/^$/d' >> /etc/postfix/updated-IP-block-list.txt

# Read list only containing the NEW IPs not already present in /etc/postfix/access into an array:
readarray arrayIPblacklist < /etc/postfix/updated-IP-block-list.txt

# Loop through the array and prepend ONLY new IPs not being currently blocked:
for i in "${arrayIPblacklist[@]}"; do
        # Write list of IPS from array to TOP of "access" file to enforce restrictions BEFORE processing whitelisted "OK" addresses:
        sed -i "1i $i" /etc/postfix/access
        # Append " REJECT" (with a space prepended in front of it) after each of the IPs added to to the "access" file:
        sed -i '1s/$/ REJECT/' /etc/postfix/access
done

# Rebuild the access Berkeley DB:
postmap /etc/postfix/access

# After cycle completes and IPs have been written to /etc/postfix/acces wipe the list and array which will be repopulated anew when script next executes:
unset arrayIPblacklist
rm /etc/postfix/access-AutoBlackList.txt
rm /etc/postfix/active-IP-block-list.txt
rm /etc/postfix/updated-IP-block-list.txt
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

wait 5
echo
echo
systemctl status Postfix-AutoBlacklisting.service

echo
echo
systemctl status Postfix-AutoBlacklisting.timer

