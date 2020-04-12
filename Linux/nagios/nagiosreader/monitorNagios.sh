#!/bin/bash
SOURCE="/var/cache/nagios3/status.dat"
DB01IP=$(</etc/db01IP)
while :
do
	inotifywait -q --format '%w' $SOURCE | while read FILE
	do
  		echo "$(date) - Detected change to $FILE" 
  		XML=`php -f statusXML.php`
  		echo $XML > status.xml
  		echo "$(date) - Doing XML POST curl to $DB01IP"
  		curl -m 3 -v -H "Content-Type: application/xml" -X POST --data "@status.xml" http://$DB01IP:8001/nagiosstatus/PostNagiosStatus
	done
	sleep 2
done
