# misc-utils
- spotify/get-all-playlists.sh:
  gets all public playlists owned by user. Output file is stored in json for easy parsing using jq.
- spotify/get-spotify-playlist.sh:    
  Gets playlist and playlist's image, both are saved under the provided directory. 
  To get playlist's URI, go to spotify and right click the PUBLIC playlist to share. 
  Select "Copy Spotify URI".   
  To run the script, you need to place credential.json at the same path as this script. 
  The content of the credential.json is:   
  `{   
    "client_id":"your_app's_client_id",   
    "client_secret":"your_app's_client_secret"   
  }`   
  Please see [Spotify for Developers](https://developer.spotify.com/) for instructions 
  on how to create an application and obtain the client id & secret.
