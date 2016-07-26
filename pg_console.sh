HOME=/home/amit
PGDIR=$HOME/pg

usage()
{
	echo "USAGE: pg_console op [ version_num | git_branch_name ]"
	echo ""
	echo " where op is:"
	echo ""
	echo " help - get this help text"
	echo " init - init PGDIR for the first time"
	echo " get  - get source tarball 9.x.x   ($ pg_console get 9.x.x)"
	echo " ?    - tell branch in git         ($ pg_console ?)"
	echo " e    - export PATH for a version  ($ pg_console e [ 9.x.x | branch ])"
	echo " i    - install version            ($ pg_console i [ 9.x.x | branch ])"
	echo " d    - init database              ($ pg_console d [ 9.x.x | branch ])"
	echo " s    - start server               ($ pg_console s [ 9.x.x | branch ])"
	echo " x    - stop server                ($ pg_console x [ 9.x.x | branch ])"
	echo " r    - restart server             ($ pg_console r [ 9.x.x | branch ])"
	echo ""
	return;
}
export -f usage;

init()
{
	echo "====================================";
	echo " Initializing for the first time...";
	echo "====================================";
	mkdir -p $PGDIR;
	mkdir -p $PGDIR/arch;
	mkdir -p $PGDIR/data;
	mkdir -p $PGDIR/gitsnap;
	mkdir -p $PGDIR/install;
	mkdir -p $PGDIR/tar;
	git clone https://github.com/postgres/postgres.git $PGDIR/git;
	return;
}
export -f init

get_tarball()
{
	ver=$1;
	alreadyhave=`ls -l $PGDIR/tar/ | grep "$ver" | wc -l`;
	if [ "$alreadyhave" != 0 ]; then
		echo "already have $ver...";
		return;
	fi;
	wget -P $PGDIR/tar/ http://ftp.postgresql.org/pub/source/v"$ver"/postgresql-"$ver".tar.gz &&\
	tar -xzf $PGDIR/tar/postgresql-"$ver".tar.gz -C $PGDIR/tar/ 
}
export -f get_tarball

set_version()
{
	branch=$1
	ver=$2
	origdir=`pwd`
	# check if requested a 9.x.x and we don't yet have a tarball
	if [ ! -z "$ver" ]; then
		verlen=`echo "$ver" | awk '{ n = split($1, dummy, "."); print n;}'`;
		if [ "$verlen" == "3" ]; then
			cd $PGDIR/tar/postgresql-$ver &> /dev/null
			if [ "$?" != 0 ]; then
		 		echo "===================================================";
				echo " Please run 'pg_console get $ver' before proceeding";
		 		echo "===================================================";
				echo "";
				return 1;
			fi;
		else
			# $ver is really a git branch name; check if valid name
			cd $PGDIR/git;
			oldver=`git status | grep "On branch" | awk '{print $4}'`;
			git checkout $ver &> /dev/null
			if [ "$?" != 0 ]; then
				echo "Named branch does not exist";
				cd $origdir
				return 1;
			fi
			git checkout $oldver &> /dev/null
		fi
	else
		# determine the current git branch and use as version
		cd $PGDIR/git;
		gitbr=`git status | grep "On branch" | awk '{print $4}'`;
		eval "$branch='$gitbr'"
	fi

	cd $origdir
}
export -f set_version

cd_to_source_or_git_branch()
{
	origdir=$1
	origver=$2
	ver=$3

	# cd to appropriate directory within $PGDIR/tar/
	verlen=`echo "$ver" | awk '{ n = split($1, dummy, "."); print n;}'`;
	if [ "$verlen" == "3" ]; then
		cd $PGDIR/tar/postgresql-$ver
		return;
	fi

	# switch to the requested git branch, remembering the current one
	cd $PGDIR/git
	oldver=`git status | grep "On branch" | awk '{print $4}'`;
	git checkout "$ver" &> /dev/null
	GITSNAPPATH=$PGDIR/gitsnap/$ver;
	git archive --format=tar HEAD | gzip > $GITSNAPPATH.tar.gz;
	mkdir -p $GITSNAPPATH;
	{
		rm -r $GITSNAPPATH/*;
	} 2>&1 > /dev/null;
	tar -xzf $GITSNAPPATH.tar.gz -C $GITSNAPPATH && rm $GITSNAPPATH.tar.gz;
	cd $GITSNAPPATH;
	if [ "$oldver" != "$ver" ]; then
		eval "$origver='$oldver'"
	fi
}
export -f cd_to_source_or_git_branch

do_install()
{
	ver=$1
	PGINSTALL="$PGDIR/install/$ver";
	mkdir -p $PGINSTALL;

	# Clean up and build
	{
		if [ -f "config.status" ]; then
			gmake distclean;
		fi
		CFLAGS="-O0 -ggdb -fno-omit-frame-pointer -Wunused -Wreturn-type -Wall"\
		./configure --enable-debug --enable-cassert --enable-tap-tests --prefix=$PGINSTALL &&\
		gmake -j2 &&\
		gmake install;
	} 2>&1 > /dev/null
}
export -f do_install

do_op()
{
	op=$1

	# Use either git branch name or 9.x.x version number
	if [ ! -z "$3" ]; then
		ver=$3
	else
		ver=$2
	fi
	PGDATA="$PGDIR/data/$ver";
	PGARCH="$PGDIR/arch/$ver";

	case $op in
	"i") # install
		origdir=`pwd`
		origver=''
		cd_to_source_or_git_branch $origdir origver $ver
		do_install $ver
		# if switched branches in git, $origver would be the old branch name
		if [ "$origver" != "origver" ]; then
			cd $PGDIR/git
			git checkout $origver
		fi
		cd $origdir
		;;

	"d") # initdb
		 # Set up data directory
		 rm -r $PGDATA;
		 rm -r $PGARCH;
		 # pg_ctl init -D $PGDATA -o "--data-checksums";
		 initdb -N -D $PGDATA;
		 mkdir -p $PGARCH
		 echo "# following settings installed by pg_console " >> $PGDATA/postgresql.conf;
		 echo "wal_level = hot_standby" >> $PGDATA/postgresql.conf;
		 echo "max_wal_senders = 3" >> $PGDATA/postgresql.conf;
		 echo "archive_mode = on" >> $PGDATA/postgresql.conf;
		 echo "archive_command = '/bin/true'" >> $PGDATA/postgresql.conf;
		 echo "logging_collector = on" >> $PGDATA/postgresql.conf;

		 echo "local   replication     $USER                                trust" >> $PGDATA/pg_hba.conf;
		 echo "host    all             all             192.168.56.0/24            trust" >> $PGDATA/pg_hba.conf;
		 ;;

	"s") # start server
		pg_ctl start -D $PGDATA;
		;;
	
	"x") # stop server
		pg_ctl stop -D $PGDATA -mf;
		;;
	
	"r") # restart server
		pg_ctl restart -D $PGDATA -mf;
		;;

	"e") # export current path - a noop as we do set_path
		;;

	"?")
		echo "Currently on '$ver' in git/";
	esac;
}
export -f do_op

set_path()
{
	branch=$1
	ver=$2
	if [ ! -z "$ver" ]; then
		PGINSTALL="$PGDIR/install/$ver";
	else
		PGINSTALL="$PGDIR/install/$branch";
	fi

	alreadyinpath="0";
	currentpgpath=`which postgres`;
	if [ "$?" == "0" ]; then
		# `which postgres` did return a postgres path; but is it the one we're
		# expecting (that is, of given version)?
		newpgpath="$PGINSTALL/bin/postgres";
		if [ "$currentpgpath" == "$newpgpath" ]; then
			alreadyinpath="1";
		fi;

		if [ "$alreadyinpath" == "0" ]; then
			PATH=$PGINSTALL/bin:$PATH;
			LD_LIBRARY_PATH=$PGINSTALL/lib:$PATH;
		else
			echo "===================";
			echo " Not altering PATH ";
			echo "===================";
		fi;
	# We have no postgres whatsoever; so add the current $PGINSTALL/bin to PATH
	else
		PATH=$PGINSTALL/bin:$PATH;
		LD_LIBRARY_PATH=$PGINSTALL/lib:$PATH;
	fi;

	export PATH
	export LD_LIBRARY_PATH
}
export -f set_path

check_op()
{
	if [ -z "$op" -o\
		 "$op" == "help" -o\
		 "$op" == "--help" -o\
		 "$op" == "-h" ] ||\
		 [ "$op" != "init" -a\
		 "$op" != "get" -a\
		 "$op" != "?" -a\
		 "$op" != "e" -a\
		 "$op" != "i" -a\
		 "$op" != "d" -a\
		 "$op" != "s" -a\
		 "$op" != "x" -a\
		 "$op" != "r" ]; then
		usage;
	fi
}
export -f check_op

if [ "$op" == "init" ]; then init; fi

op=$1
ver=$2
branch=''

check_op $op

if [ "$op" == "get" ]; then
	get_tarball $ver
	return 0;
fi

set_version branch $ver
if [ "$?" == 0 ]; then
	set_path $branch $ver
	do_op $op $branch $ver
fi
