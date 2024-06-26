#!/bin/sh
if [ "${DISPLAY+set}" != set ]; then
  # TODO: assuming :0 here is fragile
  export DISPLAY=:0.0
fi

xhost +si:localuser:root
xhost +si:localuser:jenkins
xhost +si:localuser:ubuntu  # for using with ros_buildfarm code
