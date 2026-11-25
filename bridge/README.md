# Juzeppe Bridge 0.2.1

Экспериментальный серверный мод для Minecraft 1.21.1 / NeoForge, Create 6.0.7+ и CC: Tweaked. Открывает оригинальное меню заказа Create для текущего игрока, использующего терминал CC:T. Новых блоков, клиентских пакетов и экранов не добавляет.

## Сборка

Java 21 и Gradle 8.14.3. В этом каталоге выполните `gradle build`. Артефакт: `build/libs/juzeppe-bridge-0.2.1.jar`. GitHub Actions собирает мод автоматически.

## Установка

1. Установите JAR только в папку mods сервера и перезапустите сервер. Create и CC:T должны быть на сервере и у игроков.
2. Поставьте Stock Ticker на той же сети склада, с сидящим Stock Keeper или Blaze Burner рядом. Тикер может быть спрятан в помещении или под полом, но должен быть в загруженных игроком чанках.
3. Если тикер соседствует с компьютером, привязка автоматическая. Иначе администратор выполняет в том же измерении:

       /juzeppebridge bind <x компьютера> <y> <z> <x тикера> <y> <z>

   Например: `/juzeppebridge bind 100 64 100 100 61 100`. Привязка сохраняется в пределах текущего измерения. Команда unbind с координатами компьютера отменяет привязку.
4. Откройте именно экран компьютера в Minecraft. В Lua-терминале выполните `juzeppebridge.openStock()`. В обновлённом Stock также есть кнопка GUI. Если несколько игроков одновременно открыли один компьютер, операция предлагается только после выхода остальных.

Сохраняется штатная проверка прав Create. Мод не читает произвольные координаты из Lua, не открывает меню произвольным игрокам и не отправляет заказ. Если в основной руке Shopping List, её сначала нужно убрать, чтобы обращение к штатному обработчику не стало покупкой. Интерфейс Create привязан к реальному блоку: удалённый незагруженный тикер не поддерживается.

## Проверка

Архитектура сверена с исходниками Create 6.0.8 и CC:T 1.116.1. Для проверки открытия меню в игре нужен сервер и подключённый клиент с этими модами.

## Wireless

Stock Host 1.1.0: use an adjacent ticker and wireless modem, with Bridge 0.2.1 installed on server. Pair Stock 1.3.0 via Link (host computer ID). GUI requests a short-lived invitation from the host, then opens the existing Create ordering menu after checking the active player, Create permissions and loaded ticker. Bridge has no fixed distance cap. The ticker and keeper must be loaded on the player's client in the same dimension. Create itself validates the order distance; for reliable ordering on Create 6.0.8, keep an intermediate ticker within 20 blocks of the player. Bridge warns in chat when opening farther away. No admin command required for this mode.
