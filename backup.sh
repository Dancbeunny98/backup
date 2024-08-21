#!/bin/bash

# --- НАСТРОЙКИ ---

# Локальная директория с данными для резервного копирования (одна или несколько через запятую)
# Пример: резервное копирование из нескольких директорий
LOCAL_DIR="/path/to/pterodactyl"
#LOCAL_DIR="/path/to/pterodactyl,/path/to/another"
#LOCAL_DIR="/var/www/site1,/var/www/site2"

# Временная директория для архивов
ARCHIVE_DIR="/path/to/archives"

# Данные удалённого сервера
REMOTE_USER="user"                             # Пользователь на удалённом сервере
REMOTE_HOST="remote.server.com"                # IP адрес или доменное имя удалённого сервера
REMOTE_DIR="/path/to/backup"                   # Папка на удалённом сервере для сохранения бэкапа

# Лог-файлы
LOG_FILE="/var/log/pterodactyl_backup.log"     # Основной лог-файл
ERROR_LOG_FILE="/var/log/pterodactyl_backup_error.log" # Лог-файл ошибок

# Формат даты для архивов
DATE_FORMAT=$(date '+%Y-%m-%d_%H-%M-%S')

# Дополнительные параметры подключения
SSH_PORT=22                                    # Порт для подключения по SSH (по умолчанию 22)
# Примеры использования нестандартного порта:
# SSH_PORT=2222                                 # Порт 2222 вместо стандартного

SSH_PASSWORD=""                                # Пароль для подключения (оставьте пустым для использования ключа)
# Примеры использования пароля или ключа SSH:
# SSH_PASSWORD="your_password"                  # Пароль для SSH (если требуется)
# SSH_KEY_FILE="/home/user/.ssh/id_rsa"         # Приватный ключ SSH

# Параметры повторных попыток подключения
RETRY_COUNT=5                                  # Максимальное количество попыток подключения
RETRY_DELAY=60                                 # Задержка между попытками в секундах

# Уровень сжатия (от 1 до 9, где 9 - максимальное сжатие)
COMPRESSION_LEVEL=6
# Пример: использовать максимальный уровень сжатия
# COMPRESSION_LEVEL=9

# Протокол передачи данных (поддерживаемые: rsync, scp)
PROTOCOL="rsync"
# Примеры:
# PROTOCOL="rsync"                              # Использовать rsync (по умолчанию)
# PROTOCOL="scp"                                # Использовать scp

# Опции ротации старых бэкапов на удалённом сервере
ROTATE_BACKUPS=false                           # Включение ротации старых бэкапов
ROTATE_DAYS=30                                 # Число дней для хранения бэкапов на удалённом сервере
# Примеры:
# ROTATE_BACKUPS=true                           # Включить ротацию старых бэкапов
# ROTATE_DAYS=7                                 # Хранить бэкапы только 7 дней

# Типы файлов для архивирования (по умолчанию - все файлы)
FILE_TYPES="*"
# Примеры:
# FILE_TYPES="log,sh"                           # Архивировать только .log и .sh файлы
# FILE_TYPES="tar.gz,zip"                       # Архивировать только .tar.gz и .zip файлы
# FILE_TYPES="txt,pdf,jpg"                      # Архивировать только .txt, .pdf и .jpg файлы

# --- КОНЕЦ НАСТРОЕК ---

# Помощь
if [[ "$1" == "--help" ]]; then
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --help                 Show this help message"
    echo "  --file-types=TYPE      Specify file types for backup, comma-separated (default: all)"
    echo "  --compression=LEVEL    Compression level (1-9, default: 6)"
    echo "  --protocol=PROTOCOL    Data transfer protocol (rsync, scp)"
    echo "  --rotate-backups       Enable rotation of old backups on the remote server"
    echo "  --rotate-days=DAYS     Number of days to keep backups on the remote server"
    exit 0
fi

# Разбор аргументов командной строки
for i in "$@"; do
    case $i in
        --file-types=*)
            FILE_TYPES="${i#*=}"
            shift
            ;;
        --compression=*)
            COMPRESSION_LEVEL="${i#*=}"
            shift
            ;;
        --protocol=*)
            PROTOCOL="${i#*=}"
            shift
            ;;
        --rotate-backups)
            ROTATE_BACKUPS=true
            shift
            ;;
        --rotate-days=*)
            ROTATE_DAYS="${i#*=}"
            shift
            ;;
        *)
            # неизвестный параметр
            ;;
    esac
done

# Проверка доступного места на локальном и удалённом серверах
function check_disk_space {
    local dir=$1
    local required_space=$2
    local available_space=$(df -k --output=avail "$dir" | tail -n1)

    if [ $available_space -lt $required_space ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Недостаточно места на $dir." >> $ERROR_LOG_FILE
        exit 1
    fi
}

# Создание архива с учётом типа файлов и даты
function create_archives {
    mkdir -p $ARCHIVE_DIR

    IFS=',' read -r -a DIR_ARRAY <<< "$LOCAL_DIR"
    for DIR in "${DIR_ARRAY[@]}"; do
        for TYPE in $(echo $FILE_TYPES | tr ',' ' '); do
            find $DIR -type f -name "*.$TYPE" -newermt $DATE_FORMAT -exec tar -czf $ARCHIVE_DIR/$(basename {}).$DATE_FORMAT.tar.gz -C $(dirname {}) $(basename {}) \;
        done
    done
}

# Проверка доступности удалённого сервера и попытки подключения
attempt=1
while [ $attempt -le $RETRY_COUNT ]; do
    ping -c 3 $REMOTE_HOST > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Удалённый сервер доступен, попытка $attempt из $RETRY_COUNT." >> $LOG_FILE
        break
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Не удалось подключиться к удалённому серверу $REMOTE_HOST. Попытка $attempt из $RETRY_COUNT." >> $ERROR_LOG_FILE
        attempt=$(( $attempt + 1 ))
        if [ $attempt -le $RETRY_COUNT ]; then
            sleep $RETRY_DELAY
        else
            echo "$(date '+%Y-%m-%d %H:%M:%S') - Все попытки подключения не удались. Резервные копии остаются на локальном сервере." >> $ERROR_LOG_FILE
            exit 1
        fi
    fi
done

# Ротация старых бэкапов на удалённом сервере (опционально)
if [ "$ROTATE_BACKUPS" = true ]; then
    function rotate_backups {
        ssh -p $SSH_PORT $REMOTE_USER@$REMOTE_HOST "find $REMOTE_DIR -type f -mtime +$ROTATE_DAYS -delete"
        if [ $? -eq 0 ]; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') - Ротация старых бэкапов на удалённом сервере выполнена." >> $LOG_FILE
        else
            echo "$(date '+%Y-%m-%d %H:%M:%S') - Ошибка при ротации бэкапов на удалённом сервере." >> $ERROR_LOG_FILE
        fi
    }
    rotate_backups
fi

# Формирование команды передачи файлов
function transfer_files {
    if [ "$PROTOCOL" == "rsync" ]; then
        RSYNC_CMD="rsync -avz -e 'ssh -p $SSH_PORT"
        [ -n "$SSH_KEY_FILE" ] && RSYNC_CMD="$RSYNC_CMD -i $SSH_KEY_FILE"
        [ -n "$SSH_PASSWORD" ] && RSYNC_CMD="sshpass -p $SSH_PASSWORD $RSYNC_CMD"
        RSYNC_CMD="$RSYNC_CMD' --remove-source-files $ARCHIVE_DIR/ $REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR"
        eval $RSYNC_CMD >> $LOG_FILE 2>&1
    elif [ "$PROTOCOL" == "scp" ]; then
        SCP_CMD="scp -P $SSH_PORT"
        [ -n "$SSH_KEY_FILE" ] && SCP_CMD="$SCP_CMD -i $SSH_KEY_FILE"
        [ -n "$SSH_PASSWORD" ] && SCP_CMD="sshpass -p $SSH_PASSWORD $SCP_CMD"
        SCP_CMD="$SCP_CMD $ARCHIVE_DIR/* $REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR"
        eval $SCP_CMD >> $LOG_FILE 2>&1 && rm -f $ARCHIVE_DIR/*
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Неизвестный протокол: $PROTOCOL." >> $ERROR_LOG_FILE
        exit 1
    fi
}

# Проверка дискового пространства
check_disk_space $ARCHIVE_DIR 1000000 # Проверка на 1GB свободного места

# Создание архивов
create_archives

# Передача файлов
transfer_files

# Завершение скрипта
echo "$(date '+%Y-%m-%d %H:%M:%S') - Резервное копирование завершено успешно." >> $LOG_FILE
