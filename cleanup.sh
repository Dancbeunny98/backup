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
