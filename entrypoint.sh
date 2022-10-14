#!/usr/bin/env sh
set -m
# Initialize PDNS
if [[ ! -f ${PDNS_DB_TABLE} ]]; then
	echo "<< 🤓 Applying PDNS WebServer Port >>"
	sed -i "s/#webserver-port=8081/webserver-port=${PDNS_PORT}/" /etc/pdns/pdns.conf
	echo "<< 😑 Creating database schema.. 😑>>"
	sqlite3 ${PDNS_DB_TABLE} < ${PDNS_SQL_SCHEMA}
	chmod 755 -R ${PDNS_DB_TABLE}
	chown -R pdns:pdns ${PDNS_DB_TABLE}
	rm ${PDNS_SQL_SCHEMA}
	echo "<< 😎 Database Ready! 😎>>"

else
	echo "<< 😎 Database Ready! 😎 >>"
fi

# Initialize Step-CA
if [[ ! -f ${STEPCA_INIT} ]]; then
	echo "<< 👀 Applying Step-CA Secret File 👀>>"
	echo "${STEPCA_SECRET}" > ${STEPCA_SECRET_FILE}
	echo "<< 🐣 Initializing Step-CA.. >>"
	step ca init \
		--ssh \
		--deployment-type=standalone \
		--name="${STEPCA_PROVISIONER}" \
		--provisioner=${STEPCA_PROVISIONER} \
		--dns=${STEPCA_CA_SERVER_URI} \
		--address=0.0.0.0:${STEPCA_PORT} \
		--password-file=${STEPCA_SECRET_FILE} \
		--issuer-provisioner=${STEPCA_ISSUER_PROVISIONER} \
		--issuer=https://${STEPCA_CA_SERVER_URI}:${STEPCA_PORT}  2>&1 | tee -a ${STEPPATH}/.step-ca.init
	echo ""
	echo ""
	echo "<< 🤖 Enabling ACME Provisioner 🤖 >>"
	step ca provisioner add acme --type ACME
	echo "<< 🫠Ensure Default Certificates Expiration is set <397 days 🫠>>"
	cp ${STEPPATH}/config/ca.json ${STEPPATH}/config/ca.json.bak
	jq '.authority.provisioners[[.authority.provisioners[] | .type=="JWK"] | index(true)].claims |= (. + {"maxTLSCertDuration":"9360h","defaultTLSCertDuration":"9360h"})' ${STEPPATH}/config/ca.json.bak > ${STEPPATH}/config/ca.json
	cp ${STEPPATH}/config/ca.json ${STEPPATH}/config/ca.json.bak
	jq '.authority.provisioners[[.authority.provisioners[] | .type=="ACME"] | index(true)].claims |= (. + {"maxTLSCertDuration":"9360h","defaultTLSCertDuration":"9360h"})' ${STEPPATH}/config/ca.json.bak > ${STEPPATH}/config/ca.json
	cp ${STEPPATH}/config/ca.json ${STEPPATH}/config/ca.json.bak
	echo "<< 😎 STEP-CA Ready! 😎 >>"
else
	echo "<< 😎 STEP-CA Ready! 😎 >>"
fi

# RUN Services

echo "<< 🫥 Running PDNS and placing into background 🫥>>"
pdns_server \
	--loglevel="0" \
	--webserver-allow-from="${PDNS_WEBSERVER_ALLOWED_FROM}" \
	--webserver-password="${PDNS_WEBSERVER_PASSWORD}" \
	--api-key="${PDNS_API_KEY}" &
sleep 3

echo "<< 🫥 Running Step-CA and placing into background 🫥>>"
step-ca \
	--password-file=${STEPCA_SECRET_FILE} ${STEPCA_INIT} &

# Give time and space for Step-CA to start
sleep 3
echo ""
echo ""

# Trust Step-CA's generated certificate
echo "<< 🤓 Adding ${STEPCA_CA_SERVER_URI} to localhost file >>"
echo "127.0.0.1 ${STEPCA_CA_SERVER_URI}" >> /etc/hosts

echo "<< 🤠 Downloading Roots.pem and moving it to local ca-certificates Directory 🤠>>"
wget -q https://${STEPCA_CA_SERVER_URI}:${STEPCA_PORT}/roots.pem --no-check-certificate
mv roots.pem /usr/local/share/ca-certificates/

echo "<< 👁 Trusting ${STEPCA_PROVISIONER} inside the container 👁 >>"
update-ca-certificates &>/dev/null

echo "<< 🫣 Checking Step-CA health status 🫣 >>"
curl https://${STEPCA_CA_SERVER_URI}:${STEPCA_PORT}/health 

echo "<< 🎉 Container is running normally! 🏁>>"
echo "<< 🫡Now bringing up Step-CA process in the foreground... 🫡>>"


fg %2