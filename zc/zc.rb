#!/usr/local/bin/ruby
# $Id: zc.rb,v 1.127 2010/06/29 12:08:35 chabannf Exp $

# 
# CONTACT     : zonecheck@nic.fr
# AUTHOR      : Stephane D'Alu <sdalu@nic.fr>
#
# CREATED     : 2002/07/18 10:29:53
# REVISION    : $Revision: 1.127 $ 
# DATE        : $Date: 2010/06/29 12:08:35 $
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


## !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
##
## WARN: when editing this file on installed ZoneCheck, you should
##       keep in mind that some ZoneCheck variant (cgi, ...) are 
##       more or less strongly connected with this file by:
##       - a copy     : only THIS file will be modified
##       - a hardlink : depending of your editor behaviour when
##                      saving the file, all the files will hold
##                      the modification OR only this file will.
##       - a symlink  : no problem should occured (except if on Windows)
##
## !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!


## --> CUSTOMIZATION <-- #############################################
# 
# You shouldn't really need to change these values:
#  - This is normally automatically done when performing a: make install
#  - Setting the environment variable ZC_INSTALL_PATH should be enough
#     for testing the code
#

## Installation path
ZC_INSTALL_PATH		= (ENV['ZC_INSTALL_PATH'] || (ENV['HOME'] || '/homes/sdalu') + '/Repository/zonecheck').dup.untaint

## Directories
ZC_DIR			= "#{ZC_INSTALL_PATH}/zc"
ZC_LIB			= "#{ZC_INSTALL_PATH}/lib"

ZC_CONFIG_DIR		= ENV['ZC_CONFIG_DIR']       || "#{ZC_INSTALL_PATH}/etc/zonecheck"
ZC_LOCALIZATION_DIR	= ENV['ZC_LOCALIZATION_DIR'] || "#{ZC_INSTALL_PATH}/locale"
ZC_TEST_DIR		= ENV['ZC_TEST_DIR']         || "#{ZC_INSTALL_PATH}/test"

## Configuration
ZC_CONFIG_FILE		= ENV['ZC_CONFIG_FILE'] || 'zc.conf'

## Lang
ZC_LANG_FILE		= 'zc.%s'
ZC_LANG_DEFAULT		= 'en'		# can have an enconding: en.ascii

## Message catalog fallback
ZC_MSGCAT_FALLBACK	= 'en'		# don't specifie an encoding here

## Input methods
ZC_DEFAULT_INPUT	= 'cli'

ZC_CGI_ENV_KEYS		= [ 'GATEWAY_INTERFACE', 'SERVER_ADDR' ]
ZC_CGI_EXT		= 'cgi'

## Publisher
ZC_HTML_PATH		= ENV['ZC_HTML_PATH'] || "#{ZC_INSTALL_PATH}/www"


## Contact / Details
ZC_COPYRIGHT		= 'AFNIC (c) 2003'
ZC_CONTACT		= 'ZoneCheck <zonecheck@nic.fr>'
ZC_MAINTAINER		= 'Stephane D\'Alu <sdalu@nic.fr>'

## Internal
ZC_XML_PARSER		= ENV['ZC_XML_PARSER'] 
ZC_IP_STACK		= ENV['ZC_IP_STACK'] || '46'

## --> END OF CUSTOMIZATION <-- ######################################


#
# Identification
#
ZC_CVS_NAME	= %q$Name:  $
ZC_NAME		= 'ZoneCheck'
ZC_VERSION	= (Proc::new { 
		       n = ZC_CVS_NAME.split[1]
		       n = /^ZC-(.*)/.match(n) unless n.nil?
		       n = n[1]                unless n.nil?
		       n = n.gsub(/_/, '.')    unless n.nil?
		       
		       n || '<unreleased>'
		   }).call
PROGNAME	= File.basename($0)


#
# Constants
#
EXIT_OK		=  0	# Everything went fine, no fatal error, domain ok
EXIT_FAILED	=  1	# The program completed but the result is negative
EXIT_TIMEOUT	=  2	# The program completed but the result is negative
			#  due to timeout.
EXIT_ABORTED	=  3	# The user aborted the program before completion
EXIT_ERROR      =  4	# An error unrelated to the result occured
EXIT_USAGE	=  9	# The user didn't bother reading the man page


#
# Sanity check
#
m = /^(\d+)\.(\d+)\./.match(RUBY_VERSION)
if (m[1].to_i <= 1) && (m[2].to_i < 8)
    $stderr.puts "#{PROGNAME}: ruby version 1.8.0 at least is required."
    exit EXIT_ERROR
end


#
# Run at safe level 1
#  A greater safe level is unfortunately not possible due to some 
#  low level operations in the Dnsruby library
#
$SAFE = 0	# REXML BUG


#
# Ensure '.' is not one of the possible path (too much trouble)
# Add zonecheck directories to ruby path
#
$LOAD_PATH.delete_if { |path| path == '.' }
$LOAD_PATH << ZC_DIR << ZC_LIB


#
# Version / Name / Contact
#
$zc_version	||= ZC_VERSION
$zc_name	||= ZC_NAME
$zc_contact	||= ZC_CONTACT

#
# Config directory
# 
$zc_config_dir	||= ZC_CONFIG_DIR
$zc_config_file	||= ZC_CONFIG_FILE

#
# Custom
#
$zc_custom	||= 'zc-custom'

#
# Internal
#
$zc_xml_parser	||= ZC_XML_PARSER

# Resolver configuration
$rootserver_hintfile	= "#{$zc_config_dir}/rootservers"


#
# Requierement
#
# Standard Ruby libraries
require 'socket'

# Modification to standard/core ruby classes
require 'ext/array'
require 'ext/file'
require 'ext/myxml'


# ZoneCheck component
require 'locale'
require 'msgcat'
require 'console'
require 'zonecheck'
require 'dbg'


#
# Debugger object
#  (earlier initialization, can also be set via input interface)
#
$dbg       = ZoneCheck::DBG::new
$dbg.level = ENV['ZC_DEBUG'] if ENV['ZC_DEBUG']


# External libraries
begin 
  require 'dnsruby'
rescue LoadError => e
  begin 
    require 'rubygems'
  rescue LoadError => e
    $dbg.msg(ZoneCheck::DBG::INIT, "Unable to require rubygems (#{e})")
    $stderr.puts "ERROR: You have to install Dnsruby in order to execute ZoneCheck"
    exit EXIT_ERROR
  end
  begin 
    require 'dnsruby'
  rescue LoadError => e
    $dbg.msg(ZoneCheck::DBG::INIT, "Unable to require dnsruby (#{e})")
    $stderr.puts "ERROR: You have to install Dnsruby in order to execute ZoneCheck"
    exit EXIT_ERROR
  end
end

if Dnsruby.version < 1.47
  $dbg.msg(ZoneCheck::DBG::INIT, "Unable to require dnsruby (#{e})")
  $stderr.puts "ERROR: You have to install at least Dnsruby 1.47 in order to execute ZoneCheck"
  exit EXIT_ERROR
end

include ZoneCheck

#
# XML parser
#
ENV['XML_CATALOG_FILES'] = "#{ZC_DIR}/data/catalog.xml"

$dbg.msg(DBG::INIT) {
    shrinked_path = File.shrink_path(ENV['XML_CATALOG_FILES'], ':')
    "Using XML_CATALOG_FILES=#{shrinked_path}"
}
$dbg.msg(DBG::INIT) { "Using XML parser: #{MyXML::Implementation}" }



#
# IPv4/IPv6 stack detection
#  WARN: doesn't implies that we have also the connectivity
#
$ipv4_stack = !(ZC_IP_STACK =~ /4/).nil?
$ipv6_stack = !(ZC_IP_STACK =~ /6/).nil?
$ipv4_stack = $ipv6_stack = true if !$ipv4_stack && !$ipv6_stack

$ipv4_stack &&= begin
		    UDPSocket::new(Socket::AF_INET).close
		    true
		rescue NameError,      # if Socket::AF_INET doesn't exist
			SystemCallError # for the Errno::EAFNOSUPPORT error
		    false
		end
$ipv6_stack &&= begin
		    UDPSocket::new(Socket::AF_INET6).close
		    true
		rescue NameError,      # if Socket::AF_INET6 doesn't exist
			SystemCallError # for the Errno::EAFNOSUPPORT error
		    false
		end


#
# Internationalisation
#  WARN: default locale is mandatory as no human messages are
#        present in the code (except for debugging purpose)
#
begin
    $supported_languages = ["en","fr"]
  
    # Initialize locale
    $locale = ZoneCheck::Locale::new
    $locale.lang = ZC_LANG_DEFAULT if $locale.lang.nil?
    
    # Initialize the console
    $console = Console::new
    
    # Initialize the message catalog
    $mc = MsgCat::new(ZC_LOCALIZATION_DIR, ZC_MSGCAT_FALLBACK)

    # Add watcher for notification of locale changes
    #  ... and force update
    $locale.watch('lang', proc { 
		      $mc.language = $locale.language
		      $mc.country  = $locale.country
		      $mc.reload } )
    $locale.watch('encoding', proc { 
		      $console.encoding = $locale.encoding } )
    $locale.notify('lang', 'encoding')

    # Read msgcat
    $mc.read(ZC_LANG_FILE)

rescue => e
    raise if $dbg.enabled?(DBG::DONT_RESCUE)
    $stderr.puts "ERROR: #{e.to_s}"
    exit EXIT_ERROR
end


#
# Load eventual custom version
#
begin 
    require $zc_custom
rescue LoadError => e
    $dbg.msg(DBG::INIT, "Unable to require '#{$zc_custom}' (#{e})")
end


# XXX
## Adjustement due to zc-custom
##
#begin
#    hintfile = "#{$zc_config_dir}/rootservers"
#    if $rootserver_hintfile != hintfile
#	NResolv::DNS::RootServer.current = NResolv::DNS::RootServer.from_hintfile(hintfile)
#    end
#rescue YAML::ParseError, SystemCallError => e
#    $dbg.msg(DBG::INIT, 
#	    "Unable to read/parse rootserver hint file (#{e})")
#end


#
# Check it now!
#
exit ZoneCheck::ZoneCheck::new::start ? EXIT_OK : EXIT_FAILED
