#!/bin/sh
set -e

aclocal
automake --add-missing
autoconf
rm -f config.cache
rm -rf autom4te.cache

# The original repository referenced an optional configure_ios.sh which is
# not included. Run it only when a caller supplies an executable copy.
if [ -x ./configure_ios.sh ]; then
    ./configure_ios.sh
fi
