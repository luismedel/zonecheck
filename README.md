# ZoneCheck

DNS testing tool intended to help solving misconfigurations or inconsistencies in DNS servers.

Cloned from the original CVS repo at http://savannah.nongnu.org/projects/zonecheck/

Usage info: https://linux.die.net/man/1/zonecheck

----

## Original README

\# $Id: README,v 1.4 2010/06/15 08:27:22 chabannf Exp $

Documentation about 'ruby' can be found at: http://www.ruby-lang.org/

The DNS is a critical resource for every network application, quite 
important to ensure that a zone or domain name is correctly configured 
in the DNS.

ZoneCheck is intended to help solving misconfigurations or
inconsistencies usually revealed by an increase in the latency of
the application, up to the output of unexpected/inconsistant results.

The ZoneCheck configuration file reflect the policy.
You can let ZoneCheck select the best test set to apply when checking
a zone (for example, a specific profile for reverse delegation when
under .ip6.arpa or .in-addr.arpa, or any mapping declared in ZoneCheck 
configuration file); but on the other hand, you can also force the use 
of a particular profile (for example you could create an RFC compliance 
checking profile).

To install ZoneCheck from sources, please take a look at INSTALL file.
To learn more about different versions of ZoneCheck you can see HISTORY.md
and ChangeLog files.
Details about license and copyrights see COPYING, GPL and CREDITS files. 

More informations are available at http://www.zonecheck.fr.
