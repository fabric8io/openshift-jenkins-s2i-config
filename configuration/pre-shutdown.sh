#!/bin/bash

# script using Jenkins API to check if it is idle
IS_IDLE=$(curl -s -H "Authorization: Bearer $(cat /run/secrets/kubernetes.io/serviceaccount/token)" http://localhost:8080/computer/api/json  | sed 's/\\\\\//\//g' | sed 's/[{}]//g' | awk -v k="text" '{n=split($0,a,","); for (i=1; i<=n; i++) print a[i]}' | sed 's/\"\:\"/\|/g' | sed 's/[\,]/ /g' | sed 's/\"//g' | grep -w idle | cut -f2 -d":")

RETRY=0
THREE_HRS=108

while [ $IS_IDLE == 'false' ] && [ $RETRY !=  $THREE_HRS ] 
do
    echo 'Waiting for Jenkins to become idle'
    sleep 10
    ((RETRY++))
    IS_IDLE=$(curl -s -H "Authorization: Bearer $(cat /run/secrets/kubernetes.io/serviceaccount/token)" http://localhost:8080/computer/api/json  | sed 's/\\\\\//\//g' | sed 's/[{}]//g' | awk -v k="text" '{n=split($0,a,","); for (i=1; i<=n; i++) print a[i]}' | sed 's/\"\:\"/\|/g' | sed 's/[\,]/ /g' | sed 's/\"//g' | grep -w idle | cut -f2 -d":")
done

if [ $RETRY ==  $THREE_HRS ]
then
    echo 'Timeout exceeded waiting for Jenkins jobs to stop, stopping pod.'
else 
    echo 'Jenkins is idle, stopping pod.'
fi

echo 'test 4'
