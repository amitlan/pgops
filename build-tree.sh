PGDIR=$HOME/pg

CFLAGS="-g -Wunused -Wreturn-type -Wunused-but-set-variable" ./configure --enable-debug --enable-cassert --prefix=$PGDIR/install/head
make -j2
make install

export PATH=$PGDIR/install/head/bin:$PATH
export PGDATA=$PGDIR/data/head
