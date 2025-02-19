#!/bin/sh
set -o pipefail
set -o xtrace
set -e

CUR_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )
TMP_DIR=${CUR_DIR}/libcxx.tmp

mkdir ${TMP_DIR}
cd ${TMP_DIR} 

git clone -b release/16.x --single-branch --depth=1 https://github.com/llvm/llvm-project.git

cd llvm-project

clang++ -c \
  -arch arm64 -arch x86_64 \
  -std=c++2b \
  -fvisibility=hidden \
  -flto \
  -Os \
  -mmacosx-version-min=10.15 \
  -DNDEBUG \
  libcxx/src/memory_resource.cpp

libtool -static -o libcxxbackport.a memory_resource.o

cd ./../../

rm -rf ./lib/
mkdir lib
cp ./libcxx.tmp/llvm-project/libcxxbackport.a ./lib/
rm -rf ${TMP_DIR}
