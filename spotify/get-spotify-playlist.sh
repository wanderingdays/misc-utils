#!/bin/bash

cred_file="credential.json"
client_id=$(cat $cred_file |jq -r '.client_id')
client_secret=$(cat $cred_file |jq -r '.client_secret')
cred=$(echo -n "$client_id:$client_secret" | base64 -w 0)
token=$(curl -v -s -X "POST" -H "Authorization: Basic $cred" -H "Accept: application/json" -d "grant_type=client_credentials" "https://accounts.spotify.com/api/token" 2>/dev/null | jq -r '.access_token')

full=$(curl -v -H "Authorization: Bearer $token" https://api.spotify.com/v1/playlists/6EcUtQ0fz02ajr0E6ImMjP)
pl_name=$(echo $full | jq -r '.name')
pl_img=$(echo $full | jq -r '.images[0].url')

jq -r '.tracks.items|keys[]' <<< "$full" | while read track_idx; do
    track=$(jq -r ".tracks.items[$track_idx].track" <<< "$full")
    track_title=$(jq -r '.name' <<< "$track")
    artists=""
    jq -r '.artists|keys[]' <<< "$track" | (while read artist_idx; do
	 if [ -z "$artists" ]; then
             artists="$(jq -r ".artists[$artist_idx].name" <<< "$track")"
         else
             artists="$artists, $(jq -r ".artists[$artist_idx].name" <<< "$track")"
	 fi
    done
    echo "%02d. %s - %s\n" $track_idx $artists $track_title >> $pl_name.lst)
done
#mkdir $name
#curl -o ./$name/cover.jpg $imgurl
