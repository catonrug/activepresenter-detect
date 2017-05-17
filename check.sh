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

if [ -f ~/uploader_credentials.txt ]; then
sed "s/folder = test/folder = `echo $appname`/" ../uploader.cfg > ../gd/$appname.cfg
else
echo google upload will not be used cause ~/uploader_credentials.txt do not exist
fi

#this link provides latest version
link=$(echo "https://atomisystems.com/download/")

#use spider mode to output all information abaout request
#do not download anything
wget -S --spider -o $tmp/output.log $link

#check if the whole page is even working. basic stuff
grep -A99 "^Resolving" $tmp/output.log | grep "HTTP.*200 OK"
if [ $? -eq 0 ]; then
echo

#take the first link which starts with http and ends with exe
url=$(wget -qO- "$link" | sed "s/\d034/\n/g" | grep -m1 "^http.*exe$")

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

echo creating sha1 checksum of file..
sha1=$(sha1sum $tmp/$filename | sed "s/\s.*//g")
echo

echo creating md5 checksum of file..
md5=$(md5sum $tmp/$filename | sed "s/\s.*//g")
echo

echo "$url"
echo "$filename"
echo "$version"
echo "$md5"
echo "$sha1"

echo "$url">> $db
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

https://drive.google.com/drive/folders/0B_3uBwg3RcdVUzBmR21zM082R3M/ 
"
} done
echo

else
#version do not match version pattern
echo version do not match version pattern
emails=$(cat ../maintenance | sed '$aend of file')
printf %s "$emails" | while IFS= read -r onemail
do {
python ../send-email.py "$onemail" "ActivePresenter" "Version do not match version pattern: 
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
python ../send-email.py "$onemail" "ActivePresenter" "The following link do not longer retreive good status code: 
$link"
} done
fi

#clean and remove whole temp direcotry
rm $tmp -rf > /dev/null
