FROM alpine:latest
RUN apk update
RUN apk upgrade --available && sync
RUN apk --no-cache add nano curl jq bind-tools wget tree tmux ca-certificates
RUN apk --no-cache add pdns pdns-backend-sqlite3

# ENV
ENV STEPPATH=/app/step-ca
ENV STEPCA_INIT=/app/step-ca/config/ca.json
ENV STEPCA_SECRET_FILE=/app/step-ca/.secret
ENV STEPCA_SECRET="Super-Secret-KEY!-ChangeImmedi@telY"
ENV STEPCA_NAME="name"
ENV STEPCA_PROVISIONER="provisioner"
ENV STEPCA_ISSUER_PROVISIONER="issuer provisioner"
ENV STEPCA_CA_SERVER_URI="ca.example.org"


ENV PDNSPATH=/app/pdns
ENV PDNS_SQL_SCHEMA=/app/pdns/schema.sql
ENV PDNS_DB_TABLE=/app/pdns/pdns_db.sqlite

ENV PDNS_WEBSERVER_PASSWORD="adminPassword"
ENV PDNS_API_KEY="apikey1234"


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
RUN apk add step-cli step-certificates
RUN mkdir -p /app/step-ca

# EXPOSE PORTS FOR EXTERNAL ACCESS
# Container's localhost should only be the one allowed to listen!
ENV PDNS_WEBSERVER_ALLOWED_FROM="127.0.0.1"
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
