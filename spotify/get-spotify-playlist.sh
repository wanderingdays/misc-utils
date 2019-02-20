#!/bin/bash

set -e

__cleanup()
{
    ARG=$?
#    echo "clean up tmp files"
    rm -f /tmp/resp_body
    if [ $ARG -ne 0 ]; then
	    if [ ! -z $pl_path ]; then
		    if [[ $pl_path == $path/static/playlists* ]]; then
			    echo "cleanup playlist directory $pl_path"
			    rm -rf $pl_path 
		    else
			    echo "playlist directory $pl_path looks fishy, remove it manually!"
		    fi
	    fi
    fi
    exit $ARG
}
trap __cleanup EXIT

# when successful the following directory and files will be created under <playlist_path>
# static/playlists/pl_name --- pl.ver           # playlist snapshot_id aka playlist version
#                          --- pl.link          # external URL to the playlist
#                          --- cover.jps        # cover image of the playlist 
#                          --- tracks.lst       # tracklist 

usage() {
    echo "get-spotify-playlist.sh <playlist_path> <spotify_uri>"
    exit 1 
}

get_cred() {
	client_id=$(cat $1 |jq -r '.client_id')
	client_secret=$(cat $1 |jq -r '.client_secret')
	cred=$(echo -n "$client_id:$client_secret" | base64 -w 0)
}

get_new_token() {
	rm -f $token_file
	get_cred $cred_file
	token=$(curl -s -X "POST" -H "Authorization: Basic $cred" -H "Accept: application/json" -d "grant_type=client_credentials" "https://accounts.spotify.com/api/token" 2>/dev/null | jq -r '.access_token')
	echo $token > $token_file
}

if [ $# -ne 2 ]; then
    usage
fi

path=${1%/}
pl_id=${2##*:}
spotify_util_dir=$(dirname "$(which $0)")
cred_file="$spotify_util_dir/credential.json"
token_file="$spotify_util_dir/spotify_token"

# 1.prepare token 
#TODO: check out how to do refresh token, before that, we renew token if it is > 10mins
if [ -e $token_file ]; then
	toke_age=$((($(date +%s) - $(date -r ~/misc-utils/spotify/spotify_token +%s))))
	if [ $toke_age -le 10 ]; then
#		echo "get token from file"
		token=$(cat $token_file)
	else
#		echo "token too old, get a new one"
		get_new_token
	fi
else
#	echo "get new token"
	get_new_token
fi

if [ -z $token ]; then
	echo "not able to retrieve token"
	rm -f $token_file
	exit 1
fi

get_playlist_detail() {
    rc=0
    status=$(curl -s -w "%{http_code}" \
        -o >(cat >/tmp/resp_body) \
        "$@"
    ) || rc="$?"

    if [ $status -ne 200 -o $rc -ne 0 ]; then
	    echo "get playlist detail failed status: $status rc: $rc"
	    exit 1
    fi
    pl_detail="$(cat /tmp/resp_body)"
}

# 2. get playlist detail
get_playlist_detail -H "Authorization: Bearer $token" https://api.spotify.com/v1/playlists/$pl_id
pl_url=$(echo $pl_detail| jq -r '.external_urls.spotify')
pl_name=$(echo $pl_detail| jq -r '.name')
pl_img=$(echo $pl_detail| jq -r '.images[0].url')
pl_snapshot=$(echo $pl_detail| jq -r '.snapshot_id')

# 3. check if the playlist is already downloaded and version is the same
pl_path=$path/"static/playlists"/$pl_name
mkdir -p $pl_path
if [ -e $pl_path/pl.ver ]; then
	old_pl_snapshot=$(cat $pl_path/pl.ver)
	if [ "$pl_snapshot" == "$old_pl_snapshot" ]; then
		pl_update=0
	else
		pl_update=1
	fi
else
	pl_update=1
fi

# 4. cleanup playlist if update is required
if [ $pl_update -eq 1 ]; then
	echo $pl_snapshot > $pl_path/pl.ver
	rm -f $pl_path/tracks.lst
	rm -f $pl_path/pl.link
	rm -f $pl_path/cover.jpg
fi

# 5. fetch playlist data if missing
if [ ! -e $pl_path/pl.link ]; then
	echo "${pl_url}" > $pl_path/pl.link
fi

if [ ! -e $pl_path/cover.jpg ]; then
	curl -s -o $pl_path/cover.jpg $pl_img
fi

if [ ! -e $pl_path/tracks.lst ]; then
	jq -r '.tracks.items|keys[]' <<< "$pl_detail" | while read track_idx; do
    		track=$(jq -r ".tracks.items[$track_idx].track" <<< "$pl_detail")
		track_title=$(jq -r '.name' <<< "$track")
    		artists=""
		jq -r '.artists|keys[]' <<< "$track" | (while read artist_idx; do
			if [ -z "$artists" ]; then
	   			artists="$(jq -r ".artists[$artist_idx].name" <<< "$track")"
	       		else
		   		artists="$artists, $(jq -r ".artists[$artist_idx].name" <<< "$track")"
       			fi
	    	done
		printf "%02d. %s - %s   \n" "$((track_idx+1))" "$artists" "$track_title" >> $pl_path/tracks.lst)
	done
fi

echo $pl_name
