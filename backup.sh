#!/bin/bash

# Указываем директории для архивирования
SOURCE_DIRS=(
    "/path/to/directory1"
    "/path/to/directory2"
    # Добавьте больше директорий по необходимости
)

# Указываем директории с уже архивированными файлами в формате .tar.gz
TAR_GZ_DIRS=(
    "/path/to/tar_gz_directory1"
    "/path/to/tar_gz_directory2"
    # Добавьте больше директорий по необходимости
)

# Указываем директорию, куда будут сохраняться архивы
BACKUP_DIR="/path/to/backup"
TAR_GZ_BACKUP_DIR="$BACKUP_DIR/tar_gz" # Папка для .tar.gz файлов
mkdir -p "$BACKUP_DIR"
mkdir -p "$TAR_GZ_BACKUP_DIR"

# Указываем параметры для rsync
REMOTE_USER="user"                      # Имя пользователя на удаленном сервере
REMOTE_HOST="192.168.1.100"             # IP адрес удаленного сервера
REMOTE_PORT="2222"                      # Порт SSH на удаленном сервере
REMOTE_DIR="/path/to/remote/backup"     # Директория на удаленном сервере
REMOTE_TAR_GZ_DIR="/path/to/remote/tar_gz_backup" # Директория на удаленном сервере для .tar.gz файлов
PASSWORD="your_password_here"           # Пароль для SSH
RETRY_COUNT=5                           # Максимальное количество попыток подключения
RETRY_DELAY=60                          # Задержка между попытками в секундах

# Проверка наличия sshpass, если его нет - предлагаем установить
if ! command -v sshpass &> /dev/null; then
    echo "sshpass could not be found. Please install it to use this script."
    exit 1
fi

# Функция для проверки доступности сервера
function check_server {
    echo "Checking if the remote server is available..."
    if ping -c 1 "$REMOTE_HOST" &> /dev/null
    then
        echo "Server $REMOTE_HOST is reachable."
        return 0
    else
        echo "Server $REMOTE_HOST is not reachable."
        return 1
    fi
}

# Архивирование каждой директории и отправка на сервер
for SOURCE_DIR in "${SOURCE_DIRS[@]}"
do
    DIR_NAME=$(basename "$SOURCE_DIR")  # Имя директории для использования в названии архива
    DATE=$(date +'%Y-%m-%d')
    ARCHIVE_NAME="${DIR_NAME}_backup_$DATE.zip"
    
    # Архивируем текущую директорию
    zip -r "$BACKUP_DIR/$ARCHIVE_NAME" "$SOURCE_DIR"
    
    # Цикл с попытками отправки архива на удаленный сервер
    for (( i=1; i<=RETRY_COUNT; i++ ))
    do
        check_server
        if [ $? -eq 0 ]; then
            # Если сервер доступен, пробуем отправить архив
            sshpass -p "$PASSWORD" rsync -avz -e "ssh -p $REMOTE_PORT" "$BACKUP_DIR/$ARCHIVE_NAME" "$REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR"
            if [ $? -eq 0 ]; then
                echo "Backup and transfer of $ARCHIVE_NAME completed successfully."
                break
            else
                echo "An error occurred during the transfer of $ARCHIVE_NAME. Attempt $i of $RETRY_COUNT."
            fi
        else
            echo "Attempt $i of $RETRY_COUNT: Server is not reachable. Retrying in $RETRY_DELAY seconds..."
        fi
        sleep $RETRY_DELAY
    done
    
    # Если после всех попыток не удалось отправить архив
    if [ $i -gt $RETRY_COUNT ]; then
        echo "Failed to backup and transfer $ARCHIVE_NAME after $RETRY_COUNT attempts."
    fi
done

# Отправка файлов в формате .tar.gz на удаленный сервер
for TAR_GZ_DIR in "${TAR_GZ_DIRS[@]}"
do
    # Цикл с попытками отправки файлов в формате .tar.gz
    for (( i=1; i<=RETRY_COUNT; i++ ))
    do
        check_server
        if [ $? -eq 0 ]; then
            # Если сервер доступен, пробуем отправить архивы .tar.gz
            sshpass -p "$PASSWORD" rsync -avz -e "ssh -p $REMOTE_PORT" "$TAR_GZ_DIR/"*.tar.gz "$REMOTE_USER@$REMOTE_HOST:$REMOTE_TAR_GZ_DIR/"
            if [ $? -eq 0 ]; then
                echo "Transfer of .tar.gz files from $TAR_GZ_DIR completed successfully."
                break
            else
                echo "An error occurred during the transfer of .tar.gz files from $TAR_GZ_DIR. Attempt $i of $RETRY_COUNT."
            fi
        else
            echo "Attempt $i of $RETRY_COUNT: Server is not reachable. Retrying in $RETRY_DELAY seconds..."
        fi
        sleep $RETRY_DELAY
    done
    
    # Если после всех попыток не удалось отправить файлы
    if [ $i -gt $RETRY_COUNT ]; then
        echo "Failed to transfer .tar.gz files from $TAR_GZ_DIR after $RETRY_COUNT attempts."
    fi
done

# Завершаем работу скрипта
exit 0
