# ZCTEST 1.0
# $Id: generic.rb,v 1.33 2011/03/08 14:07:26 kmkaplan Exp $

# 
# CONTACT     : zonecheck@nic.fr
# AUTHOR      : Stephane D'Alu <sdalu@nic.fr>
#
# CREATED     : 2002/08/02 13:58:17
# REVISION    : $Revision: 1.33 $ 
# DATE        : $Date: 2011/03/08 14:07:26 $
#
# CONTRIBUTORS: (see also CREDITS file)
#
#
# LICENSE     : GPL v3
# COPYRIGHT   : AFNIC (c) 2003
#
# This file is part of ZoneCheck.
#
# ZoneCheck is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
# 
# ZoneCheck is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with ZoneCheck; if not, write to the Free Software Foundation,
# Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
#

require 'framework'

module CheckGeneric
    ##
    ## Check syntax validity of the domain name
    ##
    class DomainNameSyntax < Test
	with_msgcat 'test/generic.%s'

	#-- Checks --------------------------------------------------
	# DESC: A domainname should only contains A-Z a-Z 0-9 '-' '.'
	def chk_dn_sntx
	    @domain.name.to_s =~ /^[A-Za-z0-9\-\.]*$/
	end

	# DESC: A domainname should not countain a double hyphen unless it is an ACE prefix
	def chk_dn_dbl_hyph
	    name = @domain.name.to_s.gsub(/(xn--)/,'')
	    (!(name =~ /--/))
	end

	# DESC: A domainname should not start or end with an hyphen
	def chk_dn_orp_hyph
	    ! (@domain.name.to_s =~ /(^|\.)-|-(\.|$)/)
	end
    end



    ##
    ## Check basic absurdity with the nameserver IP addresses
    ##
    class ServerAddress < Test
	with_msgcat 'test/generic.%s'

	#-- Initialization ------------------------------------------
	def initialize(*args)
	    super(*args)
	    @cache.create(:ip, :by_subnet)
	end

	#-- Shortcuts -----------------------------------------------
	def ip
	    @cache.use(:ip) {
		ip = @domain.ns.collect { |ns, ips| ips }
		ip.flatten!
		ip
	    }
	end

	def ns_from_ip(ip)
	    @domain.ns.each { |ns, ips|
		return ns if ips.include?(ip)
	    }
	    nil
	end

	def by_subnet
	    @cache.use(:by_subnet) {
		nethosts = {}
		ip.each { |i| 
		    net = case i                     # decide of subnet size:
			  when Dnsruby::IPv4 then prefix_of(i,28) # /28 for IPv4
			  when Dnsruby::IPv6 then prefix_of(i,64) # /64 for IPv6
			  end
		    nethosts[net] = [ ] unless nethosts.has_key?(net)
		    nethosts[net] << i
		}
		nethosts
	    }
	end

	#-- Checks --------------------------------------------------
	# DESC: Addresses should be distincts
	def chk_ip_distinct
	    # Ok all addresses are distincts
	    return true if ip == ip.uniq
	    
	    # Create data for failure handling
	    hosts = {}
	    @domain.ns.each { |ns, ips|
		ips.each { |i| 
		    hosts[i.to_s] = [ ] unless hosts.has_key?(i.to_s)
		    hosts[i.to_s] << ns.to_s
		}
	    }
	    hosts.delete_if { |k, v| v.size < 2 }
	    hosts.each { |k, v|	# Got at least 1 entry as ip != ip.uniq
		return { 'ip' => k.to_s, 'ns' => v.join(', ').to_s }
	    }
	end

	# DESC: Addresses should avoid belonging to the same network
	def chk_ip_same_net
	    # Only keep list of hosts on same subnet
	    same_net = by_subnet.dup.delete_if { |k, v| v.size < 2 }
		
	    # Ok all hosts are on different subnets
	    return true if same_net.empty?

	    # Create output data for failure
	    subnetlist = []
	    same_net.each { |k, v|
		hlist   = (v.collect { |i| ns = ns_from_ip(i) }).join(', ')
		prefix = case k
			 when Dnsruby::IPv4 then 28
			 when Dnsruby::IPv6 then 64
			 end
		subnetlist << "#{k}/#{prefix} (#{hlist})"
	    }
	    return { 'subnets' => subnetlist.join(', ').to_s }
	end

	# DESC: Addresses should avoid belonging ALL to the same network
	# WARN: Test is wrong in case of IPv4 and IPv6
	def chk_ip_all_same_net
	    # Ok not all hosts are on the same subnet
	    return true unless ((by_subnet.size           == 1) && 
				(by_subnet.values[0].size >  1))

	    # Create output data for failure
	    subnet = by_subnet.keys[0]
	    prefix = case subnet
		     when Dnsruby::IPv4 then 28
		     when Dnsruby::IPv6 then 64
		     end
	    return { 'subnet' => "#{subnet.to_s}/#{prefix.to_s}" }
	end

	# DESC: Addresses should avoid belonging ALL to the same AS
	def chk_all_same_asn
    asn = ip.collect { |addr|
      name = ''
      case addr
        when Dnsruby::IPv4
          name = ('%d.%d.%d.%d' % addr.address.unpack('CCCC').reverse) +
        '.asn.routeviews.org.'
        when Dnsruby::IPv6
          name = addr.address.unpack("H32")[0].split(//).reverse.join(".") + '.asn.routeviews.org.'
        else
          raise ArgumentError, 'Argument should be an address'
      end
      aname = Dnsruby::Name::create(name)
      begin
        txtres = @cm[nil].txt(aname)
        (txtres[0].nil?) ? nil : (txtres[0].strings[0])
      rescue Dnsruby::NXDomain
        nil
      end
    }
    asn.uniq!
    asn.size > 1 ? true : { 'asn' => asn[0].to_s }
	end
    end


    ##
    ## Check for nameserver!
    ##
    class NameServers < Test
	with_msgcat 'test/generic.%s'

	#-- Checks --------------------------------------------------
	# DESC: A domain should have a nameserver!
	def chk_one_ns
	    @domain.ns.length >= 1
	end

	# DESC: A domain should have at least 2 nameservers
	def chk_several_ns
	    @domain.ns.length >= 2
	end
    end


    ##
    ##
    ##
    class Delegation < Test
	with_msgcat 'test/generic.%s'

	#-- Initialisation ------------------------------------------
	def initialize(*args)
	    super(*args)
	    @querysize = const('delegation_query_size').to_i
	end

	#-- Checks --------------------------------------------------
	def chk_delegation_udp512
	  # TODO
	    dummyttl	= 3600
	    msg   = Dnsruby::Message::new(".", "NS")
	    @domain.ns.each { |ns, ips|
        rr = Dnsruby::RR::IN::NS::new(ns)
        rr.type = "NS"
        rr.klass = "IN"
        rr.name = @domain.name
        rr.ttl = dummyttl
        msg.add_authority(rr)
	    }
	    
	    excess = (msg.encode.size + @querysize-1) - 512

	    return true if excess <= 0
	    { 'excess' => excess.to_s }
	end

	def chk_delegation_udp512_additional	  
    dummyttl = 3600
    msg   = Dnsruby::Message::new(".", "NS")
    @domain.ns.each { |ns, ips|
      rr = Dnsruby::RR::IN::NS::new(ns)
      rr.type = "NS"
      rr.klass = "IN"
      rr.ttl = dummyttl
      rr.name = @domain.name
      msg.add_answer(rr)
      if ns == @domain.name || ns.subdomain_of?(@domain.name)
           ips.each { |ip|
             
             if ip.class == Dnsruby::IPv4
              rr2 = Dnsruby::RR::IN::A::new(ip)
              rr2.name = ns
              rr2.type = "A"
             else
               if ip.class == Dnsruby::IPv6
                 rr2 = Dnsruby::RR::IN::AAAA::new(ip)
                 rr2.name = ns
                 rr2.type = "AAAA"
               else
                 rr2 = Dnsruby::RR::IN::A::new(ip)
                 rr2.name = ns
                 rr2.type = "A"
               end
             end
             rr2.klass = "IN"
             rr2.ttl = dummyttl
         msg.add_additional(rr2) }
       end
    }
    rawmsg = msg.encode    
    excess = (rawmsg.size + @querysize-1) - 512
	  
    return true if excess <= 0
    { 'excess' => excess.to_s }
	end
    end
end
