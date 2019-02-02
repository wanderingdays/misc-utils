#!/bin/bash

set -e

__cleanup()
{
    ARG=$?
#    echo "clean up tmp files"
    rm -f /tmp/all_playlists*
    rm -f /tmp/pl_json
    exit $ARG
}
trap __cleanup EXIT

# when successful the following file will be created
# static/playlists/complete_lists

usage() {
    echo "get-all-playlists.sh <spotify_username> <output_filename>"
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

spotify_user=$1
pl_json=$2
spotify_util_dir=$(dirname "$(which $0)")
cred_file="$spotify_util_dir/credential.json"
token_file="$spotify_util_dir/spotify_token"
pls_base="/tmp/all_playlists_"

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

get_all_playlists() {
    rc=0
    pls="$pls_base$1"
    shift
    status=$(curl -s -w "%{http_code}" \
        -o >(cat > $pls) \
        "$@"
    ) || rc="$?"

    if [ $status -ne 200 -o $rc -ne 0 ]; then
        echo "get all playlist failed status: $status rc: $rc"
        exit 1
    fi
    pls_detail="$(cat $pls)"
}

# get first lists
pls_count=0
req="https://api.spotify.com/v1/users/$spotify_user/playlists"

while [ ! -z "$req" -a "$req" != "null" ]; do
	get_all_playlists $pls_count -X GET -H "Authorization: Bearer $token" $req
	req=$(echo $pls_detail| jq -r '.next')
	pls_count=$((pls_count+1))
done

total=$(echo $pls_detail| jq -r '.total')
i=0
echo "[" > /tmp/pl_json 
while [ -e $pls_base$i ]; do
    pls_detail=$(cat $pls_base$i)
    jq -r '.items|keys[]' <<< "$pls_detail" | (while read pl_idx; do
        pl_owner=$(jq -r ".items[$pl_idx].owner.display_name" <<< "$pls_detail")
        if [ "$pl_owner" = "$spotify_user" ]; then
            pl_id=$(jq -r ".items[$pl_idx].id" <<< "$pls_detail")
            pl_name=$(jq -r ".items[$pl_idx].name" <<< "$pls_detail")
            pl_ver=$(jq -r ".items[$pl_idx].snapshot_id" <<< "$pls_detail")
            if [ -z "$entry" ]; then
                if [ "$i" -ge "1" ]; then
                    echo "," >> /tmp/pl_json 
                fi
                entry="{\"name\":\"$pl_name\", \"id\":\"$pl_id\", \"version\":\"$pl_ver\"}"
            else
                entry=$entry,"{\"name\":\"$pl_name\", \"id\":\"$pl_id\", \"version\":\"$pl_ver\"}"
            fi
        fi
    done
    echo $entry >> /tmp/pl_json) 
    i=$((i+1))
done
echo "]" >> /tmp/pl_json 
jq . /tmp/pl_json > $pl_json 
