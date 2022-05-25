#!/bin/bash

UNIQUE_SEPARATOR="😎"

print_help() {
    printf "Usage: ./ezbackup.sh [OPTION]\nOptional arguments:\n  -h  Display this text.\n  -v  Output version information.\n"

    exit 0
}

print_version() {
    printf "EZBackUp version 1.048596\n"

    exit 0
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

display=""
address="143.47.181.131"
username="ubuntu"
password="uwu"
keylocation="./shit.key"
locallocation="./"
remotelocation="~/backup/"

download_and_decompress() {
    FOLDER_NAME_SCP="${FOLDER_NAME// /\\ }"

    if [ -z keylocation ] ; then
        sshpass -p "$password" scp "$username@$address:$remotelocation/$FOLDER_NAME_SCP" "./"
    else
        scp -i "$keylocation" "$username@$address:$remotelocation/$FOLDER_NAME_SCP" "./"
    fi

    tar --overwrite -C "$locallocation" -xf  "./$FOLDER_NAME" 

    rm "./$FOLDER_NAME"
}

list_folders() {
    if [ -z keylocation ] ; then
        FILELIST=$(sshpass -p "$password" ssh "$username@$address" "cd "$remotelocation" && find ./* -maxdepth 0 -type f -iname '*.tar.gz' -printf '%f$UNIQUE_SEPARATOR'")
    else
        FILELIST=$(ssh -i "$keylocation" "$username@$address" "cd "$remotelocation" && find ./* -maxdepth 0 -type f -iname '*.*' -printf '%f$UNIQUE_SEPARATOR'")
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
    
    if [ -z keylocation ] ; then
        sshpass -p "$password" scp "./$DATE.tar.gz" "$username@$address:$remotelocation"
    else
        scp -i "$keylocation" "./$DATE.tar.gz" "$username@$address:$remotelocation"
    fi

    rm "./$DATE.tar.gz"
}

connection_config() {
    VALUES=$(dialog --stdout --output-separator "$UNIQUE_SEPARATOR" --ok-label "Submit" \
    --form "Connection Settings" 13 60 0 \
    "Display Name" 1 1 "$display" 1 15 40 0 \
    "Address" 2 1 "$address" 2 15 40 0 \
    "Username" 3 1 "$username" 3 15 40 0 \
    "Password" 4 1 "$password" 4 15 40 0 \
    "Key Location" 5 1 "$keylocation" 5 15 40 0 \
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
    keylocation=${ARRAY_VALUES[4]}
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
    MENU_VALUES=$(dialog --stdout --ok-label "Submit" \
    --menu "Back up or restore?" 12 60 0 \
    1 "Back Up" \
    2 "Restore" \
    3 "Exit")

    check_for_cancel_in_dialog


    if [ $MENU_VALUES -eq 1 ] ; then
        upload_config
    elif [ $MENU_VALUES -eq 3 ] ; then
        exit 0
    elif [ $MENU_VALUES -eq 2 ] ; then
        download_config
    else
        main_menu
    fi
}

main_menu