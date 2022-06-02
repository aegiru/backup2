#!/bin/bash

UNIQUE_SEPARATOR="😎"
CONNECTION_LOCATION="./connections"
KEY_LOCATION="./keys"



check_keys_folder() {
    if [ ! -d "$CONNECTION_LOCATION" ] ; then
        
    fi
}



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


options() {
    while getopts "hv" option; do
        case "$option" in
            'h') print_help ;;
            'v') print_version ;;
        esac
    done
}


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


reset_load() {
    CURRENTLY_LOADED=""
}



no_connection() {
    dialog --stdout --infobox "No connection. Please set up one first." 13 60

    check_for_cancel_in_dialog

    main_menu
}



download_and_decompress() {
    FOLDER_NAME_SCP="${FOLDER_NAME// /\\ }"

    if [ -z keyname ] ; then
        sshpass -p "$password" scp "$username@$address:$remotelocation/$FOLDER_NAME_SCP" "./"
    else
        scp -i "$KEY_LOCATION/$keyname" "$username@$address:$remotelocation/$FOLDER_NAME_SCP" "./"
    fi

    tar --overwrite -C "$locallocation" -xf  "./$FOLDER_NAME" 

    rm "./$FOLDER_NAME"
}



list_folders() {
    if [ -z keyname ] ; then
        FILELIST=$(sshpass -p "$password" ssh "$username@$address" "cd "$remotelocation" && find ./* -maxdepth 0 -type f -iname '*.tar.gz' -printf '%f$UNIQUE_SEPARATOR'")
    else
        FILELIST=$(ssh -i "$KEY_LOCATION/$keyname" "$username@$address" "cd "$remotelocation" && find ./* -maxdepth 0 -type f -iname '*.tar.gz' -printf '%f$UNIQUE_SEPARATOR'")
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



save_current_selection() {
    TEMP_LOADED=$CURRENTLY_LOADED
}



reinstate_previous_selection() {
    CURRENTLY_LOADED=$TEMP_LOADED
}



no_loaded() {
    NO_LOAD=$(dialog --stdout --msgbox "No connection selected! Please create and select a connection first." 13 60)

    check_for_cancel_in_dialog
}



check_if_loaded() {
    if [ -z "$CURRENTLY_LOADED" ] ; then
        no_loaded

        main_menu
    fi
}



backup_succ() {
    B_SUCC=$(dialog --stdout --msgbox "[ $DATE.tar.gz ] created!" 13 60)

    check_for_cancel_in_dialog
}



restore_succ() {
    R_SUCC=$(dialog --stdout --msgbox "[ $DATE.tar.gz ] removed!" 13 60)

    check_for_cancel_in_dialog
}



compress_and_upload() {
    DATE=$(date '+%Y-%m-%d %H-%M-%S')
    tar -C "$locallocation" -czf "$DATE.tar.gz" $(ls "$locallocation")
    
    if [ -z keyname ] ; then
        sshpass -p "$password" scp "./$DATE.tar.gz" "$username@$address:$remotelocation"
    else
        scp -i "$KEY_LOCATION/$keyname" "./$DATE.tar.gz" "$username@$address:$remotelocation"
    fi

    rm "./$DATE.tar.gz"
}



fix_connection_newline() {
    display="${display//[$'\t\r\n']}"
    address="${address//[$'\t\r\n']}"
    username="${username//[$'\t\r\n']}"
    password="${password//[$'\t\r\n']}"
    keyname="${keyname//[$'\t\r\n']}"
    locallocation="${locallocation//[$'\t\r\n']}"
    remotelocation="${remotelocation//[$'\t\r\n']}"
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



load_existing_connections() {
    pushd $CONNECTION_LOCATION
    CONNECTIONS=$(find ./* -maxdepth 0 -type f -iname "*" -printf "%f$UNIQUE_SEPARATOR")
    popd

    install_unique_separator
    ARRAY_CONNECTIONS=($CONNECTIONS)
    reinstate_previous_separator
}



filename_selector() {
    FILENAME_DIALOG=$(dialog --stdout --ok-label "Submit" --inputbox "Choose a filename to save your connection to." 12 60 0)

    check_for_cancel_in_dialog
}



save_connection() {
    TEXT_TO_SAVE="display=\"$display\"
address=\"$address\"
username=\"$username\"
password=\"$password\"
keyname=\"$keyname\"
locallocation=\"$locallocation\"
remotelocation=\"$remotelocation\""

    echo "$TEXT_TO_SAVE" > "$CONNECTION_LOCATION/$SAVE_FILENAME"
}



new_connection() {
    reset_connection_variable

    connection_config

    filename_selector

    SAVE_FILENAME=$FILENAME_DIALOG

    save_connection

    reset_connection_variable

    connection_choice
}



remove_connection() {
    rm "$CONNECTION_LOCATION/$CONNECTION_TO_DELETE"
}



load_connection() {
    . "$CONNECTION_LOCATION/$CURRENTLY_LOADED"

    fix_connection_newline
}



connection_selector() {
    load_existing_connections

    CONNECTIONS_DIALOG="dialog --stdout --ok-label \"Submit\" --menu \"Choose the connection.\" 12 60 0 "

    d=0

    for i in "${ARRAY_CONNECTIONS[@]}"
    do
        . "$CONNECTION_LOCATION/$i"
        fix_connection_newline

        LOADED_INDICATOR=" "

        if [[ "$i" == "$CURRENTLY_LOADED"  ]] ; then
            LOADED_INDICATOR="X"
        fi

        CONNECTIONS_DIALOG+="$d \"[$LOADED_INDICATOR] $display | $address\" "
        ((d++))
    done

    CONNECTIONS_VALUE=$(eval $CONNECTIONS_DIALOG)

    check_for_cancel_in_dialog

    CURRENTLY_LOADED=${ARRAY_CONNECTIONS[$CONNECTIONS_VALUE]}
}



use_connection() {
    connection_selector

    reset_connection_variable

    load_connection

    connection_choice
}



edit_connection() {
    save_current_selection

    connection_selector

    reset_connection_variable

    load_connection

    connection_config

    SAVE_FILENAME=$CURRENTLY_LOADED

    save_connection

    reinstate_previous_selection

    connection_choice
}



delete_connection() {
    save_current_selection
    
    connection_selector

    CONNECTION_TO_DELETE=$CURRENTLY_LOADED

    remove_connection

    reinstate_previous_selection

    connection_choice
}



connection_menu() {
    CONNECTION_MENU_DIALOG=$(dialog --stdout --ok-label "Submit" \
    --menu "What would you like to do with your connections?" 12 60 0 \
    1 "Choose a Connection" \
    2 "New Connection" \
    3 "Edit Existing Connections" \
    4 "Delete a Connection" \
    5 "Return to the Main Menu")

    check_for_cancel_in_dialog
}



connection_choice() {
    connection_menu

    if [ $CONNECTION_MENU_DIALOG -eq 1 ] ; then
        use_connection
    elif [ $CONNECTION_MENU_DIALOG -eq 2 ] ; then
        new_connection
    elif [ $CONNECTION_MENU_DIALOG -eq 3 ] ; then
        edit_connection
    elif [ $CONNECTION_MENU_DIALOG -eq 4 ] ; then
        delete_connection
    elif [ $CONNECTION_MENU_DIALOG -eq 5 ] ; then
        main_menu
    else
        main_menu
    fi
}



upload_config() {
    check_if_loaded

    compress_and_upload

    backup_succ

    main_menu
}



download_config() {
    check_if_loaded

    list_folders

    main_menu
}



main_menu() {
    MENU_VALUES=$(dialog --stdout --ok-label "Submit" \
    --menu "Back up or restore?" 12 60 0 \
    1 "Back Up" \
    2 "Restore" \
    3 "Connection Editor" \
    4 "Exit")

    check_for_cancel_in_dialog


    if [ $MENU_VALUES -eq 1 ] ; then
        upload_config
    elif [ $MENU_VALUES -eq 2 ] ; then
        download_config
    elif [ $MENU_VALUES -eq 3 ] ; then
        connection_choice
    elif [ $MENU_VALUES -eq 4 ] ; then
        leave
    else
        main_menu
    fi
}



begin() {
    reset_connection_variable

    reset_load

    main_menu
}



begin
