#!/bin/bash
#
#

# Install gpiod so we can interact with gpio pins
apt install gpiod python3-lgpio -y


mkdir -p /opt/x729
echo '#!/bin/bash

SHUTDOWN=GPIO5
BOOT=GPIO12

REBOOTPULSEMINIMUM=200
REBOOTPULSEMAXIMUM=600

# Ensure the background gpioset is killed if this script is killed or terminates
trap "trap - SIGTERM && kill -- -$$" SIGINT SIGTERM EXIT

# Hold BOOT GPIO Pin high
gpioset --mode=signal $(gpiofind $BOOT)=1 &

while [ 1 ]; do
  # Wait for a change
  gpiomon  -r -n 1  $(gpiofind $SHUTDOWN)
  while [ 1 ]; do
    shutdownSignal=$(gpioget $(gpiofind $SHUTDOWN))
    if [ $shutdownSignal = 0 ]; then
      # Return to waiting for change
      break
    else
      pulseStart=$(date +%s%N | cut -b1-13)
      while [ $shutdownSignal = 1 ]; do
        /bin/sleep 0.02
        if [ $(($(date +%s%N | cut -b1-13)-$pulseStart)) -gt $REBOOTPULSEMAXIMUM ]; then
          # Power off if GPIO = 1 for more than REBOOTPULSEMAXIMUM centiseconds
          echo "X729 Shutting down", SHUTDOWN, ", halting Rpi ..."
          poweroff
          exit
        fi
        shutdownSignal=$(gpioget $(gpiofind $SHUTDOWN))
      done
      if [ $(($(date +%s%N | cut -b1-13)-$pulseStart)) -gt $REBOOTPULSEMINIMUM ]; then
	# Reboot if GPIO = 1 for more than REBOOTPULSEMINIMUM centiseconds
        echo "X729 Rebooting", SHUTDOWN, ", recycling Rpi ..."
        reboot
        exit
      else
        # Return to waiting for change
	break
      fi
    fi
  done
done' > /opt/x729/pwr.sh
chmod +x /opt/x729/pwr.sh


echo '[Unit]
Description=x729 shutdown service
After=multi-user.target

[Service]
Type=simple
Restart=on-failure
ExecStart=/opt/x729/pwr.sh

[Install]
WantedBy=multi-user.target
' > /etc/systemd/system/x729-pwr.service

systemctl enable x729-pwr.service
systemctl start x729-pwr.service



read -p "Would you like to also install the power loss shutdown script? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]
then
  echo '#!/usr/bin/env python
import lgpio
import time

h = lgpio.gpiochip_open(0)
lgpio.gpio_claim_input(h, 6)

while True:
    seconds = 0
    while lgpio.gpio_read(h, 6):     # if port 6 == 1
      seconds += 1
      time.sleep(1)
      print ("---AC Power Loss OR Power Adapter Failure---")
      if seconds >= 5:
        lgpio.gpio_write(h, 26, 0)
        time.sleep(4)
        lgpio.gpio_write(h, 26, 1)
        time.sleep(1)
    time.sleep(1)' > /opt/x729/plsd.py

  echo '[Unit]
Description=x729 power loss service
After=multi-user.target
Conflicts=getty@tty1.service

[Service]
Type=simple
Restart=on-failure
ExecStart=python3 /opt/x729/plsd.py
StandardInput=tty-force

[Install]
WantedBy=multi-user.target' > /etc/systemd/system/x729-plsd.service

systemctl enable x729-plsd.service
systemctl start x729-plsd.service
fi


read -p "Would you like to also install PWM fan script? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]
then
  echo '#!/usr/bin/python3

import lgpio
import time
import subprocess

GPIO = 13
FREQ = 200

fan = lgpio.gpiochip_open(0)
lgpio.gpio_claim_output(fan,GPIO)
lgpio.tx_pwm(fan, GPIO, FREQ, 0)
def get_temp():
    output = subprocess.run(["vcgencmd", "measure_temp"], capture_output=True)
    temp_str = output.stdout.decode()
    try:
        return float(temp_str.split("=")[1].split("\'"'"'")[0])
    except (IndexError, ValueError):
        raise RuntimeError("Could not get temperature")

while 1:
    temp = get_temp()                        # Get the current CPU temperature
    #print(f"{temp}")
    if temp > 70:                            # Check temperature threshhold, in degrees celcius
        lgpio.tx_pwm(fan, GPIO, FREQ, 100)             # Set fan duty based on temperature, 100 is max speed and 0 is min speed or off.
    elif temp > 60:
        lgpio.tx_pwm(fan, GPIO, FREQ, 95)
    elif temp > 50:
        lgpio.tx_pwm(fan, GPIO, FREQ, 90)
    elif temp > 40:
        lgpio.tx_pwm(fan, GPIO, FREQ, 80)
    elif temp > 32:
        lgpio.tx_pwm(fan, GPIO, FREQ, 60)
    elif temp > 25:
        lgpio.tx_pwm(fan, GPIO, FREQ, 40)
    else:
        lgpio.tx_pwm(fan, GPIO, FREQ, 0)
    time.sleep(5)    ' > /opt/x729/pwm_fan_control.py

  echo '[Unit]
Description=x729 PWM fan service
After=multi-user.target
Conflicts=getty@tty1.service

[Service]
Type=simple
Restart=on-failure
ExecStart=python3 /opt/x729/pwm_fan_control.py
StandardInput=tty-force

[Install]
WantedBy=multi-user.target' > /etc/systemd/system/x729-fan.service

systemctl enable x729-fan.service
systemctl start x729-fan.service

fi
