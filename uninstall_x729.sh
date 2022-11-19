#!/bin/bash
#remove x729 old installtion
sudo sed -i '/x729/d' /etc/rc.local
sudo sed -i '/ds1307/d' /etc/rc.local
sudo sed -i '/hwclock/d' /etc/rc.local
sudo sed -i '/ds1307/d' /etc/modules
sudo sed -i '/x729/d' ~/.bashrc

sudo rm /home/pi/x729*.py -rf
sudo rm /usr/local/bin/x729softsd.sh -f
sudo rm /etc/x729pwr.sh -f
#echo 'please remove old python file such x728xx.py on /home/pi/ fold'
