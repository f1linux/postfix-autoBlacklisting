#!/bin/bash
#
# Version 01.00.00
# Author/Developer: Terrence Houlahan, Linux Engineer F1Linux.com
# Linkedin:	https://www.linkedin.com/in/terrencehoulahan

# License: GPL 3.0
# Source:  https://github.com/f1linux/postfix-autoBlacklisting.git
# Version: 01.00.00


cat <<'EOF'> /etc/postfix/access-autoBlacklisting.sh
#!/bin/bash

# OPERATION:
# ----------
# This script prepends IP addresses from /var/log/maillog whose PTR record checks fail and also a static list to the /etc/postfix/access file
# ABOVE whitelisted ("OK") IPs. Thus access restrictions are enforce BEFORE permissive access grants.
# Consult the README.md file for more granular detail about this script.

# Backup /etc/postfix/access before modifying it.
# This backup will be overwritten with the last copy of the file each time script executes:

cp -p /etc/postfix/access /etc/postfix/access.BAK

# Create file to record IPs to be subjected to PERMANENT blacklisting block:
if [ ! -f /etc/postfix/access-list-permanent-blacklist.txt ]; then
        touch /etc/postfix/access-list-permanent-blacklist.txt
        chmod 644 /etc/postfix/access-list-permanent-blacklist.txt
fi

# Clear all existing blacklisted IPs:
sed -i '/.*REJECT/d' /etc/postfix/access

# Capture IP addresses of senders whose PTR check fails from /var/log/maillog:
cat /var/log/maillog | grep "does not resolve to address" | awk '{print $14}'|sed 's/://' | sort -n | uniq -u >> /etc/postfix/access-AutoBlackList.txt

# Add IPs from file of IPs subject to PERMANENT Blacklisting to same list of IPs captured from the maillog:
cat /etc/postfix/access-list-permanent-blacklist.txt | sort -n | uniq -u >> /etc/postfix/access-AutoBlackList.txt

# Read combined list of IPs from the dynamic and permanent lists which has had all duplicates stripped-out:
readarray arrayIPblacklist < /etc/postfix/access-AutoBlackList.txt

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
# Execute script every 90 seconds after it previously ran limiting to 90 seconds the attempted connections a bad host can attempt:
OnUnitInactiveSec=90s
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

