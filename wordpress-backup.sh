#!/bin/bash
#     _           _                   _     _ 
#    | |__  _   _| |_ ___  __ _  ___ | | __| |
#    | '_ \| | | | __/ _ \/ _` |/ _ \| |/ _` |
#    | |_) | |_| | ||  __/ (_| | (_) | | (_| |
#    |_.__/ \__, |\__\___|\__, |\___/|_|\__,_|
#           |___/         |___/               
#
#
#   Version:      1.0
#
#   License:      Expat License 
#                 https://directory.fsf.org/wiki/License:Expat
#
#   Contributors: Bytegold
#                 https://bytegold.com
#

# initialize default values
EXEC_DIR=$(pwd)
SCRIPT_NAME=$(basename "$0")
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
BACKUP_DIR="$EXEC_DIR"
PREFIX=$(printf '%(%Y-%m-%d)T')
POSTFIX=""

POSITIONAL_ARGS=()
while [[ $# -gt 0 ]]; do
    case $1 in
    -pre | --prefix)
        PREFIX="$2"
        shift # past argument
        shift # past value
        ;;
    -post | --postfix)
        POSTFIX="_${2}"
        shift # past argument
        shift # past value
        ;;
    -h | --help)
        HELP=YES
        shift # past argument
        ;;
    -* | --*)
        echo "Unknown option $1"
        exit 1
        ;;
    *)
        POSITIONAL_ARGS+=("$1") # save positional arg
        shift                   # past argument
        ;;
    esac
done

set -- "${POSITIONAL_ARGS[@]}" # restore positional parameters

# check if wordpress directory is given as last argument
if [[ -z $1 ]]; then
    HELP=YES
else
    WORDPRESS_DIR="$1"
fi

# print help
if [[ -n "$HELP" ]]; then
    echo "Usage: $SCRIPT_NAME [OPTION]... [WORDPRESS_DIR]"
    echo "Back up a local wordpress directory including local database dump"
    echo ""
    echo -e "-h, --help\t\t\tprint this help"
    echo ""
    echo -e "-pre, --prefix=STRING\t\tSTRING_ gets prepended to backup file name"
    echo ""
    echo -e "-post, --postfix=STRING\t\t_STRING gets appended to backup file name"
    echo -e "\t\t\t\t(before extension)"
    echo ""
    exit 0
fi

IS_SUPPORTED=""
# validate wordpress folder
if [ -d "$WORDPRESS_DIR" ]; then
    if [ -f "$WORDPRESS_DIR/wp-config.php" ]; then
        IS_SUPPORTED=YES
    fi
fi

if [ -z "${IS_SUPPORTED}" ]; then
    echo ""
    echo "#> ERROR: Not a wordpress folder: $WORDPRESS_DIR"
    echo ""
    exit 1
fi

# dynamically set up database variables
DB_NAME=`cat "$WORDPRESS_DIR/wp-config.php" | grep -Ev '^\s*[#/]' | grep DB_NAME | cut -d \' -f 4 | tail -1`
DB_USERNAME=`cat "$WORDPRESS_DIR/wp-config.php" | grep -Ev '^\s*[#/]' | grep DB_USER | cut -d \' -f 4 | tail -1`
DB_PASSWORD=`cat "$WORDPRESS_DIR/wp-config.php" | grep -Ev '^\s*[#/]' | grep DB_PASSWORD | cut -d \' -f 4 | tail -1`

SKIP_DATABASE=""
if [ -z "${DB_NAME}" ] || [ -z "${DB_USERNAME}" ] || [ -z "${DB_PASSWORD}" ]; then
    SKIP_DATABASE=YES
fi

# print disk space
echo -e "BACKUP SETTINGS\t\t"
echo ""
echo -e "  Wordpress:\t$WORDPRESS_DIR"
if [ -z "$SKIP_DATABASE" ]; then
    echo -e "  Database:\t$DB_NAME"
else
    echo -e "  Database:\t Skipping - missing credentials in wp-config.php"
fi
echo -e "  Backup:\t$BACKUP_DIR"
echo -e "  Prefix:\t${PREFIX}_"
echo -e "  Postfix:\t$POSTFIX"
echo ""
DISKSPACE=`df -Ph . | tail -1 | awk '{print $4}'`
echo -e "  $DISKSPACE disk space available"
echo ""
read -p "Press enter to continue"
echo ""

# handle file backup
read -r -p "Back up files folder? [Y/n] " response
if [[ "$response" =~ ^([nN][oO]|[nN])$ ]]; then
    echo "#> Skipping files backup"
else
    BACKUP_FILE="$BACKUP_DIR/backup_${PREFIX}_files_public_html${POSTFIX}.tar.gz"
    if [[ -f "$BACKUP_FILE" ]]; then
        read -r -p "#> Backup file already exists. Overwrite? [y/N] " response
        if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
            echo "#> Backing up files..."
            tar czf "$BACKUP_FILE" "$WORDPRESS_DIR"
            echo "#> Done."
        else
            echo "#> Skipping files backup"
        fi
    else
        echo "#> Backing up files..."
        tar czf "$BACKUP_FILE" "$WORDPRESS_DIR"
        echo "#> Done."
    fi
fi
echo ""

# handle database backup
if [ -z "$SKIP_DATABASE" ]; then
    read -r -p "Back up database? [Y/n] " response
    if [[ "$response" =~ ^([nN][oO]|[nN])$ ]]; then
        echo "#> Skipping database backup"
    else
        BACKUP_FILE="$BACKUP_DIR/backup_${PREFIX}_db_${DB_NAME}${POSTFIX}.sql"
        if [[ -f "$BACKUP_FILE" ]]; then
            read -r -p "#> Backup file already exists. Overwrite? [y/N] " response
            if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
                echo "#> Backing up database..."
                mysqldump --opt --no-tablespaces --user="$DB_USERNAME" --password="$DB_PASSWORD" "$DB_NAME" >"$BACKUP_FILE"
                echo "#> Done."
            else
                echo "#> Skipping database backup"
            fi
        else
            echo "#> Backing up database..."
            mysqldump --opt --no-tablespaces --user="$DB_USERNAME" --password="$DB_PASSWORD" "$DB_NAME" >"$BACKUP_FILE"
            echo "#> Done."
        fi
    fi
fi
echo ""

cd "$EXEC_DIR"
