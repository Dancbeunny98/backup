# Шаг 1: Установка программного обеспечения

### На Ubuntu/Debian
1. Обновите списки пакетов:

     ```sudo apt update```

2. Установите необходимые пакеты:

     ```sudo apt install -y rsync tar openssh-client sshpass findutils```
   
     ```sudo apt install -y gzip```

     ```sudo apt install -y sshpass```

     *```sudo apt install -y openssh-server```

# Шаг 2: Настройка скриптов

## Скрипт backup.sh

Устанавливается на сервере №1

1. Создайте файл `backup.sh` с содержимым:
2. Следуя комментариям и примерам укажите ваши дирректории!

## Скрипт cleanup.sh

Устанавливается на сервере №2

1. Создайте файл `cleanup.sh` с содержимым:
2. Следуя комментариям и примерам укажите ваши дирректории!

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

    Теперь вы настроили автоматическое резервное копирование и очистку старых резервных копий с
    использованием crontab. Также вы устраните возможные проблемы с кодировками скриптов. Не забудьте регулярно проверять 
    выполнение скриптов и корректность резервных копий.
