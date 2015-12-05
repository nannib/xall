# xall
This is a forensic data and file extractor from devices and image files. sudo ./xall_1.0.sh for running it. It mounts a DD/EWF image files or devices (e.g. /dev/sdb); it copies all the allocated files, it extracts all deleted files and the slackspace; It makes a data carving on the freespace only. You can choose each type of extraction. It uses a GUI made with YAD (Yet Another Dialog), so it's simple and fast to use.
You need:
Don't use blank spaces in the image filename!
YAD
XMount
The Sleuthkit (latest release)
Photorec
MD5Deep
