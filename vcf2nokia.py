#!/usr/bin/env python
# -*- coding: utf-8 -*-

import os
import io
import sys
import quopri

'''

Обрабатывается файл контактов после экспорта из адресной книги Android или Gmail.
Кодировка utf-8, имена кодируются QUOTED-PRINTABLE

=D0=91=D0=B5

Читает только поле N и склеивает поля, которые разбиты через ;
Для нескольких телефонов у одного контакта создается
несколько записей - к имени добавляется номер 1,2,...

Длина имени ограничена 15 символами

Сохраняет контакты в файл в формате
"Имя1",+12345678901
"Имя2",+12345678902
"Имя2",+12345678903

'''


def need_line(line):
    ss = ["BEGIN:VCARD",
          "END:VCARD",
          # "FN:",
          # "FN;",
          "TEL:",
          "TEL;",
          "N;CHARSET"]
    for s in ss:
        if line.startswith(s):
            return True
    return False


def decode_lines(lines):
    res = []
    for line in lines:
        if not need_line(line):
            continue
        s1 = quopri.decodestring(line).decode("utf8")
        s2 = s1.replace(";ENCODING=QUOTED-PRINTABLE", "")
        s2 = s2.replace(";CHARSET=UTF-8", "")
        res.append(s2)
    return res


def load_filtered_lines(fn):
    f = io.open(fn, mode="rt")
    lines = []
    for line in f:
        lines.append(line.strip())

    res = []
    for i in range(len(lines)):
        line = lines[i]
        if line.startswith("="):  # merge with prev
            res[-1] = res[-1] + line[1:]  # no first "="
        else:
            res.append(line)
    return res


def write_lines(fn, lines):
    f = io.open(fn, mode="wt", newline="\n", encoding="utf8")
    f.write("\n".join(lines))
    f.close()


def normalize_tel(lines):
    res = []
    for line in lines:
        if line.startswith("TEL"):
            s = line.replace("-", "")
            s = s.replace(" ", "")
            res.append(s)
        else:
            res.append(line)
    return res


def get_name(line):
    s = line.replace(":", ";")
    s = s.replace(" ", "_")
    ss = s.split(";")
    if len(ss) < 2:
        return "x-no-name-x"
    ss = ss[1:]
    n = "_".join(filter(None, ss))
    return n


def get_tel(line):
    s = line.replace(" ", "")
    s = s.replace("-", "")
    s = s.replace(":", ";")
    ss = s.split(";")
    if len(ss) > 1:
        if len(ss[-1]) > 0:
            return ss[-1]
    return "x-no-tel-x"


def make_addr_book(lines, limit_len=15):
    begins = []
    ends = []
    # find start/stop index
    for i in range(len(lines)):
        if lines[i].startswith("BEGIN:VCARD"):
            begins.append(i)
        if lines[i].startswith("END:VCARD"):
            ends.append(i)

    # group lines to cards by index BEGIN/END
    cards = [lines[n + 1:m]
             for n, m in zip(begins, ends)]  # no BEGIN/END lines in card lines

    book = []
    for lines in cards:
        b = {}
        for line in lines:
            if line.startswith("N:"):
                b["name"] = get_name(line)
            if line.startswith("TEL"):
                if not "tel" in b:
                    b["tel"] = []
                b["tel"].append(get_tel(line))

        if ("tel" in b) and ("name" in b):
            book.append(b)

    tels = []
    max_chars = limit_len

    for b in book:
        if len(b["tel"]) > 1:
            n = 1
            for t in b["tel"]:
                sn = "%1d" % n
                n = n + 1
                s = "\"" + b["name"][:(max_chars-1)] + sn + "\"" + "," + t
                tels.append(s)
        else:
            s = "\"" + b["name"][:max_chars] + "\"" + "," + b["tel"][0]
            tels.append(s)

    tels.sort()
    return tels


lines = load_filtered_lines("contacts.vcf")
lines = decode_lines(lines)
lines = normalize_tel(lines)

tels = make_addr_book(lines, limit_len=100)

write_lines("tel.csv", tels)
