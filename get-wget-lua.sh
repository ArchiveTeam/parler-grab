#!/usr/bin/env bash
#
# This script clones and compiles wget-lua.
#

# first, try to detect gnutls or openssl
CONFIGURE_SSL_OPT=""
if builtin type -p pkg-config &>/dev/null
then
  if pkg-config gnutls
  then
    echo "Compiling wget with GnuTLS."
    CONFIGURE_SSL_OPT="--with-ssl=gnutls"
  elif pkg-config openssl
  then
    echo "Compiling wget with OpenSSL."
    CONFIGURE_SSL_OPT="--with-ssl=openssl"
  fi
fi

if ! zstd --version | grep -q 1.4.4
then
  echo "Need version 1.4.4 of libzstd-dev and zstd"
  exit 1
fi

rm -rf get-wget-lua.tmp/
mkdir -p get-wget-lua.tmp

cd get-wget-lua.tmp

git clone https://github.com/archiveteam/wget-lua.git

cd wget-lua
git checkout v1.20.3-at

#echo -n 1.20.3-at-lua | tee ./.version ./.tarball-version > /dev/null

if ./bootstrap && ./configure $CONFIGURE_SSL_OPT --disable-nls && make && src/wget -V | grep -q lua
then
  cp src/wget ../../wget-at
  cd ../../
  echo
  echo
  echo "###################################################################"
  echo
  echo "wget-lua successfully built."
  echo
  ./wget-at --help | grep -iE "gnu|warc|lua"
  rm -rf get-wget-lua.tmp
  exit 0
else
  echo
  echo "wget-lua not successfully built."
  echo
  exit 1
fi
