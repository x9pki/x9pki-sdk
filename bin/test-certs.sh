#!/bin/bash

OSSL_CMD=$(type -path openssl)
HOSTS="redis:6379 postgres:5432"

for host in $HOSTS ; do
	res=$(echo "Test" | $OSSL_CMD s_client -connect $host \
		-key services.d/manager/client.key \
		-cert services.d/manager/client.cer \
		-cert_chain services.d/manager/client.chain \
		-CAfile services.d/manager/root_ca.cer 2>&1 )
	if [ $? -gt 0 ] ; then
		echo && echo "    ERROR: cannot connect to $host." && echo
		echo $res && echo
		exit 1
	fi
	echo "$res"
done

exit 0
