PGDATA=$HOME/postgres/data/head
rm -r $PGDATA
initdb -N -D $PGDATA
echo "logging_collector = on" >> $PGDATA/postgresql.conf
echo "shared_buffers = 256MB" >> $PGDATA/postgresql.conf
