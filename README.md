Author/Developer: Terrence Houlahan Linux Engineer F1Linux.com
Linkedin:	https://www.linkedin.com/in/terrencehoulahan
License: GPL 3.0

Source:  https://github.com/f1linux/postfix-autoBlacklisting.git
Version: 03.20.00
----

COMPATIBILITY:
--
Build tested on a busy mailserver which hosts many domains- my own. _I eat my own dog food_...

- Linux Version: RHEL8 (with SELinux enforcing)
- Postfix Version: rpm -qa|grep postfix -> postfix-3.3.1-9.el8.x86_64

These scripts would **probably** work with most modern versions of Linux & Postfix but it has only been tested on above and so consistency
of results on different configs cannot be guaranteed.

Minimum Requirements:
--
A Linux OS employing **SystemD** for management of services for the Blacklisting script to fire using the SystemD Timer.
You could tinker with the script to execute using a cronjob in lieu but I would strongly advise running postfix on a modern Linux OS version
rather hacking to get EOL versions of Linux still using SysVinit to work with this.

INSTALLATION:
--
Step 1: 
	cd ~

Step 2: Clone repo into your home directory on the Postfix server:

- Master Branch: Production Use
    git clone https://github.com/f1linux/postfix-autoBlacklisting.git
	
- Develop Branch: If you want to test the latest & greatest between tagged official Master releases fill your boots: 
    git clone --single-branch --branch develop https://github.com/f1linux/postfix-autoBlacklisting.git

Step 3: Drop into the cloned folder:
	cd postfix-autoBlacklisting

Step 4: Execute the script:
	./postfix-autoBlacklisting.sh

Step 5: Might want too change the frequency the SystemD timer updates the blacklist to a longer or shorter period than the default.


UNINSTALL:
--
An script to uninstall "***postfix-autoBlacklisting***" is provided for complete removal of the blacklisting script, SystemD Service & Timer and any dependent files:
To uninstall "postfix-autoBlacklisting":

Step 1:
	cd /etc/postfix/

Step 2:
	./postfix-autoBlacklisting-UNINSTALL.sh	

**NOTE**: The uninstall script does **NOT** remove an existing blacklisted IPs to ensure no unique local data is wiped.
To remove **ALL** Blacklisted IPs from /etc/postfix/access execute:
			
	sed -i '/.*REJECT/d' /etc/postfix/access
	

UPGRADING:
--
Follow the instructions for an UNINSTALL and then an INSTALLATION as above.


IPv6:
--
The tests I have designed capture addresses of both IPv4 & IPv6 abusers.
HOWEVER: Almost all the abuse in "/var/log/maillog" I had to work with was exclusively IPv4.
So although the IPv4 testing has been fairly comprehensive my ability to validate the IPv6 tests has been somewhat limited.
That is not to say the quality of the IPv6 tests are low or poor only that I  am anal when it comes to testing and cannot give iron-clad assurances on them.
If you find any IPv6- the worst being a failure to match and successfully blacklist an IP- please open an issue on this Github repo and I will resolve it.


OPERATION:
--
This repo creates a blacklisting script with a SystemD Service and Timer to execute is. Offending IPs are scraped from "/var/log/maillog" and
written to /etc/postfix/access.  So any Postfix directive whose type is "table" and reads this DB will be able to access the blacklist.
The script therefore would have no effect if your "main.cf" config does not have any directive reading the "_access_" db.

The blacklisting script prepends IP addresses from "/var/log/maillog" which matches one or more of a series of tests ABOVE any whitelisted ("OK") IPs in "/etc/postfix/access".
Thus access restrictions are enforced BEFORE permissive access grants.

A SystemD timer executes "/etc/postfix/access-autoBlacklisting.sh" at a specified interval which captures offending IPs from maillog using a series of tests and
squirts these IPS into a sorted deduplicated array which is then written to "/etc/postfix/access" with the word "***REJECT***" after each IP.


PRECEDENCE of RESTRICTIONS: IMPORTANT
--
Postfix reads restrictions from left to right until until a match is achieved and then stops.
So in order to achieve maximum effectiveness you ideally want to move any restriction specifying the "/etc/postfix/access" map as far to the left in a series of directives.
If we can just reject from a blacklist immediately this stop postfix from checking RBLs and other more expensive tests. Indeed if an RBL test happens before the
"/etc/postfix/access" blacklist is consulted a spammer will continue to connect and have their IP checked endlessly against an RBL. This is why you want the blacklist
to the left of a series of restrictive tests: most effective and least expensive should be executed first.

Examples:

Maybe in a series of restrictions we place the blacklist- any directive which reads "***hash:/etc/postfix/access***"- farthest to the left. Just block the idiots immediately:
    smtpd_client_restrictions = check_client_access hash:/etc/postfix/access, permit_sasl_authenticated, permit_mynetworks, reject_invalid_hostname, reject_non_fqdn_sender, reject_unknown_sender_domain, reject_unauth_destination, reject_rbl_client bl.spamcop.net, reject_rhsbl_reverse_client bl.spamcop.net, reject_rhsbl_helo bl.spamcop.net, reject_rhsbl_sender bl.spamcop.net

    smtpd_recipient_restrictions = check_client_access hash:/etc/postfix/access, permit_sasl_authenticated, permit_mynetworks, reject_unauth_destination, check_policy_service unix:private/policyd-spf, check_policy_service unix:private/policyd-spf

However we could alternatively waive-through trusted users by placing "***permit_mynetworks***" to the left of our blacklist (which is still the 2nd directive to be enforced).
    smtpd_sender_restrictions = permit_mynetworks, check_sender_access hash:/etc/postfix/access, reject_invalid_hostname, reject_non_fqdn_sender, reject_unknown_sender_domain

BTW the ordering of directives above is for example purposes. It is suggested significant testing be done to validate the effect of ordering in respect to unintended consequences.
Indeed some of the directives  might not even be relevant to your configuration. Do not just copy-n-paste them into "/etc/postfix/main.cf" ;-)

    Refs: http://www.postfix.org/SMTPD_ACCESS_README.html
          http://www.postfix.org/access.5.html

DEFAULT FREQUENCY:
--
The blacklisting script executes every 90 seconds via a SystemD timer. Why? Seemed a reasonable interval to catch spammers to limit abuse before being blacklisted.
Feel free to modify this value to any other figure you feel more appropriate.
Be aware though that if you bump-up interval of script execution up to 300 seconds an abuser can hammer you that much longer before being blocked.


HOUSEKEEPING:
--
Basically the script that hoovers abuser IPs from maillog wipes them all from "/etc/postfix/access" on each execution and rewrites all previous IPs plus new ones.
So as long as an offending IP remains in "/var/log/maillog" it will continue to be blocked. One kink in this logic: ALL offending IPs are cleansed immediately following log rotation.
This is not all bad however. If an offending IP has stopped abusing at some point BEFORE log rotation thereafter it drops-off block list stopping "REJECT" list from growing infinitely.
The block list will capture all the continuously offending IPs by next script execution. There needs to be a mechanism to drop IPs of hosts which stop abusing. Seemed the best balance.


UNBLOCKING A BLACKLISTED IP:
--
Once an IP has matched a test identifying abuse in /var/log/maillog the IP will continue to remain blocked as long as that test remains true.

- Method 1: Rotate /var/log/maillog so you have a clean log. Note however that all currently blacklisted IPs will be cleared along with IP being unblocked. Blacklist repopulates quickly however
- Method 2: Delete every occurence of the IP matching the test that caused it to be blacklisted from /var/log/maillog


SCRIPT EXECUTION TIME:
--
If interested in determining how long "/etc/postfix/access-autoBlacklisting.sh" is taking to complete execution- maybe to understand overhead on your mailserver
then review "/var/log/messages" and find the entries for our systemd service. "starting" is beginning of execution and "started" is completion.
This confused me but testing reveals the lated is really the completion of "/etc/postfix/access-autoBlacklisting.sh" fired-off by our systemd service.


CONCLUSION:
--
Hope you find this tool useful for reducing abuse of your mailserver. We are all better off if everybody tightens-up their mailserver against abuse.

	Terrence Houlahan Linux Engineer F1Linux.com