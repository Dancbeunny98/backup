# Шаг 1: Установка программного обеспечения

### На Ubuntu/Debian
1. Обновите списки пакетов:

     ```sudo apt update```

2. Установите необходимые пакеты:

     ```sudo apt install zip rsync sshpass```

### На CentOS/RHEL
1. Обновите систему:

     ```sudo yum update```
2. Установите необходимые пакеты:

     ```sudo yum install zip rsync sshpass```
### На macOS
1. Установите Homebrew (если еще не установлен):

     ```/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"```
2. Установите необходимые пакеты:

     ```brew install zip rsync```
3. Установка sshpass может потребовать дополнительных шагов:

     ```brew install hudochenkov/sshpass/sshpass```

# Шаг 2: Настройка скриптов

## Скрипт backup.sh

Устанавливается на сервере №1

1. Создайте файл `backup.sh` с содержимым:
2. Следуя комментариям и примерам укажите ваши дирректории!
```bash
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

```
## Скрипт cleanup.sh

Устанавливается на сервере №2

1. Создайте файл `cleanup.sh` с содержимым:
2. Следуя комментариям и примерам укажите ваши дирректории!
```bash
#!/bin/bash

# Путь к директории с резервными копиями
REMOTE_BACKUP_DIR="/path/to/remote/backup"
# Путь к директории с файлами .tar.gz
REMOTE_TAR_GZ_DIR="/path/to/remote/tar_gz_backup"

# Максимальное количество файлов для обычных резервных копий
MAX_FILES=10

# Максимальное количество файлов с расширением .tar.gz
MAX_TAR_GZ_FILES=10

# Функция для удаления старых файлов, сохраняя только последние MAX_FILES
cleanup_old_backups() {
    local dir=$1
    local max_files=$2
    cd "$dir" || exit 1

    for PREFIX in $(ls | rev | cut -d'_' -f2- | rev | uniq); do
        FILE_COUNT=$(ls -1 "${PREFIX}_"* | wc -l)
        if [ "$FILE_COUNT" -gt "$max_files" ]; then
            ls -1t "${PREFIX}_"* | tail -n +$((max_files + 1)) | xargs rm -f
            echo "Deleted old backups for $PREFIX, kept the last $max_files."
        fi
    done
}

# Очистка обычных резервных копий
cleanup_old_backups "$REMOTE_BACKUP_DIR" "$MAX_FILES"

# Очистка файлов .tar.gz
cleanup_old_backups "$REMOTE_TAR_GZ_DIR" "$MAX_TAR_GZ_FILES"

# Завершаем работу скрипта
exit 0

```
# Шаг 3: Настройка crontab

1. Откройте редактор `crontab` для редактирования:

     ```crontab -e```

2. Добавьте следующие строки для выполнения скриптов `backup.sh` и `cleanup.sh` в нужное время. Например, чтобы выполнять резервное копирование каждый день в `2:00` и очистку резервных копий каждую неделю в воскресенье в `3:00`:

    ```
    0 2 * * * /path/to/backup.sh
    0 3 * * 0 /path/to/cleanup.sh
    ```
Замените `/path/to/backup.sh` и `/path/to/cleanup.sh` на фактические пути к вашим скриптам.

# Шаг 4: Устранение проблем с кодировками

1. Проверьте кодировку файлов:

    Используйте команду `file` для проверки кодировки:

    ```
    file backup.sh
    file cleanup.sh
    ```
2. Преобразуйте кодировку в UTF-8:

    Если файл не в кодировке UTF-8, используйте команду `iconv` для преобразования:

    ```
    iconv -f <current-encoding> -t UTF-8 backup.sh -o backup.sh
    iconv -f <current-encoding> -t UTF-8 cleanup.sh -o cleanup.sh
    ```
   Замените `<current-encoding>` на текущую кодировку файла, например `ISO-8859-1` или `Windows-1251`.

3. Проверьте выполнение скриптов:

    Убедитесь, что скрипты выполняются без ошибок. Если возникают проблемы, проверьте права доступа и правильность синтаксиса.

    ```
    chmod +x /path/to/backup.sh
    chmod +x /path/to/cleanup.sh
    ```
## Заключение
    Теперь вы настроили автоматическое резервное копирование и очистку старых резервных копий с использованием crontab. Также вы устраните возможные проблемы с кодировками скриптов. Не забудьте регулярно проверять выполнение скриптов и корректность резервных копий.
