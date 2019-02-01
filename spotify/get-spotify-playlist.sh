#!/bin/bash

set -e

usage() {
    echo "get-spotify-playlist.sh <playlist_path> <spotify_uri>"
    exit 1 
}

if [ $# -ne 2 ]; then
    usage
fi

path=$1
pl_id=${2##*:}

cred_file="credential.json"
client_id=$(cat $cred_file |jq -r '.client_id')
client_secret=$(cat $cred_file |jq -r '.client_secret')
cred=$(echo -n "$client_id:$client_secret" | base64 -w 0)
token=$(curl -s -X "POST" -H "Authorization: Basic $cred" -H "Accept: application/json" -d "grant_type=client_credentials" "https://accounts.spotify.com/api/token" 2>/dev/null | jq -r '.access_token')

full=$(curl -H "Authorization: Bearer $token" https://api.spotify.com/v1/playlists/$pl_id)
pl_url=$(echo $full | jq -r '.external_urls.spotify')
pl_name=$(echo $full | jq -r '.name')
pl_img=$(echo $full | jq -r '.images[0].url')

mkdir -p $path/$pl_name

if [ -e $path/$pl_name/tracks.lst ]; then 
    echo "clean up exisitng files under $path/$pl_name/"
    rm -f $path/$pl_name/*
fi

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
    printf "%02d. %s - %s\n" "$((track_idx+1))" "$artists" "$track_title" >> $path/$pl_name/tracks.lst)
done

curl -o $path/$pl_name/cover.jpg $pl_img
