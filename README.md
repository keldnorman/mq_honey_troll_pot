# A MQTT honey (troll) type of pot 
>MQTT is Message Queuing Telemetry Transport Protocol

The script **mqtt_honey.sh** will continuously send messages to a MQ server. This script is for people who wants to troll other people and robots "out there" that likes to scan
the interweb for port **tcp 1883**

If you want to setup your own MQ server then just alter the two variables to = 1
inside of the script called:
```
START_OWN_MQ=0                        # Set this to 1 to start our own server or 0 if not
START_MQ_SERVER_AT_BOOT=0             # Set this to 1 to autostart the MQ at boot
```
If you want to host the MQ server on an external IP then alter the two below variables:
```
MQ_HOST_IP="127.0.0.1"                # RUN Own MQ server on this IP 
MQ_SERV_INTERFACE="lo"                # Host the MQ Server on this netcard
```
To ensure nobody but you can write to your MQ server you should at a minimum alter the password variable:
```
MQ_USER="user"                        # Login with this user
MQ_PASS="YourSecretMQ_WritePassword"  # Login with this pass
```
The text the script send is specified in the variable SEND_TEXT 
```
SEND_TEXT="This is a text
\ <-- this is an empty line if you just add a space
and this is the last line"
```
The MQ server you send to is specified in the variable SEND_TO_THIS_MQ_SERVER
```
SEND_TO_THIS_MQ_SERVER="127.0.0.1"        # IP of MQ Server to send text to
```
## START THE SCRIPT
```
./mqtt_honey.sh # run mqtt_read.sh in another shell to read the MQ messages
```
TIP: Instructions for adding the script to crontab can be found inside of the script.

![mqtt_honey.sh](https://raw.githubusercontent.com/keldnorman/mq_honey_troll_pot/main/mqtt.gif)
