#!/bin/bash
#
#

# Install gpiod so we can interact with gpio pins
apt install python3-gpiozero gpiod python3-lgpio -y


mkdir -p /opt/x729
echo '#!/usr/bin/python3

from gpiozero import LED
from gpiozero import Button
import time
import os

REBOOTPULSEMINIMUM=2
REBOOTPULSEMAXIMUM=6

# Hold BOOT GPIO Pin high
boot = LED(12)
boot.on()

shutdown = Button(5,pull_up=False)

print(shutdown.is_pressed)
while True:
  # Wait for a change
  shutdown.wait_for_press()
  pulseStart = time.time()
  while shutdown.is_pressed:
    #shutdown.wait_for_release()
    time.sleep(0.2)
    if time.time() - pulseStart > REBOOTPULSEMAXIMUM:
      # Power off if GPIO = 1 for more than REBOOTPULSEMAXIMUM seconds
      print("X729 Shutting down halting Rpi ...")
      os.system("poweroff")
      exit
  print("Released")
  if time.time() - pulseStart > REBOOTPULSEMINIMUM:
    # Reboot if GPIO = 1 for more than REBOOTPULSEMINIMUM seconds
    print("X729 Rebooting recycling Rpi ...")
    os.system("reboot")
    exit' > /opt/x729/pwr.py
chmod +x /opt/x729/pwr.py


echo '[Unit]
Description=x729 shutdown service
After=multi-user.target

[Service]
Type=simple
Restart=on-failure
ExecStart=python3 /opt/x729/pwr.py

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

from gpiozero import LED
from gpiozero import Button
import time

pl = Button(6)
dn = LED(26)

while True:
    seconds = 0
    while not pl.is_pressed:     # if port 6 == 1
      seconds += 1
      time.sleep(1)
      print ("---AC Power Loss OR Power Adapter Failure---")
      if seconds >= 5:
        print ("Recovery time over, shutdown")
        dn.off()
        time.sleep(4) #should this be longer?
        dn.on()
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

from gpiozero import PWMLED
import time
import subprocess

GPIO = 13

fan = PWMLED(GPIO)
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
        fan.value = 1                        # Set fan duty based on temperature, 100 is max speed and 0 is min speed or off.
    elif temp > 60:
        fan.value = 0.95
    elif temp > 50:
        fan.value = 0.90
    elif temp > 40:
        fan.value = 0.80
    elif temp > 32:
        fan.value = 0.60
    elif temp > 25:
        fan.value = 0.40
    else:
        fan.value = 0
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
