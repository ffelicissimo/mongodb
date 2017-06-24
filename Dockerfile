#
# MongoDB Dockerfile (adapted from: https://github.com/dockerfile/mongodb)
# 
# To run :
# docker run -d -p 27017:27017 --name mongodb ${machineUUID}
#
# To run with mounted directory for storage: 
# docker run -d -p 27017:27017 -v <db-dir>:/data/db --name mongodb ${machineUUID}
#
# To test backup and restore, run this command inside container:
# cd /backups;./backup.sh;mongo --verbose 127.0.0.1:27017/calcdb -u minmaster -p f1faa381-7568-46c8-8332-d4322376083a --eval "db.dropDatabase()";./restore.sh

FROM debian:jessie

# add our user and group first to make sure their IDs get assigned consistently, regardless of whatever dependencies get added
RUN groupadd -r mongodb && useradd -r -g mongodb mongodb

RUN apt-get update && apt-get install -y vim cron 

# Create the log file to be able to run tail
RUN touch /var/log/cron.log

# grab gosu for easy step-down from root
ENV GOSU_VERSION 1.7
RUN set -x \
	&& apt-get update && apt-get install -y --no-install-recommends ca-certificates wget && rm -rf /var/lib/apt/lists/* \
	&& wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture)" \
	&& wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture).asc" \
	&& export GNUPGHOME="$(mktemp -d)" \
	&& gpg --keyserver ha.pool.sks-keyservers.net --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 \
	&& gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu \
	&& rm -r "$GNUPGHOME" /usr/local/bin/gosu.asc \
	&& chmod +x /usr/local/bin/gosu \
	&& gosu nobody true \
	&& apt-get purge -y --auto-remove ca-certificates wget

# pub   4096R/A15703C6 2016-01-11 [expires: 2018-01-10]
#       Key fingerprint = 0C49 F373 0359 A145 1858  5931 BC71 1F9B A157 03C6
# uid                  MongoDB 3.4 Release Signing Key <packaging@mongodb.com>
RUN apt-key adv --keyserver ha.pool.sks-keyservers.net --recv-keys 0C49F3730359A14518585931BC711F9BA15703C6

ENV MONGO_MAJOR 3.4
ENV MONGO_VERSION 3.4.0
ENV MONGO_PACKAGE mongodb-org

RUN echo "deb http://repo.mongodb.org/apt/debian jessie/mongodb-org/$MONGO_MAJOR main" > /etc/apt/sources.list.d/mongodb-org.list

RUN set -x \
	&& apt-get update \
	&& apt-get install -y \
		${MONGO_PACKAGE}=$MONGO_VERSION \
		${MONGO_PACKAGE}-server=$MONGO_VERSION \
		${MONGO_PACKAGE}-shell=$MONGO_VERSION \
		${MONGO_PACKAGE}-mongos=$MONGO_VERSION \
		${MONGO_PACKAGE}-tools=$MONGO_VERSION \
	&& rm -rf /var/lib/apt/lists/* \
	&& rm -rf /var/lib/mongodb \
	&& mv /etc/mongod.conf /etc/mongod.conf.orig

COPY backup.sh /backup.sh
COPY restore.sh /restore.sh
COPY crontab /etc/cron.d/mongodb-backup-cron
RUN chmod 0644 /etc/cron.d/mongodb-backup-cron
RUN crontab /etc/cron.d/mongodb-backup-cron
COPY docker-entrypoint.sh /docker-entrypoint.sh
WORKDIR /data

RUN mkdir -p /data/db /data/configdb /backups \
	&& chown -R mongodb:mongodb /data/db /data/configdb /backups

VOLUME /data/db /data/configdb /backups

COPY docker-entrypoint.sh /docker-entrypoint.sh
ENTRYPOINT ["/docker-entrypoint.sh"]

EXPOSE 27017 

RUN sed -i '/session    required     pam_loginuid.so/c\#session    required     pam_loginuid.so' /etc/pam.d/cron
RUN echo "America/Sao_Paulo" > /etc/timezone

CMD ["mongod", "--auth"]
