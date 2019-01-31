#!/bin/bash

cred_file="credential.json"
client_id=$(cat $cred_file |jq -r '.client_id')
client_secret=$(cat $cred_file |jq -r '.client_secret')
cred="$(echo -n "$client_id:$client_secret" | base64 -w 0)"
token=$(curl -v -s -X "POST" -H "Authorization: Basic $cred" -H "Accept: application/json" -d "grant_type=client_credentials" "https://accounts.spotify.com/api/token" 2>/dev/null | jq -r '.access_token')

fulllist=$(curl -v -H "Authorization: Bearer $token" https://api.spotify.com/v1/playlists/6EcUtQ0fz02ajr0E6ImMjP)
echo $fulllist | jq .

echo $fulllist | jq -r '.tracks.items[].track.name' | while read track ; do
#    echo $fulllist | jq -r '.tracks.items[]  | select(.track.name == $track) | .artists[].name'
    echo $track
done
#name=$(echo $fulllist | jq -r '.name')
#mkdir $name
#imgurl=$(echo $fulllist | jq -r '.images[0].url')
#curl -o ./$name/cover.jpg $imgurl
