#!/bin/bash
set -e

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <executable> <bundle_path>"
    exit
fi

RUN_SCRIPT='#!/bin/bash
THIS_DIR=$(DIRNAME=$(dirname "$0"); cd "$DIRNAME"; pwd)
THIS_FILE=$(basename "$0")
THIS_PATH="$THIS_DIR/$THIS_FILE"
RELEASE_DIR=$(mktemp -d)
trap "rm -rf $RELEASE_DIR" EXIT # delete released content on exit
# untar bundled resources to $RELEASE_DIR
tail -n +::num_lines_of_run_file:: "$THIS_PATH" | tar -x -C $RELEASE_DIR
$RELEASE_DIR/lib/ld-linux-x86-64.so.2 --library-path $RELEASE_DIR/lib $RELEASE_DIR/bin/::the_name_of_bundled_exe:: $@
exit $!
# Following is the content of the executable and its dependencies
'

EXE=$1
EXE_NAME=$(basename "$EXE")
BUNDLE_PATH=$2
BUNDLE_FILE=$BUNDLE_PATH/$EXE_NAME
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

mkdir -p $TEMP_DIR/lib
mkdir -p $TEMP_DIR/bin

cp $EXE $TEMP_DIR/bin
for f in $(ldd $1 | cut -d' ' -f3); do
    cp $f $TEMP_DIR/lib/
done
cp /lib64/ld-linux-x86-64.so.2 $TEMP_DIR/lib/

mkdir -p $BUNDLE_PATH
echo "$RUN_SCRIPT" | sed "s#::num_lines_of_run_file::#$(($(echo "$RUN_SCRIPT" | wc -l) + 1))#; s#::the_name_of_bundled_exe::#$EXE_NAME#" > $BUNDLE_FILE
tar -cv -C $TEMP_DIR . -O >> $BUNDLE_FILE
chmod +x $BUNDLE_FILE
