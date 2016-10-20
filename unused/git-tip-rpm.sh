#!/bin/sh
# USAGE: sh git-tip-rpm.sh spec-file target-name-prefix
# EXAMPLE: sh git-tip-rpm.sh SPECS/pg_rman94.spec pg_rman-1.3.2-pg94

rm -r ~/rpmbuild/
mkdir -p ~/rpmbuild/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}
git archive --format=tar --prefix=$2/ HEAD | gzip -9 > ~/rpmbuild/SOURCES/$2.tar.gz
rpmbuild -ba $1
