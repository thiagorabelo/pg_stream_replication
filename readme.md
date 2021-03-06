# Exemplo de Configuração de Stream Replication no PostgreSQL 14

Usaremos as imagens Docker oficiais do Postgres 14 para criar o cluster com
uma instância primária e uma réplica.

As configurações necessárias para rodar os container estão no arquivo
`docker-compose.yaml`, como rede e `Dockerfile`.

## Configurando a instância primária

Execute um container do PostgreSQL somente para copiar os arquivos de configurações:

```sh
# vamos executar somente para poder copiar os arquivos de configuração
docker container run --name pg_temp -d -e POSTGRES_PASSWORD=123@mudar postgres:14
```

```sh
# Copiando o arquivo postgresql.conf
docker container cp pg_temp:/var/lib/postgresql/data/postgresql.conf primary/

# Copiando o arquivo pg_hba.conf
docker container cp pg_temp:/var/lib/postgresql/data/pg_hba.conf primary/
```

Agora já pode parar a execução

```sh
docker container rm -f pg_temp
```

Altere as permissões dos arquivos:

```sh
chmod 644 primary/postgresql.cong
chmod 644 primary/pg_hba.conf
```

Estes dois arquivos estão configurados serem usados como configuração quando
forem executados com o Compose.

### Editando os arquivos de configuração

Altere as entradas a abaixo ao arquivo `postgresql.conf`

```conf
wal_level = replica
max_wal_senders = 10
wal_keep_size = '1GB'
wal_compression = on
```

Altere o arquivo `pg_hba.conf` com a configuração abaixo, informando o IP da
instância da réplica que poderá fazer a replicação:

```conf
# OBS: Neste caso não especificamos o IP específico da máquina, mas sim
#      o endereço da subrede. Desta forma todo container que estiver na
#      network poderá fazer a replicação.
#
# TYPE  DATABASE        USER            ADDRESS                 METHOD
host    replication     repl            192.168.55.0/24         trust
```

### Executando a instância primária

Para executar somente a instância primária, faça:

```sh
docker-compose up -d primary
```

Crie o usuário com permissão de replicação que informamos em `pg_hba.conf`.
Para tal, acesse o terminal do container primário:

```sh
# Acessando o terminal do container
docker-compose exec -u postgres primary bash
```

```sh
# Criando o usuário
createuser --replication repl
```

Crie um slot no primário para cada réplica, onde cada slot terá um valor
único. E este nome será informado na configuração da réplica.

```sh
psql -c "select * from pg_create_physical_replication_slot('replica_1_slot');"

psql -c "select slot_name, slot_type, active, wal_status from pg_replication_slots;"
```

## Configurando a instância réplica

### Criando o Base Backup

Antes de qualquer ação, precisamos comentar a linha que possui a instrução
`command`, e os volumes que mapeiam os arquivos `postgresql.conf`e
`pg_hba.conf`, da configuração de `replica` do `docker-compose.yaml`

Em seguida vamos executar uma instância temporária para criar no host a pasta
onde serão armazenados os arquivos e mudar as permissões.

```sh
docker-compose run --rm replica bash \
    -c "chown postgres:postgres /var/lib/postgresql/data"
```

Vamos, novamente, criar uma instância temporária somente para realizar o
processo de base backup e copiar os arquivos `postgresql.conf` e `pg_hba.conf`.

```sh
# Iniciando uma instância temporária da replica.
docker-compose run --rm -i -u postgres --name repl_temp replica bash
```

```sh
# Fazendo o base backup.
# --host=     - É configurado com o nome do service do compose (primary)
# --username= - É usado o usuário criado no servidor primário para fazer
#               a replicação (repl).
# --label=    - Um label dado para o backup.
pg_basebackup --pgdata /var/lib/postgresql/data --format=p \
    --write-recovery-conf --checkpoint=fast --label=replica-1 \
    --progress --host=primary --port=5432 --username=repl
```

Em outro terminal, copie os arquivos de configuração:

```sh
# Copiando o arquivo postgresql.conf
docker container cp repl_temp:/var/lib/postgresql/data/postgresql.conf replica/

# Copiando o arquivo pg_hba.conf
docker container cp repl_temp:/var/lib/postgresql/data/pg_hba.conf replica/
```

Altere as permissões dos arquivos:

```sh
chmod 644 replica/postgresql.cong
chmod 644 replica/pg_hba.conf
```

Descomente a linha com a instrução `command` e `volumes`.

Edite o arquivo `replica/postgresql.conf` e configure o acesso à instância primária
adicionando as configurações abaixo:

```conf
# Configurações de acesso (usuário, porta e host [ou ip] da instância primária) e
# nome da aplicação (nome do aplicativo a ser relatado em estatísticas e logs).
primary_conninfo = 'user=repl port=5432 host=primary application_name=replica-1'

# Slot criado no primário que esta replica usará.
primary_slot_name = 'replica_1_slot'
```

## Referência

- <https://girders.org/postgresql/2021/11/05/setup-postgresql14-replication/>
- <https://hevodata.com/learn/postgresql-replication-slots/>
- <https://www.archaeogeek.com/blog/2011/08/11/setting-up-a-postgresql-standby-servers/>
- <https://mydbops.wordpress.com/2021/01/20/pgpool-ii-installation-configuration-part-i/>
- <https://www.pgpool.net/docs/pgpool-II-3.0/tutorial-en.html>
