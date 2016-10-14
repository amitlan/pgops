#!/bin/sh

poll_stack()
{
	nstf="$1";
	for pidprocname in `ps aux | grep postgres: | grep pgbench | grep -v grep | awk -v OFS="" '{print $2, ":", $12}'`;
		do echo $pidprocname |\
		awk -F ":" -v cmdvar="$nstf" -v OFS="" '{print "== ", $1, " (", $2, ") ", "=="; system("pstack "$1" | head -n "cmdvar);}';
	done;
}
export -f poll_stack

show_summary()
{
	grep -v "^=" /tmp/pg-stack.txt | awk '{print $4}' > /tmp/pgstack.csv;
	psql --no-psqlrc pgbench -f /tmp/pg-stack.sql
}
export -f show_summary

trap 'show_summary' INT
rm -f /tmp/pg-stack.txt
watch -n $2 poll_stack $1 '|' tee -a /tmp/pg-stack.txt
