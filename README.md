# live-server-viewer
View the live chat in your server from this mobile app

The app is fully build in [https://flutter.dev](Flutter) which I've recently started using.

See a preview here: https://youtu.be/D8GrQC9RNpo


## Prerequisites

1. Have downloaded the sourcemod compiler and includes: https://www.sourcemod.net/downloads.php?branch=stable
2. Download additional includes for sourcemod (and install them in your server): https://forums.alliedmods.net/showthread.php?t=298024 , https://forums.alliedmods.net/showthread.php?t=67640
3. Have installed the Flutter SDK to compile to app: https://flutter.dev/docs/get-started/install

## Installation
1. Clone this repo with its submodules: `git clone --recurse-submodules https://github.com/Hexer10/live-server-viewer.git`.
2. Navigate to the `sourcemod` directory and compile the plugin `chattosocket.sp`.
3. Move the `chattosocket.smx` file to your plugin directory.

4. Navigate to the `flutter/assets` directory and edit the `config.yaml` file.
5. Navigate to the `flutter` directory and run `flutter build apk` and `flutter install` having your phone connected in debug mode.

