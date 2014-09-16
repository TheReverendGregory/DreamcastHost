#!/bin/bash
# Detect connected modem and establish settings
#
# Usage:
# modem-settings.sh $Override $Modem $DCuser
#
# Where:
# $Override	= The override file
# $Modem	= Modem device to use
# $DCuser	= User account to connect to
#
# Author: Gregory Hoople
#
# Date Created: 2014-8-6
# Date Modified: 2014-9-15
#
# References:
# www.dreamcast-scene.com/guides/pc-dc-server-guide-win7
# www.ryochan7.com/blog/2009/06/23/pc-dc-server-guide-part-0-introduction
# na2's comments on:
# www.dreamcast-talk.com/forum/viewtopic.php?f=3&t=1160&start=40
# Corona688's comments on:
# www.unix.com/linux/153781-how-do-i-capture-responses-chat-command.html


# Helper Functions:
# Fuction to check that an IP address is valid.
checkIP() {
	echo $* | awk -F"\." ' $0 - /^([0-9]{1,3}\.){3}[0-9]{1,3}$/ && $1 <= 255 && $2 <= 255 && $3 <= 255 && $4 <= 255 '
}

# Use nslookup to check the IP address of the entered domain
lookupDomain() {
	toCheck=$*
	searchIP=$(nslookup $toCheck)
	echo "$searchIP" | grep -A 1 "$toCheck" | grep -m 1 "Address" |
		awk '{print $2}'
}


# Set default variables
# Override File
Override="Override"

# Modem device to connect to
MODEM="/dev/ttyACM0"

# User to log in as
DCuser="dream"

echo "Recieved: $1 | $2 | $3"

# Check if arguments have been passed in
# Check for first argument (Override)
if [[ ! -z $1 ]]; then
	Override=$1
fi

# Check for second argument (Modem)
if [[ ! -z $2 ]]; then
	MODEM=$2
fi

# Check for third argument (User Name)
if [[ ! -z $3 ]]; then
	DCuser=$3
fi

# Directory for PPP settings files
pppDirectory="/etc/ppp"

# Dreamcast User's Password
DCpass="dreamcast"

# Check for an 'Override' of 'Login' for Password
overPass=$(grep "Login" $Override | grep -v \# | awk '{print $3}')

if [[ ! -z $overPass ]]; then
	DCpass=$overPass
fi

# Current Date and Time
DATE=$(date +"%Y-%m-%d  %I:%M %p %Z")
#:%H:%M:%S`

# Set Communication Speed
SPEED=115200

# Check if the user has stated they don't want to
# get the apache web server.
overWeb=$(grep "Webserver Off" $Override | grep -v \#)

# Set up the configuration file for the modem

# Get local IP Address
myLANip=$(hostname -I)

# Remove trailing white space from IP Address
myLANip=${myLANip% *}

if [[ -z $myLANip ]]; then
	echo "Error: No Internet Detected."
	exit 1
else
	echo "Found my local IP Address: $myLANip"
fi

ipGroup=${myLANip%.*}
echo "Searching for open IP on: $ipGroup.*"
ipCheck="127.0.0.1"
ipDreamcast=""

# Check Overrride file for "Dreamcast IP"
overDCIP=$(grep "Dreamcast IP" $Override | grep -v \# |
	awk '{print $3}')

# No Override Specified for Dreamcast IP Address
if [[ -z $overDCIP ]]; then

	# IP addresses to scan through
	#HOST_LOW=25
	HOST_LOW=$(echo $myLANip | cut -d "." -f 4)
	HOST_LOW=$(($HOST_LOW + 10))
	HOST_HIGH=200

	for ((i=$HOST_LOW;i<$HOST_HIGH;i++)); do
		ipCheck=$ipGroup.$i
		if [[ $ipCheck == $myLANip ]]; then
			continue
		fi
		echo "Checking $ipCheck..."
		checkAddress=$(ping -c 1 $ipCheck)
		if [[ $checkAddress == *"0 received"* ]]; then
			echo "Found open IP Address for Dreamcast!"
			ipDreamcast=$ipCheck
			break
		elif [[ -z $checkAddress ]]; then
			echo "Error: No Network Detected."
			break
		else
			echo "... IP Address in use."
		fi
	done

else
	echo "Override for Dreamcast IP Found: $overDCIP"
	ipDreamcast=$overDCIP
fi

if [[ -z $ipDreamcast ]]; then
	echo "Error: Could not find an open IP Address for the Dreamcast."
	exit 1
else
	echo "Dreamcast IP: $ipDreamcast"
fi

netmask=$(ifconfig | grep -w inet | grep -v 127.0.0.1 |
	awk '{print $4}' | cut -d ":" -f 2)

if [[ -z $netmask ]]; then
	echo "Error: Could not find internet netmask."
	exit 1
else
	echo "Netmask is: $netmask"
fi

# Check Overrride file for "Dreamcast IP"
overDNS=$(grep "Set DNS" $Override | grep -v \# | awk '{print $3}')

# Check that the group listed a valid IP
cIP=$(checkIP $overDNS)

# If not valid, assume it's a domain
if [[ -z $cIP ]]; then
	overDNS=$(lookupDomain $overDNS)
fi


# No Override Specified for Dreamcast IP Address
if [[ ! -z $overDNS ]]; then
	echo "Override for DNS Gateway Found: $overDNS"
	gateway=$overDNS
elif [[ -z $overDNSmasq ]]; then
	gateway=$myLANip
else
	gateway=$(route -n | grep -w UG | awk '{print $2}' | cut -d " " -f 2)
fi

if [[ -z $gateway ]]; then
	echo "Error: Could not find internet gateway (router)."
	exit 1
else
	echo "Gateway is: $gateway"
fi

# /etc/ppp/options.ModemName
# Save Modem Options File
modemFile="$pppDirectory/options.$MODEM"
echo "Writing $modemFile"
echo "$myLANip:$ipDreamcast" > $modemFile
echo "netmask $netmask" >> $modemFile

# /etc/ppp/options
# Save General Options File
optFile="$pppDirectory/options"
echo "Writing $optFile"
echo "#" > $optFile
echo -e "# $optFile" >> $optFile
echo "#" >> $optFile
echo "# Author(s): Gregory Hoople" >> $optFile
echo "#" >> $optFile
echo "# Created:   2014-6-20" >> $optFile
echo "# Modified:  2014-8-5" >> $optFile
echo -e "# Generated: $DATE" >> $optFile
echo "#" >> $optFile
echo "# This is the automatically generated" >> $optFile
echo "# settings file for PPP." >> $optFile
echo "#" >> $optFile
echo "# These settings are based on the following guides:" >> $optFile
echo "# www.dreamcast-scene.com/guides/pc-dc-server-guide-win7" >> $optFile
echo "# www.ryochan7.com/blog/2009/06/23/pc-dc-server-guide-part-0-introduction" >> $optFile
echo -e >> $optFile
echo "debug" >> $optFile
echo "login" >> $optFile
echo "default-asyncmap" >> $optFile
echo "require-pap" >> $optFile
echo "proxyarp" >> $optFile
echo "ktune" >> $optFile
echo -e >> $optFile
echo "# DNS Server Address" >> $optFile
echo "# If we have dnsmasq, this is the local IP address" >> $optFile
echo "ms-dns $gateway" >> $optFile

# /etc/ppp/pap-secrets
# pap-secrets setup
papFile="$pppDirectory/pap-secrets"
echo "Checking $papFile for Dreamcast dialup login"
papSecrets=$(cat $papFile | grep $DCuser)

if [[ -z $papSecrets ]]; then
	echo "Adding login user to $papFile"
	echo "$DCuser	*	$DCpass	*" >> $papFile
else
	echo "The file $papFile is already set up."
fi

# /etc/ppp/peers/$DCuser
# user settings
# The "name" field needs to be the account
# trying to be connected to. But the peer
# filename can be any name. Just needs to
# be called with "pon FILENAME". For
# simplicity they are the same name.
peerFile="$pppDirectory/peers/$DCuser"
echo "Writing $peerFile"
echo "$MODEM" > $peerFile
echo "$SPEED" >> $peerFile
echo "name \"$DCuser\"" >> $peerFile
echo "lock" >> $peerFile
echo "usepeerdns" >> $peerFile
echo "noauth" >> $peerFile

# Set up the computer to have an account
# for the dreamcast to log into
echo "Checking for account: $DCuser"
if getent passwd $DCuser > /dev/null 2>&1; then
	# User exists
	echo "$DCuser user account found."
else
	# User does not exist
	echo "Creating $DCuser user account."
	useradd -G dialout,dip,users -c "Dreamcast user" -d /home/$DCuser -g users -s /usr/sbin/pppd $DCuser
	echo "Setting $DCuser password."
	# Not sure this is working...
	echo "$DCuser:$DCpass" | chpasswd
fi


# If we're running the web server
# set up host information
if [[ -z $overWeb ]]; then

	# Set up Hosts file for Apache Server
	hostsFile="/etc/hosts"

	# Remove the previous dreamcast domains entry
	sed -i '/Start Dream/,/End Dream/d' $hostsFile

	# Set the default web host as the local machine
	directTo=$myLANip

	# Check Override file for "Host"
	overHost=$(grep "Host" $Override | grep -v \# |
		awk '{print $2}')

	# If there's an override for "Host"
	# we direct traffic to it.
	if [[ ! -z $overHost ]]; then
		echo "Host override found: $overHost"
		directTo=$overHost
	fi

	echo "Writing Domains to $hostsFile"
	echo "### Start Dreamcast Hosts ###" >> $hostsFile

	# We write the "Redirect" override commands before
	# writing the "Domain" override commands as we give
	# the "Redirect" commands priority. In order to do
	# that they need to be at the top of the "$hostsFile"

	# Read all lines that contain "Redirect"
	while read -r line; do

		# Grab the redirect's IP address
		reIP=$(echo $line | awk '{print $3}')

		# Check that "reIP" is a valid IP address
		cIP=$(checkIP $reIP)

		# If nothing is returned, then it is not an IP address
		if [[ -z $cIP ]]; then

			# Check if the "reIP" is a Group
			cGroup=$(grep "Group" $Override | grep $reIP |
				grep -v \# | awk '{print $3}')

			# If no group found, assume it's a domain.
			if [[ -z $cGroup ]]; then

				# Check the IP for the domain
				reIP=$(lookupDomain $reIP)
			else
				#Set "reIP" to the entry for the group
				reIP=$cGroup

				# Check that the group listed a valid IP
				cIP=$(checkIP $reIP)

				# If not valid, assume it's a domain
				if [[ -z $cIP ]]; then
					reIP=$(lookupDomain $reIP)
				fi
			fi
		fi

		# Grab the redirect's domain name
		reNAME=$(echo $line | awk '{print $2}')
		echo -e "$reIP \t$reNAME" >> $hostsFile

	# Feed the check of the Overrride file for
	# "Redirect" and input results into the while loop
	done < <(grep "Redirect" $Override | grep -v \#)


	# Read all lines that contain "Domain"
	while read -r line; do

		echo -e "$directTo \t$line" >> $hostsFile

	# Feed the check of the Overrride file for
	# "Domain" and input results into the while loop
	done < <(grep "Domain" $Override | grep -v \# |
		awk '{print $2}')

	echo "#### End Dreamcast Hosts ####" >> $hostsFile

	echo "Restarting apache"
	sudo service apache2 restart

	echo "Restarting dnsmasq"
	sudo /etc/init.d/dnsmasq restart

	echo "Web server set up."
fi

echo "Updating Settings Complete"
