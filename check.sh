#!/bin/sh

#this code is tested un fresh 2015-11-21-raspbian-jessie-lite Raspberry Pi image
#by default this script should be located in two subdirecotries under the home

#sudo apt-get update -y && sudo apt-get upgrade -y
#sudo apt-get install git -y
#mkdir -p /home/pi/detect && cd /home/pi/detect
#git clone https://github.com/catonrug/activepresenter-detect.git && cd activepresenter-detect && chmod +x check.sh && ./check.sh

#check if script is located in /home direcotry
pwd | grep "^/home/" > /dev/null
if [ $? -ne 0 ]; then
  echo script must be located in /home direcotry
  return
fi

#it is highly recommended to place this directory in another directory
deep=$(pwd | sed "s/\//\n/g" | grep -v "^$" | wc -l)
if [ $deep -lt 4 ]; then
  echo please place this script in deeper directory
  return
fi

#set application name based on directory name
#this will be used for future temp directory, database name, google upload config, archiving
appname=$(pwd | sed "s/^.*\///g")

#set temp directory in variable based on application name
tmp=$(echo ../tmp/$appname)

#create temp directory
if [ ! -d "$tmp" ]; then
  mkdir -p "$tmp"
fi

#check if database directory has prepared 
if [ ! -d "../db" ]; then
  mkdir -p "../db"
fi

#set database variable
db=$(echo ../db/$appname.db)

#if database file do not exist then create one
if [ ! -f "$db" ]; then
  touch "$db"
fi

#check if google drive config directory has been made
#if the config file exists then use it to upload file in google drive
#if no config file is in the directory there no upload will happen
if [ ! -d "../gd" ]; then
  mkdir -p "../gd"
fi

#this link provides latest version
link=$(echo http://atomisystems.com/apdownloads/latest/ActivePresenter_setup.exe)

#set change log
changes=$(echo "http://atomisystems.com/updates/ActivePresenter/v5/releasenotes_v5.html")

#use spider mode to output all information abaout request
#do not download anything
wget -S --spider -o $tmp/output.log $link

#start basic check if the page even have the right content
grep -A99 "^Resolving" $tmp/output.log | grep "http.*ActivePresenter.*exe" > /dev/null
if [ $? -eq 0 ]; then

#take the first link which starts with http and ends with exe
url=$(grep -A99 "^Resolving" $tmp/output.log | sed "s/http/\nhttp/g" | sed "s/exe/exe\n/g" | grep "^http.*exe$" | head -1)

#calculate exact filename of link
filename=$(echo $url | sed "s/^.*\///g")

#check if this link is in database
grep "$filename" $db > /dev/null
if [ $? -ne 0 ]
then
echo new version detected!

echo Downloading $filename
wget $url -O $tmp/$filename -q
echo

#detect exact verison of ActivePresenter
version=$(pestr $tmp/$filename | grep -m1 -A1 "ProductVersion" | grep -v "ProductVersion")
echo $version | grep "[0-9\.]\+"
if [ $? -eq 0 ]; then
echo

versioncheck=$(echo "$version" | sed "s/^/ActivePresenter /")
echo version: $versioncheck viena atstarpe
echo changes: "$changes"

wget -qO- "$changes" | grep -A999 "<body>" > $tmp/releasenotes.log

echo looking for change log..
grep -B99 -m3 "<\/div>" $tmp/releasenotes.log | grep -A99 $version | grep -v "<\/h2>" | sed -e "s/<[^>]*>//g" | sed "s/^[ \t]*//g" | grep "[a-zA-Z]" | sed -e "/:/! s/^/- /" > $tmp/change.log

echo change log is:
cat $tmp/change.log
echo

#check if even something has been created
if [ -f $tmp/change.log ]; then
echo

#calculate how many lines log file contains
lines=$(cat $tmp/change.log | wc -l)
if [ $lines -gt 0 ]; then
echo change log found:
echo
cat $tmp/change.log
echo

echo creating sha1 checksum of file..
sha1=$(sha1sum $tmp/$filename | sed "s/\s.*//g")
echo

echo creating md5 checksum of file..
md5=$(md5sum $tmp/$filename | sed "s/\s.*//g")
echo

echo "$filename">> $db
echo "$version">> $db
echo "$md5">> $db
echo "$sha1">> $db
echo >> $db

#if google drive config exists then upload and delete file:
if [ -f "../gd/$appname.cfg" ]
then
echo Uploading $filename to Google Drive..
echo Make sure you have created \"$appname\" direcotry inside it!
../uploader.py "../gd/$appname.cfg" "$tmp/$filename"
echo
fi

#lets send emails to all people in "posting" file
emails=$(cat ../posting | sed '$aend of file')
printf %s "$emails" | while IFS= read -r onemail
do {
python ../send-email.py "$onemail" "ActivePresenter $version" "$url 
$md5
$sha1

`cat $tmp/change.log`"
} done
echo

else
#changes.log file has created but changes is mission
echo changes.log file has created but changes is mission
emails=$(cat ../maintenance | sed '$aend of file')
printf %s "$emails" | while IFS= read -r onemail
do {
python ../send-email.py "$onemail" "To Do List" "changes.log file has created but changes is mission: 
$version 
$changes "
} done
fi

else
#changes.log has not been created
echo changes.log has not been created
emails=$(cat ../maintenance | sed '$aend of file')
printf %s "$emails" | while IFS= read -r onemail
do {
python ../send-email.py "$onemail" "To Do List" "changes.log has not been created: 
$version 
$changes "
} done
fi

else
#version do not match version pattern
echo version do not match version pattern
emails=$(cat ../maintenance | sed '$aend of file')
printf %s "$emails" | while IFS= read -r onemail
do {
python ../send-email.py "$onemail" "To Do List" "Version do not match version pattern: 
$link "
} done
fi

else
echo $filename already in database
fi

else
#exe file not found
emails=$(cat ../maintenance | sed '$aend of file')
printf %s "$emails" | while IFS= read -r onemail
do {
python ../send-email.py "$onemail" "To Do List" "The following link do not longer retreive installer: 
$link"
} done
fi

#clean and remove whole temp direcotry
rm $tmp -rf > /dev/null
