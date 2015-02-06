#!/bin/bash

# TODO(mcgrathr): consolidate this with glibc-x86_64-linux.sh,
# either using a shared common script of subroutines or a single
# script with arguments

set -x
set -e
set -u

echo @@@BUILD_STEP sync@@@

root_dir=$(pwd)
src_dir="${root_dir}/glibc"
build_dir="${root_dir}/build-i686-linux"

if [ -d ${src_dir} ]; then
  cd ${src_dir}
  git pull
  cd ${root_dir}
else
  git clone git://sourceware.org/git/glibc.git ${src_dir}
fi


echo @@@BUILD_STEP configure@@@

mkdir -p $build_dir
cd $build_dir
${src_dir}/configure --prefix=/usr --enable-add-ons \
  CC='gcc -m32' CXX='g++ -m32' --build=i686-linux

num_jobs=$(getconf _NPROCESSORS_ONLN)


echo @@@BUILD_STEP make@@@

make -j${num_jobs} -k

echo @@@BUILD_STEP check@@@

make -j${num_jobs} -k check