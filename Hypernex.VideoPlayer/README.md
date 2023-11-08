# Hypernex.VideoPlayer

By **200Tigersbloxed**

A VideoPlayer for Hypernex that syncs across the server (if you want it to)

## VideoPlayerClient.lua

The LocalScript for the video player. To use it, attach it to a LocalScript on which a VideoPlayer and valid Controls are.

### Config

**NetworkSync** (Default: **true**) - Defines whether or not to sync the VideoPlayer over the network

**ShareControls** (Default: **true**) - Defines whether or not to allow controls to be shared by default. **This should match the server settings!**

**StartingURL** (Default: *empty string*) - The default video to display. Leave empty if you don't want to have one

## VideoPlayerServer.lua

The ServerScript for syncing the video player. Optionally if you plan to not use NetworkSync.

### Config

**ShareControls** (Default: **true**) - Defines whether or not to allow controls to be shared by default. **This should match the client settings!**