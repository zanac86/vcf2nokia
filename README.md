## Подключить телефон в Ubuntu

Работает с Nokia 105DS и 130DS

```sh
sudo modprobe usbserial vendor=0x0421 product=0x069a
nokiatool.sh phonebook-read phone
```

## Экспорт в файл

```sh
nokiatool.sh phonebook-read phone > contacts.csv
```

Будет создан файл csv

```
1,"Имя1",+12345678901
2,"Имя2",+12345678902
3,"Имя2",+12345678903
```

## Перенос контактов в телефон

```sh
nokiatool.sh phonebook-import phone < tel.csv
```

Порядковых номеров контактов нет.
Контакты можно на русском в кодировке UTF-8.
Переводы строк UNIX!!! (0x0A).

```
"Имя1",+12345678901
"Имя2",+12345678902
"Имя2",+12345678903
```

Для сортировки можно использовать

```sh
sort tel.csv > tel_sorted.csv
```



## Конвертер контактов

Скрипт `vcf2nokia.py` конвертирует контакты из vcf файла в файл для заливки в телефон.
Имена урезаются до 15 символов. Если у контакта есть несколько телефонов, то 
к имени добавляется порядковй номер.

Обрабатывается файл контактов после экспорта из адресной книги Android или Gmail.

## Источники

[github nokiatool]([https://gist.github.com/plugnburn/5b2582be521944f739e1)
[helpix nokia105ds](http://helpix.ru/opinion/201602/55164-nokia_105_dual_sim.html)

```
*#RESET# (*#73738#) - сброс игры Smash'n'Win
*#RESET2# (*#737382#) - сброс игры Ninja Up
*#RESET3# (*#737383#) - сброс игры Sky Gift
*#RESET4# (*#737384#) - сброс игры Danger Dash
```
