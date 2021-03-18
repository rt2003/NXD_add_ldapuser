#!/bin/bash
# Defaults
LDAP_BASE="dc=nextdrive,dc=io"
LDAP_BIND_DN="cn=admin,${LDAP_BASE}"

while IFS=',' read -r gn sn tel mobile uid email group title dfgroup loc; do
#	awk 'BEGIN {FS='\t'} { print $4}'
	/usr/local/sbin/nd_ldapadduser "$uid" "3640" "$gn" "$sn" "$email" "$tel" "$mobile" "$loc" "$title"
	/usr/local/sbin/ldapaddusertogroup "$uid" "$group"
	/usr/local/sbin/ldapaddusertogroup "$uid" "$dfgroup"
#ADD USER EMAIL TO DEFAULT GROUP
LDAP_DFGROUP="cn=${dfgroup},ou=Groups,${LDAP_BASE}"

LDIF1=$(cat << EOF
dn: ${LDAP_DFGROUP}
changetype: modify
add: name
name: ${email}
EOF
)

echo "$LDIF1" | ldapmodify -Y EXTERNAL -H ldapi:///

#ADD USER EMAIL TO PRIVATE GROUP
LDAP_PGROUP="cn=${group},ou=Groups,${LDAP_BASE}"

LDIF2=$(cat << EOF
dn: ${LDAP_PGROUP}
changetype: modify
add: name
name: ${email}
EOF
)

echo "$LDIF2" | ldapmodify -Y EXTERNAL -H ldapi:///

#Generate password file to send email
PW="$(cat /var/log/ldapscripts_passwd.log | grep "$uid" | tail -1 | awk {'print $3'})"
echo $uid,$PW >> newcomer.pw

done < nextdrive.user

#Upload password file to GCDS server
scp newcomer.pw root@192.168.3.233:/root/

#Send email from remotely and delete file
ssh root@192.168.3.233 "php /root/newcomer_sendEmail.php; rm /root/newcomer.pw"

#Delete local password file
rm /root/add_ldap_user/newcomer.pw
