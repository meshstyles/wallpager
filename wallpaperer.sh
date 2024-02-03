#!/bin/bash

################################################
#                    Usage                     #
################################################
# YOU MAY ONLY USE ONE FLAG AT THE TIME!       #
# -p / --page : Creates Album Page, uploads to #
#       server and index                       #
#   usage: ./wallpaperer.sh -p foldername      #
# -i / --index: Index the currently available  #
#       albums in list and gallery format      #
#   usage: ./wallpaperer.sh -i                 #
################################################

################################################
#                   Settings                   #
################################################
# max_size = max length of shortest side of a  #
#       preview. I'd recomend 480p!            # 
max_size="480"                                 #
# supported_types = file endings of supported  #
#       file types. if you are sure to only    #
#       include images you can consider to     #
#       just enter a glob match.               #
supported_types="png|jpg|webp|jpeg"            #
# server_side_index = automatically call       #
#       remote indexing galleries on remote    #
server_side_index="true"                       #
# server_path = path to the wallpapers dir     #
#       on the server [always from root]       #
server_path="/var/www/html/wallpapers"         #
# remote_script_path = path to script on       #
#       remote                                 #
remote_script_path="/home/user/.local/bin/wallpaperer.sh"
# remote = user and host comobo for rsync, scp #
#       and ssh                                #
remote="user@host"                             #
################################################

################################################
#                 RSS Settings                 #
################################################
feed_name="Wallpaper Feed"                     #
feed_description="List of Wallpaper updates"   #
domain="http://server/wallpapers/"             #
################################################

flag="$1"

SAVEIFS=$IFS   # Save current IFS
IFS='|'      # Change IFS to new line
exts=($supported_types)
IFS=$SAVEIFS 

#===================================================================
# wallpaperer
#===================================================================
if [[ "$flag" == '-p' ]] || [[ "$flag" == '--page' ]] ; then
    echo "[wallpager] running page-creator"
    folder="$2"
    # make sure folder exists
    if [ ! -d "$folder" ] ; then
        echo "[page-creator] folder \"$folder\" does not exist"
        exit 1
    fi
    # creating folder and adding boilerplate html
    echo "[page-creator] creating webpage for \"$folder\""
    cd "$folder"
    album_title=$(echo "$folder" | sed 's/\/$//' | rev | cut -d '/' -f 1 | rev | sed "s/[:|?]/-/g; s/–/-/g; s/[ ]*$//; s/^[ ]*//; s/ /-/g" | cut -c-200)

cat > "index.html" <<- EOM
<!DOCTYPE html>
<html lang="en">
    <head>
        <meta charset="UTF-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0" />
        <title>$album_title</title>
        <link rel="stylesheet" href="../css/addition.css" />
        <link rel="stylesheet" href="../css/bootstrap.cyborg.min.css" />
        <link rel="icon" type="image/x-icon" href="./img/favicon.png" />
    </head>
    <body>
        <div>
            <p class="text-center title-text-5">
                == <span class="blue">$album_title</span> ==
            </p>
            <!-- col are 12u wide -->
            <div class="container">
                <div class="row row-flex">
                <!-- album items -->
EOM

    types=""
    for ext in "${exts[@]}"
    do
        if [[ "$ext" != "" ]]; then
            types="$types *.$ext"
        fi
    done

    # obtain file list
    folder_name="preview_${max_size}"
    file_list_output=$(ls $types 2>/dev/null)
    mkdir "$folder_name"

    # creating an array of file list
    SAVEIFS=$IFS   # Save current IFS
    IFS=$'\n'      # Change IFS to new line
    file_list_array=($file_list_output)
    IFS=$SAVEIFS 

    # remove file list
    rm file.list

    # going through file array
    for filename in "${file_list_array[@]}"
    do
        echo "[page-creator] adding $filename"

        imagestats=$(identify "${filename}")
        imageres=($imagestats)
        imageres=$(echo ${imageres[-7]})

        res_x=$(echo "${imageres##*x}")
        res_y=$(echo "${imageres%%x*}")

        # setting data for page element creator
        file_full="./$filename"
        file_thumb="./$folder_name/$filename"

        # adding image to file list
        echo "${file_full#*./}" >> file.list

        # 720x and x720 are auto size determining
        if [[ "$res_x" -lt "$res_y" ]]; then
            # echo "horzontal"
            if [[ "$res_x" -gt "$max_size" ]]; then
                convert -geometry "x${max_size}" "$filename" "$file_thumb"
            # avoid creating converting images that are already to size
            else
                cp "$filename" "$file_thumb"
            fi
        elif [[ "$res_x" -ge "$res_y" ]]; then
            # echo "vertical/square"
            if [[ "$res_y" -gt "$max_size" ]]; then
                convert -geometry "${max_size}x" "$filename" "$file_thumb"
            # avoid creating converting images that are already to size
            else
                cp "$filename" "$file_thumb"
            fi
        else
            echo "send me the metadata for this image because the script is broken"
            exit 1;
        fi

cat >> "index.html" <<- EOM
                    <div class="col-md-6 col-sm-6 col-xs-12" >
                        <a href="$file_full">
                            <div class="content bg-border">
                                <div target="_blank" class="hov">
                                    <img
                                        class="center-block thumb"
                                        loading="lazy"
                                        src="$file_thumb"
                                    />
                                    <img
                                        class="full"
                                        src="$file_thumb"
                                    />
                                </div>
                            </div>
                        </a>
                    </div>
EOM

    done

    echo "[page-creator] done creating page for $album_title"

cat >> "index.html" <<- EOM
                <!-- album items end -->
                </div>
            </div>
        </div>
    </body>
</html>
EOM

    cd ..
    echo "[page-creator] transmitting data"
    if [[ "$(rsync 2>&1 --garbageoption)" == *"unknown option"* ]]; then
        rsync -uvrP "$folder" "${remote}:${server_path}/$folder/"
    else
        scp -r "$folder" "${remote}:${server_path}"
    fi

    prog=$0
    if [[ "$server_side_index" == "true" ]]; then
        echo "[page-creator] index remotely"
        ssh $remote $remote_script_path -i
    else
        echo "[page-creator] index albums locally"
        "$prog" '-i'
    fi

#===================================================================
# INDEXER
#===================================================================
elif [[ "$flag" == '-i' ]] || [[ "$flag" == '--index' ]] ; then
    echo "[indexer] stating indexing"

cd "$server_path"

cat > "table.html" <<- EOM
<!DOCTYPE html>
<html lang="en">
    <head>
        <meta charset="UTF-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0" />
        <title>Index of Galleries</title>
        <link rel="stylesheet" href="./css/addition.css" />
        <link rel="stylesheet" href="./css/bootstrap.cyborg.min.css" />
        <link rel="icon" type="image/x-icon" href="./img/favicon.png" />
    </head>
    <body>
        <p class="text-center title-text-5">
            == <span class="blue">Index - Gallery</span> ==
        </p>
        <div class="container">
            <table>
                <tr>
                    <th>Image</th>
                    <th>Title</th>
                  </tr>
EOM

cat > "index.html" <<- EOM
<!DOCTYPE html>
<html lang="en">
    <head>
        <meta charset="UTF-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0" />
        <title>Index of Galleries</title>
        <link rel="stylesheet" href="./css/addition.css" />
        <link rel="stylesheet" href="./css/bootstrap.cyborg.min.css" />
        <link rel="icon" type="image/x-icon" href="./img/favicon.png" />
    </head>
    <body>
        <p class="text-center title-text-5">
            == <span class="blue">Index - Gallery</span> ==
        </p>
        <!-- col are 12u wide -->
        <div class="container">
            <div class="row row-flex">
EOM

cat > "rss.xml" <<- EOM
<rss version="2.0">
    <channel>
        <title>$feed_name</title>
        <description>$feed_description</description>
        <link>$domain</link>
        <generator>wallpager</generator>
EOM

    folders=$(ls -t -d */)
    # creating an array of file list
    SAVEIFS=$IFS   # Save current IFS
    IFS=$'\n'      # Change IFS to new line
    folders=($folders)
    IFS=$SAVEIFS 

    # going through file array
    for folder in "${folders[@]}"
    do
        if [ -f "$folder/index.html" ] ; then
            echo "[indexer] indexing $folder"
            files=""
            for ext in "${exts[@]}"
            do
                if [[ "$ext" != "" ]]; then
                    files="$files $folder*.$ext"
                fi
            done
            image=$( ls $files 2>/dev/null | head -n 1 )
            foldername="${folder%/*}"

cat >> "table.html" <<- EOM
                <tr>
                  <td>
                      <img
                          class="center-block rthumb"
                          loading="lazy"
                          align="left"
                          src="./$image"
                      />
                  </td>
                  <td>
                      <a href="./$folder" class="title-text-3" >$foldername</a>
                  </td>
                </tr>
EOM

cat >> "index.html" <<- EOM
                <div class="col-md-4 col-sm-6 col-xs-12">
                    <a href="./$folder">
                        <div class="content bg-border">
                            <div target="_blank" class="hov">
                                <img
                                    class="center-block gthumb"
                                    loading="lazy"
                                    src="./$image"
                                />
                            </div>
                        </div>
                        <p class="text-center">
                            <a href="./$folder" class="title-text-2"
                                >$foldername</a
                            >
                        </p>
                    </a>
                </div>
EOM

foldernoslash="${folder%\/*}"

cat >> "rss.xml" <<- EOM
        <item>
            <title>$foldernoslash</title>
            <description>Image Gallery $foldernoslash</description>
            <link>$domain$folder</link>
        </item>
EOM
        else
            echo "[indexer] no index was found skipping $folder"
        fi
    done

cat >> "table.html" <<- EOM
            </table>
        </div>
    </body>
</html>
EOM

cat >> "index.html" <<- EOM
            </div>
        </div>
    </body>
</html>
EOM

cat >> "rss.xml" <<- EOM
    </channel>
</rss>
EOM

else
    echo "[wallpager] not matching flag found"
    exit 1
fi
