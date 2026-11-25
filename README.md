# JuzeppeOS Package Repository

Готовый статический сайт и HTTP-репозиторий для JuzeppeOS 0.8.3. Содержимое можно разместить на GitHub Pages или в любом каталоге Nginx; серверный код не требуется.

## GitHub Pages

1. Создайте публичный репозиторий GitHub, например juzeppe-repo.
2. Загрузите содержимое этого каталога в корень ветки main, включая .nojekyll и CNAME.
3. Откройте Settings → Pages → Build and deployment, выберите Deploy from a branch, main, / (root), сохраните.
4. В Settings → Pages → Custom domain укажите repo.juzeppe.icu. После сохранения у DNS-провайдера создайте запись CNAME:

       repo    CNAME    ВАШ-ЛОГИН.github.io.

   Если для repo уже существуют A/AAAA записи, удалите только конфликтующие записи именно этого поддомена. Остальные поддомены менять не нужно.
5. После проверки DNS включите Enforce HTTPS.

Официальное руководство:
https://docs.github.com/en/pages/configuring-a-custom-domain-for-your-github-pages-site/managing-a-custom-domain-for-your-github-pages-site

## Подключение JuzeppeOS

В JuzeppeOS 0.8.3 репозиторий уже настроен установщиком. Открой магазин приложений или введи в терминале:

    jpkg refresh
    jpkg install office

Для JuzeppeOS 0.6.3 и старше сначала подключи репозиторий:

    jpkg repo https://raw.githubusercontent.com/gosuparenek/juzeppe-repo/main
    jpkg refresh

В качестве альтернативы укажите URL Pages вида https://ВАШ-ЛОГИН.github.io/juzeppe-repo без завершающего /, пока свой домен ещё не настроен.

## Новые приложения

1. Поместите файл .juz в packages/.
2. Запустите из корня репозитория:

       python rebuild-catalog.py

3. Загрузите обновлённый index.json и новый пакет на GitHub.

Сайт автоматически читает index.json. Тот же файл читают игровые компьютеры. При изменении версии пакета необходимо обновить его manifest.version, пересобрать индекс и опубликовать оба файла.

Загрузчик ОС находится в downloads/juzeppe.lua. При новой версии обновите этот файл и номер версии в index.html.

Встроенный каталог JuzeppeOS можно вернуть командой jpkg repo local.

## Stock / беспроводной склад

В JuzeppeOS 0.8.3 приложение Stock 1.1.0 читает Create Stock Ticker локально, через проводной модем или через беспроводной компьютер-посредник. Для склада нужен Create 6.0.7+ с интеграцией CC: Tweaked.

1. На компьютере рядом с тикером установите Wireless Modem либо Ender Modem. Тикер должен быть связан с нужной сетью Create.
2. В CraftOS скачайте и запустите службу:

       wget https://raw.githubusercontent.com/gosuparenek/juzeppe-repo/main/downloads/stock-host.lua stock-host.lua
       stock-host

3. Запомните Server ID. Оставьте программу запущенной, а чанк склада — загруженным.
4. На втором компьютере с беспроводным модемом установите или обновите Stock через Apps. При первом запуске разрешите stock.read и stock.remote. Нажмите Link, введите Server ID, затем Sync для повторного запроса. Пустое поле Link возвращает локальный режим; Src выбирает следующий локальный тикер.

Служба передаёт только список предметов и количества. Она не оформляет заказы. В текущем протоколе ID используется для выбора компьютера, а не для аутентификации: список предназначен для общедоступного просмотра в пределах сети Minecraft. Поддерживаются до 4096 записей за один запрос. Если связь пропала, Stock сохраняет старый список и показывает ошибку.
