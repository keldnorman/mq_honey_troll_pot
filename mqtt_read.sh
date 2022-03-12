#!/bin/bash
clear
#------------------------------------------------------------------------------
# INFORMATION                                (C)opyleft Keld Norman, Marts 2022
#------------------------------------------------------------------------------
#
# Script to read data from a messagequeue
#
#-----------------------------------
# Banner for the 1337'ishness
#-----------------------------------
cat << "EOF"

 MQTT QUEUE READER SCRIPT 2022

       __..._   _...__
  _..-"      `Y`      "-._
  \ Once upon | Someone   /
  \\  a time..|  read a  //
  \\\         |   MQ..  ///
   \\\ _..---.|.---.._ ///
    \\`_..---.Y.---.._`//
     '`               `'
EOF
#------------------------------------------------------------------------------
# VAR
#------------------------------------------------------------------------------
SERVER="127.0.0.1"                       # MQTT Server to post to
MQTT_PORT=1883                           # Use this MQTT port
#------------------------------------------------------------------------------
# PRE
#------------------------------------------------------------------------------
if [ ! -x /usr/bin/mosquitto_sub ]; then 
 printf "\n ### ERROR - Missing /usr/bin/mosquitto_sub\n\n"
 printf " Fix it by running: apt-get update -qq -y && apt-get install mosquitto-clients\n\n"
 exit 1
fi
#------------------------------------------------------------------------------
# MAIN
#------------------------------------------------------------------------------
printf "$(date) - Connecting to MQ@${SERVER}\n"
printf -- "------------------------------------------------------------------\n"
printf "Running: /usr/bin/mosquitto_sub --host ${SERVER} --port ${MQTT_PORT} -v --topic '/#'\n\n"
/usr/bin/mosquitto_sub --host ${SERVER} --port ${MQTT_PORT} -v --topic '/#'
#------------------------------------------------------------------------------
# END OF SCRIPT
#------------------------------------------------------------------------------
