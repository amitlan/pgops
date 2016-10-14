start=$1
end=$2
op=$3
for i in `seq $start $end`; do
	pg_ctl -D /tmp/replica$i $op;
done
