#!/bin/bash
#set -x
#------------------------------------------------------------------------------
# INFORMATION                                (C)opyleft Keld Norman, Marts 2022
#------------------------------------------------------------------------------
# VERSION | DATE            | Comment
# -----------------------------------------------------------------------------
# 0.1b    | 12 Marts, 2022  | First version by Keld Norman
# 1.0     | 12 Marts, 2022  | Added autoconfigurations functions
# -----------------------------------------------------------------------------
#
# This script can setup a messagequeue (MQ) for you and also at the same time
# send text to it constantly - You can exclude the hosting part if you just
# want to send text constantly to a MQ
# 
# You must redirect traffic from your external IP to this server tcp port 1883 
# if you want to expose this MQ server to the internet
# 
# Remember to allow this traffic in your local firewall (ufw or iptables)
# 
# You can test a connection to a MQ like this: 
# 
# READ:  mosquitto_sub -v -u 'user' -P 'password' -t '/#' -h 1.2.3.4
# WRITE: mosquitto_pub -d -u 'user' -P 'password' -t '/:' -m 'Knock Knock MQ'
#
# This script can be added to crontab after it has been executed manually.
# 
# To add it to crontab run:  crontab -e 
#
# Then just paste the following in:
#
# --- CUT --- BELOW --- HERE --- CUT --- BELOW --- HERE --- CUT --- BELOW --- 
#
#------------------------------------------------------------------------------
# Cron Syntaks:
#------------------------------------------------------------------------------
#
# * * * * *
# | | | | |_ Weekly 0-6 (0 Sunday)
# | | | |___ Monthly 1-12
# | | |_____ Day of month 1-31
# | |_______ Hour 0-23
# |_________ Minute 0-59
#
# 0 * * * * /here/is/the/script/mqtt_troll.sh >/dev/null 2>&1
#
# --- END -- CUT --- BELOW --- HERE --- END --- CUT --- BELOW --- HERE --- END
# 
# Then alter the path above to the script and remove the # in front of it 
#
#------------------------------------------------------------------------------
# Banner for the 1337'ishness
#------------------------------------------------------------------------------
if [ -t 1 ]; then  # Only show output when running in a terminal (for humans)
 clear
 cat << "EOF"

 MQ HONEY (Troll) POT 2022
  
       　  lﾆヽ
  　    　 |= | 
  　    　 |= | 
  　    　 |_ |
  　　/⌒|~ |⌒i-、
  　 /|　|　|　|'｜
  　｜(　(　(　( ｜
  　｜　　　　　 ｜
  　 ＼　　　　　/
  　　 ＼　　　 |

EOF
fi
#------------------------------------------------------------------------------
# HOST YOUR OWN MQ SERVER - VARIABLES
#------------------------------------------------------------------------------
START_OWN_MQ=1              # Set this to 1 to start our own server or 0 if not
START_MQ_SERVER_AT_BOOT=0   # Set this to 1 to autostart the MQ at boot
#------------------------------------------------------------------------------
MQ_HOST_IP="127.0.0.1"                # RUN Own MQ server on this IP 
MQ_USER="user"                        # Login with this user
MQ_PASS="YourSecretMQ_WritePassword"    # Login with this pass
MQ_PORT=1883                          # Use this MQ port
MQ_PATH="/"                           # Send messages to this queue
MQ_SERV_MAX_CONNECTIONS=42            # Max parallel connections to your MQ server
MQ_SERV_INTERFACE="lo"                # Host the MQ Server on this netcard
MQ_ACL_FILE="/etc/mosquitto/acl_file" # MQ servers access control list config file
MQ_PWD_FILE="/etc/mosquitto/pwd_file" # MQ servers password file
MQ_CFG_FILE="/etc/mosquitto/conf.d/local.conf"     # MQ servers config file (local)
MQ_SERV_LOGFILE="/var/log/mosquitto/mosquitto.log" # MQ servers logfile
#------------------------------------------------------------------------------
# TARGET MQ SERVER
#------------------------------------------------------------------------------
SEND_TO_THIS_MQ_SERVER="127.0.0.1"        # IP of MQ Server to send text to
SEND_TEXT="-------------------------------------------------------
We're no strangers to love
You know the rules and so do I
A full commitment's what I'm thinking of
You wouldn't get this from any other guy
\ 
I just wanna tell you how I'm feeling
Gotta make you understand
\ 
Never gonna give you up
Never gonna let you down
Never gonna run around and desert you
Never gonna make you cry
Never gonna say goodbye
Never gonna tell a lie and hurt you
\ 
We've known each other for so long
Your heart's been aching, but you're too shy to say it
Inside, we both know what's been going on
We know the game, and we're gonna play it"
#------------------------------------------------------------------------------
# SYSTEM VARIABLES
#------------------------------------------------------------------------------
PROGNAME=${0##*/}
LOCKFILE="/var/run/${PROGNAME%%.*}.pid"
LOGGER="/usr/bin/logger"
#------------------------------------------------------------------------------
# UTILITY
#------------------------------------------------------------------------------
MOSQUITTO_PASSWD="/usr/bin/mosquitto_passwd"  # Create username/pass for local MQ
MOSQUITTO_SUB="/usr/bin/mosquitto_sub"        # Util to Subscribe to a MQ
MOSQUITTO_PUB="/usr/bin/mosquitto_pub"        # Util to Publish to a MQ
NETSTAT="/bin/netstat"                        # Check network listening ports
#------------------------------------------------------------------------------
# CHECK IF RUNNING AS ROOT
#------------------------------------------------------------------------------
if [ ${EUID} -ne 0 ]; then
 if [ -t 1 ]; then 
  printf "\n ### ERROR - This script must have root persmissions (perhaps use sudo)\n\n"
 fi
 exit 1
fi
#------------------------------------------------------------------------------
# TRAP
#------------------------------------------------------------------------------
trap '
 # Remove lockfile when script exits
 if [ -e ${LOCKFILE} -a "$$" -eq "$(cat ${LOCKFILE} 2>/dev/null)" ]; 
  then rm ${LOCKFILE:-error} >/dev/null 2>&1
 fi
 # Print empty line
 if [ -t 1 ]; then 
  echo ""
 fi 
' EXIT 1
#------------------------------------------------------------------------------
# CHECK FOR LOCK FILE (ensures we only run one script at a time)
#------------------------------------------------------------------------------
PROCESS_FOUND=1
PROCESS_PID=1
# Check for lock file and process running
if [ -e ${LOCKFILE} ]; then # There is a lockfile
 OLD_PROCESS_PID="$(cat ${LOCKFILE:-error} 2>/dev/null )"
 PROCESS_FOUND="$(ps -p ${OLD_PROCESS_PID} -o pid|grep -cv PID)"
 if [ ${PROCESS_FOUND} -ne 0 ];then # Check if old process is running
  # The PID found in the lockfile is running
  if [ -t 1 ]; then 
   echo ""
   echo "### ERROR - Lockfile ${LOCKFILE} exist."
   echo "            This script is already running with PID: ${OLD_PROCESS_PID}"
   #${LOGGER} "Script ${0} failed - lock file exist - please investigate"
  fi
  exit 3
 else # The PID found in the lockfile is NOT running - Remove the lock file
  rm ${LOCKFILE:-error} > /dev/null 2>&1
 fi
fi
# Create new lock file
echo $$ > ${LOCKFILE}
#------------------------------------------------------------------------------
# PRE CHECKS
#------------------------------------------------------------------------------
# Select utils to check based on if we need to start a MQ server or not
if [ ${START_OWN_MQ:-0} -eq 1 ]; then 
 UTILS_NEEDED="${MOSQUITTO_PASSWD} ${MOSQUITTO_SUB} ${MOSQUITTO_PUB} ${NETSTAT}"
else
 UTILS_NEEDED="${MOSQUITTO_SUB} ${MOSQUITTO_PUB} ${NETSTAT}"
fi
# Check if needed utils is installed
for CHECK_UTIL in ${UTILS_NEEDED}; do
 if [ ! -x ${CHECK_UTIL} ]; then 
  if [ -t 1 ]; then  # Only show output when running in a terminal (for humans)
   printf "\n ### ERROR - Missing ${CHECK_UTIL}\n\n"
   printf " Run this to fix this error: \n\n"
   printf " apt-get update -qq -y && apt-get install mosquitto mosquitto-clients net-tools\n"
  fi
  exit 1
 fi
done
#------------------------------------------------------------------------------
function setup_mq_server {                                    # SETUP MQ SERVER
#------------------------------------------------------------------------------
 systemctl stop mosquitto.service >/dev/null 2>&1
 if [ -s /etc/mosquitto/mosquitto.conf ]; then 
   mv /etc/mosquitto/mosquitto.conf /etc/mosquitto/mosquitto.conf.org
   touch /etc/mosquitto/mosquitto.conf
 fi
 # Check if a password file for your MQ server exist
 if [ ! -s ${MQ_PWD_FILE} ]; then 
  touch ${MQ_PWD_FILE}
  chmod 644 ${MQ_PWD_FILE}
  chown root:root ${MQ_PWD_FILE}
 fi
 #-----------------------------------------------------
 # Ensure your user is in the MQ password file
 #-----------------------------------------------------
 ${MOSQUITTO_PASSWD} -c -b ${MQ_PWD_FILE} ${MQ_USER} ${MQ_PASS}
 #-----------------------------------------------------
 # Setup the MQ servers access control list config file
 #-----------------------------------------------------
 cat << "EOF" > ${MQ_ACL_FILE}
# Allow anonymous to read sys
topic read $SYS/#

# Allow anonymous to read
topic read /#

# Allow user named "user" to write
user user
topic /#
EOF
 #-----------------------------------------------------
 # Setup the MQ servers config file
 #-----------------------------------------------------
 cat << "EOF" > ${MQ_CFG_FILE}
pid_file /run/mosquitto/mosquitto.pid
log_timestamp true
set_tcp_nodelay true
log_type information
allow_anonymous false
connection_messages true
EOF
 echo "max_connections ${MQ_SERV_MAX_CONNECTIONS}"     >> ${MQ_CFG_FILE}
 echo "bind_interface ${MQ_SERV_INTERFACE}"            >> ${MQ_CFG_FILE}
 echo "log_dest file ${MQ_SERV_LOGFILE}"               >> ${MQ_CFG_FILE}
 echo "password_file ${MQ_PWD_FILE}"                   >> ${MQ_CFG_FILE}
 echo "acl_file ${MQ_ACL_FILE}"                        >> ${MQ_CFG_FILE}
 chmod 644 ${MQ_CFG_FILE}
 chown root:root ${MQ_CFG_FILE}
 #-----------------------------------------------------
 # Enable or disable MQ servers autostart at boot
 #-----------------------------------------------------
 AUTO_START_MQ_STATE=$(systemctl is-enabled mosquitto.service 2>&1|head -1)
 if [ ${START_MQ_SERVER_AT_BOOT:-0} -eq 1 ]; then  
  if [ "${AUTO_START_MQ_STATE,,}" == "disabled" ] ;then 
   if [ -t 1 ]; then
    printf "\n %-55s" "- Enabling autostart for mosquitto.service"
   fi
   ERROR=$(systemctl enable mosquitto.service 2>&1)
   ERROR_RC=$?
   if [ -t 1 ]; then
    if [ ${ERROR_RC} -eq 0 ]; then 
     echo "[OK]"
    else
     echo "[FAILED]"
     printf "\n ERROR: ${ERROR}\n\n"
    fi
   fi
  fi
 else
  if [ "${AUTO_START_MQ_STATE,,}" == "enabled" ] ;then 
   if [ -t 1 ]; then
    printf "\n %-55s" "- Disabling autostart for mosquitto.service"
   fi
   ERROR=$(systemctl disable mosquitto.service 2>&1)
   ERROR_RC=$?
   if [ -t 1 ]; then
    if [ ${ERROR_RC} -eq 0 ]; then 
     echo "[OK]"
    else
     echo "[FAILED]"
     printf "\n ERROR: ${ERROR}\n\n"
    fi
   fi
  fi
 fi
 systemctl start mosquitto.service >/dev/null 2>&1
}
#------------------------------------------------------------------------------
function start_mq_server {
#------------------------------------------------------------------------------
 if [ -t 1 ]; then
  printf " %-55s" "- Starting the mosquitto.service"
 fi
 ERROR=$(systemctl start mosquitto.service 2>&1)
 ERROR_RC=$?
 if [ ${ERROR_RC} -eq 0 ]; then 
  if [ -t 1 ]; then
   echo "[OK]"
  fi
 else
  if [ -t 1 ]; then
   echo "[FAILED]"
   printf "\n ERROR: ${ERROR}\n\n"
  fi
  exit 1
 fi
 sleep 3

}
#------------------------------------------------------------------------------
# PRE
#------------------------------------------------------------------------------
function check_mq_server_running {
 # systemctl is-active --quiet mosquitto.service && echo Service is running || echo Service is not running
 if [ $(${NETSTAT} -tupln |grep "${MQ_HOST_IP}:[1]883"|grep mosquitto|grep LISTEN|wc -l) -eq 0 ]; then 
  if [ -t 1 ]; then 
   printf "\n### WARNING - Mosquitto server not running (not listening on port 1883)!\n\n"
  fi
  start_mq_server
  sleep 3
  if [ $(${NETSTAT} -tupln |grep "${MQ_HOST_IP}:[1]883"|grep mosquitto|grep LISTEN|wc -l) -eq 0 ]; then 
   if [ -t 1 ]; then 
    printf "\n### ERROR - Mosquitto server not running (not listening on port 1883) - exiting!\n"
   fi
   exit 1
  fi
 fi
 #> ${MQ_SERV_LOGFILE:-/dev/null}
}
#------------------------------------------------------------------------------
function send_messages_to_mq {
#------------------------------------------------------------------------------
 printf "\n $(date) - MQ Transmitter started\n"
 COUNTER=1
 if [ -t 1 ]; then 
  printf "\n Full message send counter: "
 fi
 while true; do
  if [ -t 1 ]; then 
   printf "\r Ful message send counter: ${COUNTER}"
  fi
  while read LINE; do 
   ${MOSQUITTO_PUB} --username "${MQ_USER}" \
    --pw "${MQ_PASS}"                       \
    --message "${LINE}"                     \
    --topic "${MQ_PATH}"                    \
    --port ${MQ_PORT}                       \
    -h ${SEND_TO_THIS_MQ_SERVER}            # > /dev/null 2>&1
   sleep .3
  done <<< $(echo "${SEND_TEXT}")
  let COUNTER++
 done
}
#------------------------------------------------------------------------------
function check_setup {
#------------------------------------------------------------------------------
 if [ ${START_OWN_MQ:-0} -eq 1 ]; then
  setup_mq_server 
  check_mq_server_running 
 else
  systemctl stop mosquitto.service > /dev/null 2>&1
 fi
}
#------------------------------------------------------------------------------
# MAIN
#------------------------------------------------------------------------------
check_setup             # Check the settings of this script and if setup is ok
send_messages_to_mq     # Send text to the target MQ server
#------------------------------------------------------------------------------
# END OF SCRIPT
#------------------------------------------------------------------------------
