#!/bin/bash

cred_file="credential.json"
client_id=$(cat $cred_file |jq -r '.client_id')
echo $client_id
client_secret=$(cat $cred_file |jq -r '.client_secret')
echo $client_secret
cred="$(echo -n "$client_id:$client_secret" | base64 -w 0)"
echo $cred
token=$(curl -s -v -X "POST" -H "Authorization: Basic $cred" -H "Accept: application/json" -d "grant_type=client_credentials" "https://accounts.spotify.com/api/token" 2>/dev/null | jq -r '.access_token')
echo $token


