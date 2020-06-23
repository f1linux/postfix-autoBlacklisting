#!/bin/bash
#
# Author/Developer: Terrence Houlahan Linux Engineer F1Linux.com
# Linkedin:	https://www.linkedin.com/in/terrencehoulahan

# License: GPL 3.0
# Source:  https://github.com/f1linux/postfix-autoBlacklisting.git
# Version: 03.00.00

cat <<'EOF'> /etc/postfix/access-autoBlacklisting.sh
#!/bin/bash
#
# Author/Developer: Terrence Houlahan Linux Engineer F1Linux.com
# Linkedin:	https://www.linkedin.com/in/terrencehoulahan

# License: GPL 3.0
# Source:  https://github.com/f1linux/postfix-autoBlacklisting.git
# Version: 03.00.00

# OPERATION:
# ----------
# This script PREPENDS offending IP addresses from "/var/log/maillog" to "/etc/postfix/access"
# This ensures restrictive access rules applied before permissive grants.
# Consult README.md file for more granular detail about this script.


# Stop timer from executing Blacklisting script: Existing blacklist in /etc/postfix/access is enforce enforced while the new blacklist rebuilds
systemctl stop Postfix-AutoBlacklisting.timer

# Purge blacklist: Blacklist recreated each script execution capturing both previous offending IPs as well as newest ones present in logs
sed -i '/REJECT$/d' /etc/postfix/access

### Scrape log for different forms of abuse using different tests to identify abuse IPs and squirt each to same central file:
# Enable/Disable any of provided block tests according to your requirements. Adding your own is easy if you use my tests which isolate offending IPs as templates.

# TEST 1: Blacklist Zombie hosts from endlessly squirting spam: These are identified by no PTR record being set for them
#grep "does not resolve to address" /var/log/maillog | awk '{print $14}' | sed 's/://' | sort -u -t . -k 1,1n -k 2,2n -k 3,3n -k 4,4n | sed '/^$/d' >> /etc/postfix/access-blacklist
grep "does not resolve to address" /var/log/maillog | awk '{print $14}' | sed 's/://' >> /etc/postfix/access-blacklist

# TEST 2: Block all subsequent attempts of RBL Blacklisted IPs from talking to our mailserver:
grep "blocked using" /var/log/maillog | sed -rn 's/.*\[(([0-9]{,3}.){4})\].*/\1/gp' >> /etc/postfix/access-blacklist

# TEST 3: Block spammers guessing account names where they know our domain:
# WARNING: this could potentially cause a block where an unintentional misspelling of an mail account name occured.
# Uncomment only if you are happy to accept such a risk:
grep "Recipient address rejected: User unknown in virtual mailbox table" /var/log/maillog | sed -rn 's/.*\[(([0-9]{,3}.){4})\].*/\1/gp' >> /etc/postfix/access-blacklist


# Populate an array with sorted and depuplicated list of offending IPs scraped from maillog using foregoing tests:
readarray arrayIPblacklist < <( cat /etc/postfix/access-blacklist | sort -u -t . -k 1,1n -k 2,2n -k 3,3n -k 4,4n | sed '/^$/d' )

# If "access" is a new empty file then the subsequent "sed" will fail. Any new file will have a zero size so the '-s' test will not equal 'true'.
# So we use negation to test "true" and echo a blank space to file. The subsequent "sed" will now execute.
# If "access" file already has whitelist entry then the 'if' statement does nothing and "sed" which follows executes as expected for a non-empty file:
if [ ! -s /etc/postfix/access ]; then echo "" > /etc/postfix/access; fi

for i in "${arrayIPblacklist[@]}"; do
        # Write list of IPS from array to TOP of "access" file to enforce restrictions BEFORE processing whitelisted "OK" addresses:
        sed -i "1i $i" /etc/postfix/access
        # Append " REJECT" (with a space prepended in front of it) after each of the IPs added to to the "access" file:
        sed -i '1s/$/ REJECT/' /etc/postfix/access
done


# Rebuild the /etc/postfix/access Berkeley DB:
postmap /etc/postfix/access

# After cycle completes and IPs written to /etc/postfix/acces we wipe array which repopulates anew upon next script execution:
unset arrayIPblacklist

systemctl restart Postfix-AutoBlacklisting.service
systemctl start Postfix-AutoBlacklisting.timer

EOF

chmod 744 /etc/postfix/access-autoBlacklisting.sh



cat <<EOF> /etc/systemd/system/Postfix-AutoBlacklisting.service
[Unit]
Description=Captures IPs of hosts from maillog which match tests and prepends them to Postfix access file for Blacklisting.

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
# Execute script every 90 seconds to limits number of times a spammer can connect before being blocked after this interval is reached:
OnUnitInactiveSec=90s
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
