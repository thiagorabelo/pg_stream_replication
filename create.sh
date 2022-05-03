#!/bin/bash

PG_VERSION="${PG_VERSION:-14}"
PG_SLOT="${PG_SLOT:-replica_1_slot}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-123@mudar}"
PG_REPLICATION_USER=repl
PG_NETWORK=${PG_NETWORK:-192.168.55.0/24}

PG_CONTAINER_DATA="/var/lib/postgresql/data"

PGPOOL_MONITOR="monitor"
PGPOOL_MONITOR_PWD="m0n1T0r"
PGPOOL_MONITOR_DB="monitor"

dc="$(docker compose --help 2>&1 > /dev/null && echo "docker compose" || echo "docker-compose")"

function wait_pg_ok() {
    local agent=${AGENT:-"docker container"}
    local resource=${1}
    until [[ "$(${agent} exec -u postgres ${resource} psql -qAt -c "select 1;" 2>/dev/null )" == 1 ]]; do
        echo "Aguardando ${resource}"
        sleep 1
    done;
}


docker container run --name pg_temp -d \
    -e POSTGRES_PASSWORD="${POSTGRES_PASSWORD}" \
    "postgres:${PG_VERSION}"

wait_pg_ok pg_temp

docker container cp pg_temp:"${PG_CONTAINER_DATA}/postgresql.conf" primary/
docker container cp pg_temp:"${PG_CONTAINER_DATA}/pg_hba.conf" primary/

docker container rm -f pg_temp

chmod 644 primary/postgresql.conf
chmod 644 primary/pg_hba.conf

echo -e "\nwal_level = replica\nmax_wal_senders = 10\nwal_keep_size = '1GB'\nwal_compression = on" >> primary/postgresql.conf
echo -e "\nhost    replication     ${PG_REPLICATION_USER}            ${PG_NETWORK}         trust\n" >> primary/pg_hba.conf

${dc} up -d primary

AGENT="${dc}" wait_pg_ok primary

${dc} exec -u postgres primary createuser --replication ${PG_REPLICATION_USER}
${dc} exec -u postgres primary \
    psql -c "select * from pg_create_physical_replication_slot('${PG_SLOT}');"

${dc} exec -u postgres primary \
    psql -c "create user ${PGPOOL_MONITOR} with login encrypted password '${PGPOOL_MONITOR_PWD}';"
${dc} exec -u postgres primary \
    createdb --owner=${PGPOOL_MONITOR} ${PGPOOL_MONITOR}

touch ./replica/postgresql.conf
touch ./replica/pg_hba.conf

${dc} run --rm \
    --entrypoint bash \
    replica \
    -c "chown postgres:postgres /var/lib/postgresql/data"

${dc} run --rm -u postgres --name repl_temp \
    -v $(pwd)/replica/data:${PG_CONTAINER_DATA}/../pgdata:rw \
    --entrypoint bash \
    replica \
    -c "pg_basebackup --pgdata ${PG_CONTAINER_DATA}/../pgdata \
    --format=p --write-recovery-conf --checkpoint=fast --label=replica-1 \
    --progress --host=primary --port=5432 --username=${PG_REPLICATION_USER}"

${dc} run --rm -u postgres --name repl_temp \
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

echo -e "\nprimary_conninfo = 'user=${PG_REPLICATION_USER} port=5432 host=primary application_name=replica-1'" >> replica/postgresql.conf
echo -e "\nprimary_slot_name = '${PG_SLOT}'" >> replica/postgresql.conf

${dc} down
