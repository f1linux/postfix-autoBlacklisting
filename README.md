Version: 02.10.00
---

Author/Developer: Terrence Houlahan, Linux Engineer F1Linux.com
---

License: GPL 3.0
---

Date Released: 20200314
---


COMPATIBILITY:
--
Build tested and known to be compatible with: RHEL8
Postfix version: rpm -qa|grep postfix -> postfix-3.3.1-9.el8.x86_64

Probably work with any version of Linux and Postfix but has only been tested with RHEL 8 and postfix-3.3.1-9.
Although problems unlikely YMMV if you execute this script on a different combination of Linux & Postfix.

OPERATION:
--
This script prepends IP addresses from /var/log/maillog whose PTR record checks fail and also a static list to the /etc/postfix/access file
ABOVE whitelisted ("OK") IPs. Thus access restrictions are enforce BEFORE permissive access grants.

A SystemD timer executes "/etc/postfix/access-autoBlacklisting.sh" every 60 seconds which captures offending IPs from maillog and sorts these
into a deduplicated list named "access-AutoBlackList.txt".  Next "/etc/postfix/access" iis scanned again for IPs currently being blocked and
these are sorted into the list "active-IP-block-list.txt".  Finally the two lists are compared using "comm" and only NEW IPs captured since the
script previously executed are written to the file "/etc/postfix/updated-IP-block-list.txt".

It is this last file "/etc/postfix/updated-IP-block-list.txt" that is read into an array which is looped through prepending NEW IPs to '/etc/postfix/access".
After the "access" list is updated with any new IPs, the Berekely DB is recreated by executing "postmap /etc/postfix/access". Postfix is NOT restarted.
After the script executes, the array is unset and all three files deleted.  When script next executes all these files will be recreated anew.

Default Frequency:
--
Script executes every 60 seconds via a SystemD timer. Why 60 seconds? Seemed a reasonable interval to catch spammers. Their window is just 60 seconds for
nonsense before being blocked.

Housekeeping:
--
Presently there is none: Once an IP is blocked it stays blocked. Depending on how active spammers are connecting to your mailserver you may need to purge
the /etc/postfix/access list daily, weekly, monthly or yearly. I'll revisit this at some point and code the balance between an infinite block list and
potentially letting the same troublemakers through to start making malicious nonsense potentially in the future.


Detailed guidance on operation of /etc/postfix/acces:
      http://www.postfix.org/access.5.html


EXECUTION:
----------

Step 1: cd ~

Step 2: Clone repo into your home directory on the Postfix server.
	git clone https://github.com/f1linux/postfix-autoBlacklisting.git

Step 3: Drop into the cloned folder:
	cd postfix-autoBlacklisting

Step 4: Execute the script:
	./postfix-autoBlacklisting.sh

Step 5: Might want too change the frequency the SystemD timer updates the blacklist to a longer or shorter period than the default.
	
