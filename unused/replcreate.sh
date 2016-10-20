n=$1
for i in `seq $n`; do
	rm -r /tmp/replica$i;
	pg_basebackup -R -D /tmp/replica$i;
	echo "port = $((5432+$i))" >> /tmp/replica$i/postgresql.conf
	echo "hot_standby = on" >> /tmp/replica$i/postgresql.conf
done
