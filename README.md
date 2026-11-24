# JuzeppeOS Package Repository

Готовый статический сайт и HTTP-репозиторий для JuzeppeOS 0.6.1. Содержимое можно разместить на GitHub Pages или в любом каталоге Nginx; серверный код не требуется.

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

В терминале ОС:

    jpkg repo https://repo.juzeppe.icu
    jpkg refresh
    jpkg install calculator

В качестве альтернативы укажите URL Pages вида https://ВАШ-ЛОГИН.github.io/juzeppe-repo без завершающего /, пока свой домен ещё не настроен.

## Новые приложения

1. Поместите файл .juz в packages/.
2. Запустите из корня репозитория:

       python rebuild-catalog.py

3. Загрузите обновлённый index.json и новый пакет на GitHub.

Сайт автоматически читает index.json. Тот же файл читают игровые компьютеры. При изменении версии пакета необходимо обновить его manifest.version, пересобрать индекс и опубликовать оба файла.

Загрузчик ОС находится в downloads/juzeppe.lua. При новой версии обновите этот файл и номер версии в index.html.

Встроенный каталог JuzeppeOS можно вернуть командой jpkg repo local.
