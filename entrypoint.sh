#!/bin/bash
set -m
# Initialize PDNS
if [[ ! -f ${PDNS_DB_TABLE} ]]; then
	echo ""
	echo "<< 🤓		Modifying PDNS Configuration... >>"
	sed -i "s/#webserver-port=8081/webserver-port=${PDNS_PORT}/" ${PDNS_CONF}
	sed -i "s/#webserver-password=/webserver-password=${PDNS_WEBSERVER_PASSWORD}/" ${PDNS_CONF}
	sed -i "s/#api-key=/api-key=${PDNS_API_KEY}/" ${PDNS_CONF}
	echo ""
	echo "<< 😑		Creating database schema... >>"
	sqlite3 ${PDNS_DB_TABLE} < ${PDNS_SQL_SCHEMA}
	chmod 755 -R ${PDNS_DB_TABLE}
	chown -R pdns:pdns ${PDNS_DB_TABLE}
	rm ${PDNS_SQL_SCHEMA}
	echo ""
	echo "<< 😎		Database Ready! >>"

else
	echo ""
	echo "<< 😎		Database Ready! >>"
fi

# Initialize Step-CA
if [[ ! -f ${STEPCA_INIT} ]]; then
	echo ""
	echo "<< 👀		Applying Step-CA Secret File! >>"
	echo "${STEPCA_SECRET}" > ${STEPCA_SECRET_FILE}
	echo ""
	echo "<< 🐣		Initializing Step-CA... >>"
	step ca init \
		--ssh \
		--deployment-type=standalone \
		--name="${STEPCA_ORGANIZATION}" \
		--provisioner=${STEPCA_PROVISIONER} \
		--dns=localhost \
		--dns=ca.${STEPCA_CA_DOMAIN} \
		--address=:${STEPCA_PORT} \
		--password-file=${STEPCA_SECRET_FILE} \
		--issuer-provisioner=${STEPCA_PROVISIONER} \
		--issuer=https://ca.${STEPCA_CA_DOMAIN}:${STEPCA_PORT}  2>&1 | tee -a ${STEPPATH}/.step-ca.init
	echo ""
	echo ""
	echo "  ☢️  WARNING    WARNING    WARNGING  ☢️  "
	echo " YOU ARE RESPONSIBLE FOR BACKING UP ANY PRIVATE INFO GENERATED ABOVE!"
	echo " THE DOCKER CONTAINER IS PROVIDED AS IS "
	echo "  ☢️  WARNING    WARNING    WARNGING  ☢️  "
	echo ""
	echo ""
	echo "<< 🤖		Enabling ACME Provisioner! >>"
	step ca provisioner add acme --type ACME
	echo ""
	echo "<< 🫠		Ensure Default Certificates Expiration is set <397 days... >>"
	cp ${STEPPATH}/config/ca.json ${STEPPATH}/config/ca.json.bak
	jq '.authority.provisioners[[.authority.provisioners[] | .type=="JWK"] | index(true)].claims |= (. + {"maxTLSCertDuration":"9360h","defaultTLSCertDuration":"9360h"})' ${STEPPATH}/config/ca.json.bak > ${STEPPATH}/config/ca.json
	cp ${STEPPATH}/config/ca.json ${STEPPATH}/config/ca.json.bak
	jq '.authority.provisioners[[.authority.provisioners[] | .type=="ACME"] | index(true)].claims |= (. + {"maxTLSCertDuration":"9360h","defaultTLSCertDuration":"9360h"})' ${STEPPATH}/config/ca.json.bak > ${STEPPATH}/config/ca.json
	cp ${STEPPATH}/config/ca.json ${STEPPATH}/config/ca.json.bak
	echo ""
	echo "<< 😎		STEP-CA Ready! >>"
else
	echo ""
	echo "<< 😎		STEP-CA Ready! >>"
fi

# Running the services
if [[ ! -f /app/.initialized ]]; then
	# First time run services in background
	echo ""
	echo "<< 🫥		Running Services and placing into background...	>>"
	nohup pdns_server --webserver-allow-from="${PDNS_WEBSERVER_ALLOWED_FROM}" &
	step-ca	--password-file=${STEPCA_SECRET_FILE} "${STEPCA_INIT}" &>/dev/null &

	# Give time for Step-CA to start
	sleep 3

	# Trust Step-CA's generated certificate
	echo ""
	echo "<< 🤓		Adding ca.${STEPCA_CA_DOMAIN} to localhost file! >>"
	echo "127.0.0.1 ca.${STEPCA_CA_DOMAIN}" >> /etc/hosts
	echo ""
	echo "<< 🤠		Downloading Roots.pem and moving it to local ca-certificates Directory... >>"
	wget https://ca.${STEPCA_CA_DOMAIN}:${STEPCA_PORT}/roots.pem --no-check-certificate --quiet
	mv roots.pem /usr/local/share/ca-certificates/
	echo ""
	echo "<< 👁		Trusting ${STEPCA_PROVISIONER} inside the container! >>"
	update-ca-certificates &>/dev/null
	echo ""
	echo "<< 🫣		Restarting Step-CA to Apply changes and Check health status >>"
	echo ""
	kill %2
	sleep 3
	step-ca	--password-file=${STEPCA_SECRET_FILE} "${STEPCA_INIT}" &
	sleep 3
	curl -s https://ca.${STEPCA_CA_DOMAIN}:${STEPCA_PORT}/health
	echo ""
	echo "<< 🎉		Container is running normally! >>"
	echo ""
	echo "<< 🏁		Now bringing up Step-CA process in the foreground...>>"
	echo ""
	echo "🫡"
	touch /app/.initialized
	echo "127.0.0.1" > /etc/resolv.conf
	echo ""
	fg %3
else
	echo "<< 🫥		Running Services and placing into background...	>>"
	nohup pdns_server --webserver-allow-from="${PDNS_WEBSERVER_ALLOWED_FROM}" &
	step-ca	--password-file=${STEPCA_SECRET_FILE} "${STEPCA_INIT}" &>/dev/null &
	# Give time for Step-CA to start
	sleep 3
	echo ""
	echo "<< 🫣		Checking Step-CA health status >>"
	echo ""
	curl -s https://ca.${STEPCA_CA_DOMAIN}:${STEPCA_PORT}/health
	echo ""
	echo "<< 🎉		Container is running normally! >>"
	echo ""
	echo "<< 🏁		Now bringing up Step-CA process in the foreground...>>"
	echo ""
	echo "🫡"
	echo "127.0.0.1" > /etc/resolv.conf
	fg %2
fi