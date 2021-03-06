#!/bin/bash -x
# $Id: build-httpd2.sh 58 2006-09-27 17:02:47Z marcus.ferreira $
#
# Apache 2.2.3 - RH ES 4
# Ago/2006
#


# export BERKELEY_DB="/usr/local/svn/BerkeleyDB"
# export LD_LIBRARY_PATH=$BERKELEY_DB/lib

DIR=./httpd-2.2.3
cd $DIR

cd srclib/apr 2>/dev/null

    ./configure                          \
        --prefix=$PREFIX/apache          \
        2>&1 | tee configure.my.log

    [ "$?" == "0" ] && make         | tee make.log
    [ "$?" == "0" ] && make test    | tee make.test.log
    [ "$?" == "0" ] && make install | tee make.install.log
