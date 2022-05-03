#!/bin/bash

PG_VERSION="${PG_VERSION:-14}"
PG_SLOT="${PG_SLOT:-replica_1_slot}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-123@mudar}"

PG_CONTAINER_DATA="/var/lib/postgresql/data"

function wait_pg_running() {
    local container=${1}
    local file=${PG_CONTAINER_DATA}/postgresql.conf
    until [[ "$(docker container exec -u postgres ${container} psql -qAt -c "select 1;" 2>/dev/null )" == 1 ]]; do
        echo "Aguardando ${container}"
        sleep 1;
    done;
}

function wait_pg_compose_running() {
    local service=${1}
    until [[ "$(docker-compose exec -u postgres ${service} psql -qAt -c "select 1;" 2>/dev/null)"  ==  1 ]]; do
        echo "Aguardando ${service}"
        sleep 1;
    done;
}


# docker container run --name pg_temp -d -e POSTGRES_PASSWORD="${POSTGRES_PASSWORD}" "postgres:${PG_VERSION}"

# wait_pg_running pg_temp

# docker container cp pg_temp:"${PG_CONTAINER_DATA}/postgresql.conf" primary/
# docker container cp pg_temp:"${PG_CONTAINER_DATA}/pg_hba.conf" primary/

# docker container rm -f pg_temp

# chmod 644 primary/postgresql.conf
# chmod 644 primary/pg_hba.conf

# echo -e "\nwal_level = replica\nmax_wal_senders = 10\nwal_keep_size = '1GB'\nwal_compression = on" >> primary/postgresql.conf
# echo -e "\nhost    replication     repl            192.168.55.0/24         trust\n" >> primary/pg_hba.conf

# docker-compose up -d primary

# wait_pg_compose_running primary

# docker-compose exec -u postgres primary createuser --replication repl
# docker-compose exec -u postgres primary psql -c "select * from pg_create_physical_replication_slot('${PG_SLOT}');"


set -x

touch ./replica/postgresql.conf
touch ./replica/pg_hba.conf

docker-compose run --rm \
    --entrypoint bash \
    replica \
    -c "chown postgres:postgres /var/lib/postgresql/data"

docker-compose run --rm -u postgres --name repl_temp \
    -v $(pwd)/replica/data:${PG_CONTAINER_DATA}/../pgdata:rw \
    --entrypoint bash \
    replica \
    -c "pg_basebackup --pgdata ${PG_CONTAINER_DATA}/../pgdata \
    --format=p --write-recovery-conf --checkpoint=fast --label=replica-1 \
    --progress --host=primary --port=5432 --username=repl"

docker-compose run --rm -u postgres --name repl_temp \
    -v $(pwd)/replica/data:${PG_CONTAINER_DATA}/../pgdata:rw \
    --entrypoint bash \
    -d \
    replica \
    -c "sleep 10"

docker container cp repl_temp:${PG_CONTAINER_DATA}/../pgdata/postgresql.conf replica/postgresql.conf.1
docker container cp repl_temp:${PG_CONTAINER_DATA}/../pgdata/pg_hba.conf replica/pg_hba.conf.1

docker container rm -f repl_temp

mv replica/postgresql.conf.1 replica/postgresql.conf
mv replica/pg_hba.conf.1 replica/pg_hba.conf

chmod 644 replica/postgresql.conf
chmod 644 replica/pg_hba.conf

echo -e "\nprimary_conninfo = 'user=repl port=5432 host=primary application_name=replica-1'" >> replica/postgresql.conf
echo -e "\nprimary_slot_name = 'replica_1_slot'" >> replica/postgresql.conf