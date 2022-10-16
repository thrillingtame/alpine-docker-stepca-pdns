# MODIFYING DIRECTLY FOR ADVANCE USERS
FROM alpine:latest
LABEL container="ContainerLabel"
RUN apk update
RUN apk upgrade --available && sync
RUN apk --no-cache add bash nano bind-tools curl wget jq ca-certificates
RUN apk --no-cache add pdns pdns-backend-sqlite3

# ENV
ENV STEPPATH=/app/step-ca
ENV STEPCA_INIT=/app/step-ca/config/ca.json
ENV STEPCA_SECRET_FILE=/app/step-ca/.secret
ENV STEPCA_SECRET="SuperSecret"
ENV STEPCA_ORGANIZATION="Example Org"
ENV STEPCA_PROVISIONER="provisioneremail"
ENV STEPCA_CA_DOMAIN="domain.tld"
ENV PDNSPATH=/app/pdns
ENV PDNS_CONF=/etc/pdns/pdns.conf
ENV PDNS_SQL_SCHEMA=/app/pdns/schema.sql
ENV PDNS_DB_TABLE=/app/pdns/pdns_db.sqlite
ENV PDNS_WEBSERVER_PASSWORD="WebAdminPWD"
ENV PDNS_API_KEY="ApiKEYpdns"
ENV EDITOR="nano"

# INSTALL PowerDNS
RUN mkdir -p /app/pdns
ADD ./schema.sql /app/pdns/
RUN chown -R pdns:pdns /app/pdns
RUN rm -rf /etc/pdns/pdns.conf
ADD ./pdns.conf /etc/pdns/
RUN chown -R pdns:pdns /etc/pdns
RUN mkdir -p /var/empty/var/run


# INSTALL STEPCA
RUN echo "http://dl-cdn.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories
RUN apk update
RUN apk --no-cache add step-cli step-certificates
RUN mkdir -p /app/step-ca

# EXPOSE PORTS FOR EXTERNAL ACCESS
# PDNS API Webserver Access. Set to your LAN subnet to limit access!
ENV PDNS_WEBSERVER_ALLOWED_FROM="0.0.0.0/0"
# PDNS DNS 53 *ADVANCE USE ONLY!
# EXPOSE 53

# PDNS API
ENV PDNS_PORT="8081"
EXPOSE 8081
# STEPCA API
ENV STEPCA_PORT="8443"
EXPOSE 8443

# ENTRYPOINT
RUN rm -rf /var/cache/apk/*
ADD ./entrypoint.sh /app/
RUN chmod +x /app/entrypoint.sh
CMD ["/app/entrypoint.sh"]
