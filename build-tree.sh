CFLAGS="-g -Wunused -Wreturn-type -Wunused-but-set-variable" ./configure --enable-debug --enable-cassert --prefix=/home/amit/pg/install/head
make -j2
make install

export PATH=/home/amit/pg/install/head/bin:$PATH
export PGDATA=~/pg/data/head
