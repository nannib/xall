#!/bin/bash 
#
# Xall - by Nanni Bassetti - digitfor@gmail.com - http://www.nannibassetti.com 
# release: 1.5
#
# It mounts a DD/EWF image file or a block device and extracts all the allocated files, it extracts all deleted files,
# it makes a data carving on the unallocated space, then you have all ready for indexing with the program you prefer.
#

check_cancel()
{
	if [ $? -gt 0 ]; then
		exit 1
		break
	fi
}

if [ "$(id -ru)" != "0" ];then
	gksu -k -S -m "Enter root password to continue" -D "Xall requires root user priveleges." echo
fi

yad --title="XAll V.1.5" --width="300" --text "Welcome to XALL 1.5\n by Nanni bassetti\n http://www.nannibassetti.com\n The program ends with the message 'Operation succeeded!', so wait..."
check_cancel 



get_image_type()
{
    IMG_TYPE=$(img_stat ${imm[@]} | grep "Image Type:")
    IMG_TYPE=${IMG_TYPE#*:}
    case $IMG_TYPE in
        *raw) ITYPE=dd ;;
        *ewf) ITYPE=ewf ;;
    esac
    export ITYPE
}

mount_split_image()
{
    if [ ${#imm[@]} -gt 1 ] || [ "$ITYPE" = "ewf" ]
    then
    
        MNTPNT=$outputdir/tmp
        mkdir -p $MNTPNT
        xmount --in $ITYPE --out dd ${imm[@]} $MNTPNT
        imm=$MNTPNT/$(ls $MNTPNT|grep ".dd")
        yad --title="XAll V.1.5" --width="300" --text "Virtual dd image created at $imm\n"
        echo "Virtual dd image created at $imm" >&2
    else
        imm=$(readlink -f ${imm})
    fi
    export imm
}

while :
do
   outputdir="$(yad --file-selection --directory \
	--height 400 \
	--width 600 \
	--title "Insert destination directory mounted in rw " \
	--text " Select or create a directory (e.g. /media/sdb1/results) \n")"
	outputdir="$(echo $outputdir | tr "|" " ")"
check_cancel

   [[ "${outputdir:0:1}" = / ]] && { 
      [[ ! -d $outputdir ]] && mkdir $outputdir
      break
   }
   check_cancel
done

while :
do
   imm="$(yad --file-selection \
	--multiple \
	--height 400 \
	--width 600 \
	--title "Disk Image or Device Selection" \
	--text " Insert image file or dev (e.g. /dev/sda or disk.img)\nIf image is split, select all image segments (shift-click).\n")"
	imm="$(echo $imm | tr "|" " ")"
	
	get_image_type
	mount_split_image

imm=$imm

[[ -f $imm || -b $imm || -L $imm ]] && break
 
  check_cancel
done

check_af()
{
af="$(yad --form --image="dialog-question" \
	--title "Allocated files check" \
	--text "Do you want extract allocated files (y/n)\?" \
	--field="Answer:CB" '?!No!Yes!')"
check_cancel

af="$(echo $af | tr "|" " ")"

}

check_slack()
{
slack="$(yad --form --image="dialog-question" \
	--title "Slack space check" \
	--text "Do you want extract the slack space (y/n)\?" \
	--field="Answer:CB" '?!No!Yes!')"
check_cancel

slack="$(echo $slack | tr "|" " ")"

}

check_delf()
{
delf="$(yad --form --image="dialog-question" \
	--title "Deleted files check" \
	--text "Do you want recover deleted files? (y/n)\?" \
	--field="Answer:CB" '?!No!Yes!')"
check_cancel

delf="$(echo $delf | tr "|" " ")"

}

check_dcarv()
{
dcarv="$(yad --form --image="dialog-question" \
	--title "Data carving check" \
	--text "Do you want data carving (over the whole unallocated disk space)? (y/n)\?" \
	--field="Answer:CB" '?!No!Yes!')"
check_cancel

dcarv="$(echo $dcarv | tr "|" " ")"

}

check_af
check_slack
check_delf
check_dcarv

(! mmls $imm 2>/dev/null 1>&2) && {
   yad --title="XAll V.1.5" --text "The starting sector is '0'\n"
check_cancel 
   so=0
} || {

m=$(mmls -B $imm)  
p="$(yad --title="MMLS output" --width="600" --text "$m\n" \
--form \
 --field="Choose the partition number you need (e.g. 2,4,etc.)")"
 p="$(echo $p | tr "|" " ")"

echo $p | sed 's/,/\n/g' > $outputdir/parts_chosen.txt
mmls $imm | grep ^[0-9] | grep '[[:digit:]]'| awk '{print $3,$4}' > $outputdir/mmls.txt

DIR_FREESPACE=$outputdir/freespace    # Carved File's Folder
if [ $dcarv == "Yes" ] 
then 

[[ ! -d $DIR_FREESPACE ]] && mkdir $DIR_FREESPACE || {
rm -R $DIR_FREESPACE
mkdir $DIR_FREESPACE
}
# using photorec to carve inside the freespace
photorec /d $DIR_FREESPACE/ /cmd $imm fileopt,everything,enable,freespace,search | yad  --progress --pulsate --auto-close --text="Doing data carving..."  --width=250 --title="" --undecorated
fi


cn=0
cat $outputdir/parts_chosen.txt | while read lineparts
do
cl=$(( $lineparts+1 ))
cat $outputdir/mmls.txt | while read line
do
cn=$(( cn+1 ))
if [ "$cn" = "$cl" ] 
then
pts=$(echo $p | awk -F, '{print $cn}')
startsect0=$(echo $line | awk '{print $1}')
so=$(echo "$startsect0" | bc)
endsect0=$(echo $line | awk '{print $2}')
endsect=$(echo "$endsect0" | bc)
endoff=$(($endsect * 512 | bc))
	
  [[ ! -d $outputdir/$lineparts/ ]] && mkdir $outputdir/$lineparts/
HASHES_FILE=$outputdir/$lineparts/hashes.txt      # File output hash
DIR_DELETED=$outputdir/$lineparts/deleted        # Deleted File's Folder
DIR_SLACK=$outputdir/$lineparts/slackspace       # Slackspace's Folder
BASE_IMG=$outputdir/tmpdd/$lineparts            # mounting directory

allocated=$outputdir/$lineparts/Allocated

[[ ! -d  $allocated ]] && mkdir -p $allocated

[[ ! -d $BASE_IMG ]] && mkdir -p $BASE_IMG

off=$(( $so * 512 ))
# allocated files
if [ $af == "Yes" ] 
then 

cn=$(($cl))

tsk_recover -a -o $so $imm $allocated | yad  --progress --pulsate --auto-close --text="Copying allocated files..."  --width=250 --title="" --undecorated 

fi

# recovering the deleted files
if [ $delf == "Yes" ] 
then 
echo "recovering deleted files..."
[[ ! -d $DIR_DELETED ]] && mkdir -p $DIR_DELETED
tsk_recover -o $so $imm $DIR_DELETED | yad  --progress --pulsate --auto-close --text="Recovering deleted files..."  --width=250 --title="" --undecorated 
fi

# freespace and carving
if [ $dcarv == "Yes" ] 
then 

# taking off duplicates from carving directory
echo "taking off duplicates from carving directory..."
[[ $(ls $DIR_DELETED) ]]  && md5deep -r $DIR_DELETED/* > $HASHES_FILE
[[ $(ls $DIR_FREESPACE) ]] && md5deep -r $DIR_FREESPACE/* >> $HASHES_FILE
awk 'x[$1]++ { FS = " " ; print $2 }' $HASHES_FILE | xargs rm -rf
[[ -f $HASHES_FILE ]] && rm $HASHES_FILE | yad  --progress --pulsate --auto-close --text="Removing duplicates..."  --width=250 --title="" --undecorated 
fi

# extracting slackspace
if [ $slack == "Yes" ] 
then 
[[ ! -d $DIR_SLACK ]] && mkdir -p $DIR_SLACK
echo "Recovering the slackspace..."
blkls -s -o $so $imm > $DIR_SLACK/slackspace | yad  --progress --pulsate --auto-close --text="Recovering slackspace..."  --width=250 --title="" --undecorated 
fi

fi
done
done
rm $outputdir/parts_chosen.txt
rm $outputdir/mmls.txt
[[ "$ITYPE" = "ewf" ]] && umount $MNTPNT
[[ -d $MNTPNT ]] && rm  -r $MNTPNT
[[ -d $outputdir/tmpdd/ ]] && rm  -r $outputdir/tmpdd/
if [ $? == 0 ]; then
	yad  --width 600 \--title "XAll" --text "Operation succeeded!\n\nYour data are here  $outputdir"
else
	yad --width 600 --title "XAll" --text "XAll encountered errors.\n\nPlease check your settings and try again"
fi
echo "Done!";
}
