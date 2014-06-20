#!/bin/bash -u

function error() { echo "ERROR: $*" >&2 ; }
function fatal() { echo "FATAL ERROR: $*" >&2 ; exit 42 ; }


if [ $# -ne 1 ] ; then
	echo "Usage : $(basename '$0') <serverFqdn> " >&2
	fatal "Missing parameter : serverFqdn"
fi 

serverFqdn=${1:-}



#wiki.strongswan.org/projects/strongswan/wiki/SimpleCA


caHome=$(dirname "$0")
caRadical=hyt
caCertRadical="${caHome}/${caRadical}Ca"
caKey=${caCertRadical}Key.der
caCert="${caCertRadical}Cert.der"

if [ -f "${caKey}" ] ; then
	echo "Skipping generation of already existing private key file '${caKey}'."
else
 	echo "Generating CA private key ${caKey}"
	rm -f "${caCert}"
	ipsec pki --gen > "${caKey}" || fatal "could not geneate ca Key"
fi
dnBase="C=com,O=thalesgroup,O=cloud-omc,O=hyb"

if  [ -f "${caCert}" ] ; then
	echo "Skipping generation of already existing public certificate file '${caCert}'."
else
	echo "Generating CA certificate ""${caCert}""..."
	ipsec pki --self --in "${caKey}" --dn "$dnBase,CN=ca" --ca > "${caCert}" || fatal "could not generate ca Cert"
fi
servHost="${serverFqdn%%.*}"
servCertRadical="${caHome}/${servHost}"

servKey="${servCertRadical}-Key.der"
servCert="${servCertRadical}-Cert.der"

if [ -f "${servKey}" ] ; then
	echo "Skipping generation of already existing private key file '${servKey}'."
else
	echo "Generating private key '${servKey}'..."
	rm -f "$servCert"
	ipsec pki --gen > "${servKey}" || fatal "could not generate server key"
fi

if [ -f "${servCert}" ] ; then
	echo "Skipping generation of already existing public certificate file '${servCert}'."
else
	echo "Generating server cert ""${servCert}"" for host ${servHost}..."
	dn="$dnBase,CN=${servHost}"
	ipsec pki --pub --in "${servKey}" | ipsec pki --issue --cacert "${caCert}" --cakey "${caKey}" --dn "$dn"  --san $serverFqdn > "${servCert}" || fatal "could not generate server cert"
fi
