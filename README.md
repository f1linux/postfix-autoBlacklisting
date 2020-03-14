Version: 01.00.00
---

Author/Developer: Terrence Houlahan, Linux Engineer F1Linux.com
---

License: GPL 3.0
---

Date Released: 20200314
---


COMPATIBILITY:
--------------
Build tested and known to be compatible with: RHEL8
Postfix version: rpm -qa|grep postfix -> postfix-3.3.1-9.el8.x86_64

Probably work with any version of Linux and Postfix but has only been tested with RHEL 8 and postfix-3.3.1-9.
Although problems unlikely YMMV if you execute this script on a different combination of Linux & Postfix.

OPERATION:
----------
This script prepends IP addresses from /var/log/maillog whose PTR record checks fail and also a static list to the /etc/postfix/access file
ABOVE whitelisted ("OK") IPs. Thus access restrictions are enforce BEFORE permissive access grants.

How Achieved: IPs from /var/log/maillog and /etc/postfix/access-list-permanent-blacklist.txt are written to /etc/postfix/access-AutoBlackList.txt.
The comprehensive list of IPs to blacklist in /etc/postfix/access-AutoBlackList.txt are read into the array "arrayIPblacklist".
Finally the array is processed in a loop prepending the IPs and the word " REJECT" ABOVE whitelisted IPs in /etc/postfix/access.
Script finishes by deleting file "/etc/postfix/access-AutoBlackList.txt" and clearing array.

Housekeeping: To preclude a gazillion IPs being loaded into array each time script executes the dynamic list created from /var/log/maillog is destroyed
and the array unset after the IPs are added to /etc/postfix/access. If the same offender is present the next time script executes their ban will continue
until they are no longer found in /var/log/maillog. So IPs only remain blacklisted until they stop trying to connect.

Frequency:  Although script can be executed manually ideally it should be executed from a SystemD Timer at some interval you determine reasonable.
Default execution is every 90 seconds. This limits attempts of a dodgy mailserver to make connections to just that small window befoore being blocked.

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
	
