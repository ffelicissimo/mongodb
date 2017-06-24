#!/bin/bash

if [ ! -f /data/db/.mongodb_password_set ]; then
        echo "Setting password..."

        mongod --fork --logpath /var/log/mongodb/mongodb.log

        RET=1
        while [[ RET -ne 0 ]]; do
            echo "=> Waiting for confirmation of MongoDB service startup"
            sleep 5
            mongo admin --eval "help" >/dev/null 2>&1
            RET=$?
        done

        mongoUsername=${MONGODB_USERNAME:-"usr_mongo"}
        dataDB=${DATA_DB:-"mongodb"}
        echo "=> Creating an admin user in MongoDB"
        mongo admin --eval "db.createUser({user: '$mongoUsername', pwd: '$MONGODB_PASSWORD', roles: [ 'root' ]});"
        mongo $dataDB --eval "db.createUser({user: '$mongoUsername', pwd: '$MONGODB_PASSWORD', roles: [ 'dbOwner', 'userAdmin' ]});"
        mongod --shutdown

        echo "=> Done!"
        touch /data/db/.mongodb_password_set
fi
if [ ! -f /.env_set ]; then
        echo "MONGODB_PASSWORD=$MONGODB_PASSWORD" >> /etc/environment
        touch /.env_set
fi

cron
echo "$(date) container started. cron job: $(cat /etc/cron.d/mongodb-backup-cron | head -1)" >> /backups/backup.log

exec "$@"
