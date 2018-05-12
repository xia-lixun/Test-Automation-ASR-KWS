function [] = luxInit()

system('sdb root on'); % response: Switched to 'root' account mode 
system('sdb shell "mount -o remount,rw /"');
system('sdb shell "chmod -R 777 /opt/usr/media"');
