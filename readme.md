# Wallpaper page tool

This is a simple but powerful script that can handle image galleries.
It's mainly written to be used for wallpapers it should work just fine for everything else.
There is no pagination on the index, so this tool is maybe not the best if add new galleries daily.

## stack

-   a webserver (tested with Apache but anything else should be fine)
-   bash (tested on Debian but probably works with another Linux distro, (old) MacOS or BSD)
-   imagemagick
-   scp or rsync

## features

-   Galleries
-   Gallery index
-   RSS
-   File list (as cheap API replacement)
-   Settings (in script file)

## prep
Please change the settings in the script file before pushing it on the server.
Note the script does not transfer the `img/` and `css/` folder so these need to be uploaded manually to the server.

## usage

./wallpaperer.sh -p `foldername`  
to create a gallery page and upload it and remotely/localy update all files

./wallpaperer.sh -i
update just the index and the RSS feed locally.
