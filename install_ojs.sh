#!/bin/sh

HOST=$1  # First argument: Host IP
DB_NAME=$2  # Second argument: Database name
TOOL_VERSION=$3  # Third argument: Tool version

if [ -z "$HOST" ] || [ -z "$DB_NAME" ] || [ -z "$TOOL_VERSION" ]; then
    echo "Usage: $0 <server_ip> <database_name> <tool_version>"
    echo "Example:"
    echo "'./install_ojs.sh 127.0.0.1 test_db 3.4.0-8'"
    exit 1
fi

echo "OJS SERVICE INSTALLATION"
echo "Author: yorranan"
echo "-----------------------"
echo "The recommendation is to run this script in your user directory with administrator rights"
echo "Do not forget to check the OJS version requirements before starting"
echo "This is a definitive action; make sure you have backed up your data"
echo "Create a snapshot of the server for safety"
echo "-----------------------"
echo "After installation, configure the server as recommended in the documentation"

echo "Server IP: $HOST"
echo "Database name: $DB_NAME"
echo "Tool version: $TOOL_VERSION"

ask_confirmation() {
    while true; do
        read -p "Do you really want to reset the OJS service (y/n) ?" yn
        case $yn in
            [Yy]* ) return 0;;  
            [Nn]* ) exit;;     
            * ) echo "Please answer 'y' or 'n'.";;
        esac
    done
}

manage_database() {
    host="$HOST"
    user="seer"
    db="$DB_NAME"

    # Entering the postgres user and suppressing error messages
    su postgres <<EOF 2>/dev/null
    echo "Deleting database $db..."
    psql -c "DROP DATABASE $db"
    if [ $? -ne 0 ]; then
        echo "Error deleting database $db. Aborting execution."
        exit 1
    fi
    echo "Database $db deleted"

    echo "Recreating database $db..."
    psql -c "CREATE DATABASE $db OWNER $user"
    if [ $? -ne 0 ]; then
        echo "Error creating database $db. Aborting execution."
        exit 1
    fi
    echo "Database $db recreated"

    echo "Granting privileges to user $user"
    psql -c "GRANT ALL privileges ON DATABASE $db TO $user"
    if [ $? -ne 0 ]; then
        echo "Error granting privileges to user $user. Aborting execution."
        exit 1
    fi
    echo "Privileges granted"
    
    psql -c "\q"
EOF
}

download_ojs() {
    home="/root"
    file="ojs-$TOOL_VERSION.tar.gz"

    echo "Downloading file $file..."
    if [ -f "$home/$file" ]; then
        echo "OJS file is already downloaded"
    else
        wget -nv https://pkp.sfu.ca/ojs/download/$file
        if [ $? -ne 0 ]; then
            echo "Error downloading OJS file. Aborting execution."
            exit 1
        fi
        echo "OJS file downloaded"
    fi
}

extract_ojs() {
    home="/root"
    unpackfile="ojs-$TOOL_VERSION"
    
    echo "Extracting file $file..."
    if [ -d "$home/ojs" ]; then
        echo "OJS directory already exists"
    else
        tar -xf "$home/$file" --transform "s!^$unpackfile/\(.*\)!ojs/\1!"
        if [ $? -ne 0 ]; then
            echo "Error extracting OJS file. Aborting execution."
            exit 1
        fi
        echo "File $file extracted"
    fi
}

configure_directories() {
    directory="ojs"

    # Removing installation directory if it exists
    echo "Removing directory $directory..."
    if [ -d "/var/www/$directory" ]; then
        rm -rf "/var/www/$directory"
        if [ $? -ne 0 ]; then
            echo "Error removing directory $directory. Aborting execution."
            exit 1
        fi
        echo "Installation directory removed"
    fi

    echo "Creating directory /var/www/$directory..."
    mkdir "/var/www/$directory"
    if [ $? -ne 0 ]; then
        echo "Error creating directory $directory. Aborting execution."
        exit 1
    fi
    echo "New directory $directory created"

    # Moving extracted files to the installation directory
    echo "Transferring files to /var/www/$directory..."
    cp -r /root/ojs/* "/var/www/$directory/"
    if [ $? -ne 0 ]; then
        echo "Error moving files to directory $directory. Aborting execution."
        exit 1
    fi
    echo "Files moved to /var/www/$directory"

    # Configuring the files directory
    echo "Removing old files directory..."
    if [ -d "/var/www/files" ]; then
        rm -rf /var/www/files
        if [ $? -ne 0 ]; then
            echo "Error removing /var/www/files directory. Aborting execution."
            exit 1
        fi
        echo "Files directory removed"
    fi

    echo "Creating new /var/www/files directory"
    mkdir /var/www/files
    if [ $? -ne 0 ]; then
        echo "Error creating /var/www/files directory. Aborting execution."
        exit 1
    fi
    echo "Changing ownership permissions for the files directory"
    chown www-data:www-data /var/www/files
    if [ $? -ne 0 ]; then
        echo "Error changing ownership permissions for /var/www/files directory. Aborting execution."
        exit 1
    fi
    echo "Files directory created and permissions changed"

    # Changing ownership of files in the installation directory
    echo "Changing ownership permissions for the directory $directory..." 
    chown -R www-data:www-data "/var/www/$directory"
    if [ $? -ne 0 ]; then
        echo "Error changing ownership permissions for directory $directory. Aborting execution."
        exit 1
    fi
    echo "Ownership permissions changed in the installation directory"
}

start_php() {
    directory="revistas3.4"

    echo "Starting PHP server..."
    cd "/var/www/$directory"
    php -S 0.0.0.0:8000
    if [ $? -ne 0 ]; then
        echo "Error starting PHP server. Aborting execution."
        exit 1
    fi
    echo "Service can be installed on port 8000"
}

# Main
ask_confirmation
manage_database
download_ojs
extract_ojs
configure_directories
start_php
