#!/bin/bash

UNIQUE_SEPARATOR="😎"
CONNECTION_LOCATION="./connections"



leave() {
    clear
    exit 0
}



print_help() {
    printf "Usage: ./ezbackup.sh [OPTION]\nOptional arguments:\n  -h  Display this text.\n  -v  Output version information.\n"

    leave
}



print_version() {
    printf "EZBackUp version 1.048596\n"

    leave
}



while getopts "hv" option; do
    case "$option" in
        'h') print_help ;;
        'v') print_version ;;
    esac
done



install_unique_separator() {
    TEMP_IFS=$IFS
    IFS=$UNIQUE_SEPARATOR
}



reinstate_previous_separator() {
    IFS=$TEMP_IFS
}



check_for_cancel_in_dialog() {
    if [ $? -eq 1 ] ; then
        main_menu
    fi
}



reset_connection_variable() {
    display=""
    address=""
    username=""
    password=""
    keyname=""
    locallocation=""
    remotelocation=""
}



download_and_decompress() {
    FOLDER_NAME_SCP="${FOLDER_NAME// /\\ }"

    if [ -z keyname ] ; then
        sshpass -p "$password" scp "$username@$address:$remotelocation/$FOLDER_NAME_SCP" "./"
    else
        scp -i "$keyname" "$username@$address:$remotelocation/$FOLDER_NAME_SCP" "./"
    fi

    tar --overwrite -C "$locallocation" -xf  "./$FOLDER_NAME" 

    rm "./$FOLDER_NAME"
}



list_folders() {
    if [ -z keyname ] ; then
        FILELIST=$(sshpass -p "$password" ssh "$username@$address" "cd "$remotelocation" && find ./* -maxdepth 0 -type f -iname '*.tar.gz' -printf '%f$UNIQUE_SEPARATOR'")
    else
        FILELIST=$(ssh -i "$keyname" "$username@$address" "cd "$remotelocation" && find ./* -maxdepth 0 -type f -iname '*.tar.gz' -printf '%f$UNIQUE_SEPARATOR'")
    fi

    install_unique_separator
    ARRAY_FILELIST=($FILELIST)
    reinstate_previous_separator

    FOLDER_COMMAND="dialog --stdout --ok-label \"Submit\" --menu \"Choose the back-up point to restore.\" 12 60 0 "

    j=0

    for i in "${ARRAY_FILELIST[@]}"
    do
        FOLDER_COMMAND+="$j \"$i\" "
        ((j++))
    done

    FOLDER_VALUE=$(eval $FOLDER_COMMAND)

    check_for_cancel_in_dialog

    FOLDER_NAME=${ARRAY_FILELIST[$FOLDER_VALUE]}

    download_and_decompress
}



compress_and_upload() {
    DATE=$(date '+%Y-%m-%d %H-%M-%S')
    tar -C "$locallocation" -czf "$DATE.tar.gz" $(ls "$locallocation")
    
    if [ -z keyname ] ; then
        sshpass -p "$password" scp "./$DATE.tar.gz" "$username@$address:$remotelocation"
    else
        scp -i "$keyname" "./$DATE.tar.gz" "$username@$address:$remotelocation"
    fi

    rm "./$DATE.tar.gz"
}



fix_connection_newline() {
    display="${display//[$'\t\r\n']}"
    address="${address//[$'\t\r\n']}"
}



connection_config() {
    VALUES=$(dialog --stdout --output-separator "$UNIQUE_SEPARATOR" --ok-label "Submit" \
    --form "Connection Settings" 13 60 0 \
    "Display Name" 1 1 "$display" 1 15 40 0 \
    "Address" 2 1 "$address" 2 15 40 0 \
    "Username" 3 1 "$username" 3 15 40 0 \
    "Password" 4 1 "$password" 4 15 40 0 \
    "Key Location" 5 1 "$keyname" 5 15 40 0 \
    "Local Location" 6 1 "$locallocation" 6 15 40 0 \
    "Remote Location" 7 1 "$remotelocation" 7 15 40 0)

    check_for_cancel_in_dialog

    install_unique_separator
    ARRAY_VALUES=($VALUES)
    reinstate_previous_separator

    display=${ARRAY_VALUES[0]}
    address=${ARRAY_VALUES[1]}
    username=${ARRAY_VALUES[2]}
    password=${ARRAY_VALUES[3]}
    keyname=${ARRAY_VALUES[4]}
}



load_connections() {
    pushd $CONNECTION_LOCATION
    CONNECTIONS=$(find ./* -maxdepth 0 -type f -iname "*.connection" -printf "%f$UNIQUE_SEPARATOR")
    popd

    install_unique_separator
    ARRAY_CONNECTIONS=($CONNECTIONS)
    reinstate_previous_separator
}



filename_selector() {
    FILENAME_DIALOG="dialog --stdout --ok-label \"Submit\" --inputbox \"Choose a filename to save your connection to.\" 12 60 0"
}



new_connection() {
    reset_connection_variable

    connection_config

    filename_selector

    TEXT_TO_SAVE="display=\"$display\"
    address=\"$address\"
    username=\"$username\"
    password=\"$password\"
    keyname=\"$keyname\"
    locallocation=\"$locallocation\"
    remotelocation=\"$remotelocation\""

    echo "$TEXT_TO_SAVE"
}



connection_selector() {
    load_connections

    CONNECTIONS_DIALOG="dialog --stdout --ok-label \"Submit\" --menu \"Choose the connection.\" 12 60 0 "

    d=1

    for i in "${ARRAY_CONNECTIONS[@]}"
    do
        . "$CONNECTION_LOCATION/$i"
        fix_connection_newline
        CONNECTIONS_DIALOG+="$d \"$display | $address\" "
        (($d++))
    done

    CONNECTIONS_VALUE=$(eval $CONNECTIONS_DIALOG)

    check_for_cancel_in_dialog
}



connection_menu() {
    CONNECTION_MENU_DIALOG=$(dialog --stdout --ok-label "Submit" \
    --menu "What would you like to do with your connections?" 12 60 0 \
    1 "New Connection" \
    2 "Edit Existing Connections" \
    3 "Delete a Connection")

    check_for_cancel_in_dialog
}



connection_config() {
    connection_menu

    if [ $CONNECTION_MENU_DIALOG -eq 1 ] ; then
        new_connection
    elif [ $CONNECTION_MENU_DIALOG -eq 2] ; then

    elif [ $CONNECTION_MENU_DIALOG -eq 3 ] ; then

    else
        main_menu
    fi
}



upload_config() {
    connection_config

    compress_and_upload
}



download_config() {
    connection_config

    list_folders
}



main_menu() {
    reset_connection_variable

    MENU_VALUES=$(dialog --stdout --ok-label "Submit" \
    --menu "Back up or restore?" 12 60 0 \
    1 "Back Up" \
    2 "Restore" \
    3 "Connection Editor" \
    4 "Exit")

    check_for_cancel_in_dialog


    if [ $MENU_VALUES -eq 1 ] ; then
        upload_config
    elif [ $MENU_VALUES -eq 4 ] ; then
        leave
    elif [ $MENU_VALUES -eq 2 ] ; then
        download_config
    elif [ $MENU_VALUES -eq 3 ] ; then
        connection_selector
    else
        main_menu
    fi
}



main_menu
