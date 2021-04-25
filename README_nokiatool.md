NokiaTool: control MediaTek-based Nokia phones from your PC
===========================================================

Overview
--------

NokiaTool is a simple Bash script (`nokiatool.sh`) that allows you to use an undocumented serial connection in USB-enabled MediaTek-based Nokia feature phones manufactured by Microsoft (even the most basic ones, like the new 105) in order to control them from your PC.

This project is an ongoing work and uses only some bits and pieces of information about the phone internals available to the public, so under any circumstances don't consider it stable or a replacement for official tools if any are present.

Configuration and running
-------------------------

Dependencies: `stty`, `grep`, `iconv`, `od`, `sed`, `tr`, `cut`. Most probably they are already present in your distribution.

First of all, you have to make sure that you have the suitable driver initialization command (`DRIVERINIT` variable) in the script. If you have Nokia 105 or 130, you can leave it as is, otherwise you'll probably have to change vendor/product ID according to actual device (or leave this command empty altogether).

Second, you may have to adjust the actual serial port capable of receiving AT commands (`MODEM` variable). For example, Nokia 105 DS opens two ports, and the second one (/dev/ttyUSB1 in my case) is the right one to connect. Your mileage may vary.

After that, just make the script executable (via `chmod +x`) and you are ready to go.

NokiaTool functionality is divided into subcommands. Each of them is described in corresponding section. If you're not running the script under root privileges but any useful command (not in the `help` section), it will ask you for your `sudo` password in order to authorize modem device access. This is completely safe because the only root-enabled operation is writing into `/dev/ttyUSBx` or whatever character device file you choose in the `MODEM` variable.

Choosing a SIM for further operation
------------------------------------

If you have a dual-SIM model with 2 active SIM cards, all operations are performed via SIM 1 by default. If you need to select the second SIM to dial a number or send SMS via NokiaTool , please run:

`nokiatool.sh sim select-second`

And if you need to return to the first SIM, just run:

`nokiatool.sh sim select-first`

Note that active SIM is reset to SIM 1 after each phone reboot.

Main functions
--------------

The simplest NokiaTool commands are:

- Dial a number: `nokiatool.sh dial <number>`, e.g. `nokiatool.sh dial 5433`
- Answer the call: `nokiatool.sh pickup`
- End the call: `nokiatool.sh hangup`
- Send an SMS message (no concatenated messages suport for now: Unicode is supported but limited to 70 characters, Latin messages can use 160 characters, quotes must be escaped properly): `nokiatool.sh sms <number> <message>`, e.g. `nokiatool.sh sms +18003733411 hello dudes!`
- Write an SMS draft (all the same limitations apply) and save it into the phone: `nokiatool.sh draft <message>`, e.g. `nokiatool.sh draft Don\\\'t forget to buy some milk`
- Send a Flash SMS (also known as Class 0 SMS - an SMS that's displayed immediately and doesn't get saved into the inbox by default) up to 70 characters long (Unicode only): `nokiatool.sh flash-sms <number> <message>`, e.g. `nokiatool.sh flash-sms +18003733411 You won\\\'t find me at the party`
- Reboot the phone: `nokiatool.sh reboot`

SIM control
-----------

Besides `sim select-first` and `sim select-second`, NokiaTool provides some more commands to control SIM activity:

- `nokiatool.sh sim off` - turn off both SIMs (flight mode!)
- `nokiatool.sh sim current-off` - turn off current selected SIM
- `nokiatool.sh sim first` - activate SIM 1 only
- `nokiatool.sh sim second` - activate SIM 2 only (for dual-SIM models)
- `nokiatool.sh sim both` - activate both SIMs

Phonebook and call logs
-----------------------

### Reading (export)

NokiaTool allows you to easily export any section of your phonebook or call logs into CSV format so that you can easily view your contacts on a PC or transfer them to another device. It's done with `nokiatool.sh phonebook-read` subcommand. You can view contacts in the console, redirect the output into a file (it's separated from info messages) or even pipe it to other program for processing. For example, `nokiatool.sh phonebook-read phone > phone.csv` command exports the entire device phonebook into the `phone.csv` file.

The following reading modes are supported for different phonebook parts:

- `nokiatool.sh phonebook-read phone` - view/export device phonebook;
- `nokiatool.sh phonebook-read sim` - view/export currently selected SIM card phonebook;
- `nokiatool.sh phonebook-read own` - view/export own number list of current SIM;
- `nokiatool.sh phonebook-read fdn` - view/export FDN number list.

All phonebook entries are exported in the following CSV line format: `<index>,"<name>",<number>`. You can also omit indexes by passing `short` as the last parameter, for example, `nokiatool.sh phonebook-read sim short`. This way only `"<name>",<number>` will be present in each CSV line.

The following reading modes are supported for different call logs:

- `nokiatool.sh phonebook-read last` - view/export last dialed numbers;
- `nokiatool.sh phonebook-read outgoing` - view/export all dialed numbers;
- `nokiatool.sh phonebook-read received` - view/export all received calls;
- `nokiatool.sh phonebook-read missed` - view/export all missed calls.

All call log entries are exported in the following CSV line format: `<index>,<number>,"<date>","<time>"`. You can also omit indexes by passing `short` as the last parameter. Contact names __are not__ exported due to encoding issues present in internal call log representation of the device. But this should not be a problem: once you have exported the phonebooks, you can match the necessary names using other tools.

### Writing (individual)

To create, update and delete individual phonebook entries, the following commands are supported for each `<type>`, where `<type>` can be either `phone` (device memory) or `sim` (current selected SIM card memory):

- `nokiatool.sh phonebook-create <type> <number> <name>` - create a new phonebook entry;
- `nokiatool.sh phonebook-update <type> <index> <number> <name>` - update an existing phonebook entry by its index;
- `nokiatool.sh phonebook-delete <type> <index>` - erase an existing phonebook entry by its index.

For example: `nokiatool.sh phonebook-create sim 5433 My service` will write a local number 5433 to current SIM card memory, and `nokiatool.sh phonebook-update phone 23 +1234567890 My American Friend` will update the cell #23 with an international number on the phone memory.

When creating or updating any entry, contact name can be specified without quotes but all usual escaping rules apply.

### Bulk import

NokiaTool finally gets support for bulk contact import from CSV format. The command is the following:

`nokiatool.sh phonebook-import <type> < file.csv`

where `<type>` can be either `phone` (device memory) or `sim` (current selected SIM card memory).

Both short and full (with indexes) CSV formats are recognized. If indexes are present, NokiaTool will replace the phonebook entries present in those cells.

You can also pipe other programs stdout or create/modify entries by typing them directly in the console (end with Ctrl+D sequence) instead of specifying the CSV file to read (with `< file.csv`).

Note that bulk phonebook export/import are the most resource-heavy operations of NokiaTool so you may have to wait some time to get the job done.

Keypad emulation
----------------

New Nokias, just like any other MediaTek-based phones, provide complete support for keypad entry emulation. NokiaTool encapsulates this feature into a single `nokiatool.sh keypad "<keystring>"` command. The `<keystring>` can consist of everything you can find on the physical Nokia keypad: digits, * and # characters and all control keys that are encoded in a special way:

- Softkeys: `[` - left, `m` - central (menu), `]` - right
- Operating keys: `s` - send (call) key, `e` - hangup key
- Arrows: `<` - left, `>` - right, `^` - up, `v` - down

You can also get the above information by running `nokiatool.sh keypad-help`.

For example, the command `nokiatool.sh keypad "e[*111#svs"` will perform the following actions on a Nokia 105 DS: unlock the keypad, dial the *111# USSD code, press "Send" key to make the call, select the second SIM by pressing "Down" and actually send the USSD code by pressing "Send" again. Actually you can emulate any actions a normal user would perform on the phone.

Expert mode functions
---------------------

The following commands belong to the `expert` section and are meant to perform __potentially dangerous__ operations, so you really must know what you are doing, and proceed at your own risk only.

- GSM band selection: `nokiatool.sh expert band <900|euro|amer|auto>` - support heavily depends on the model and region, for Nokia 105 or 130 only `nokiatool.sh expert band 900` (select GSM900 mode only) makes a real difference from other supported modes (`euro` or `auto`)
- Backlight mode: `nokiatool.sh expert backlight <constant|normal>` - turn the display backlight constantly on or return it to the normal mode
- Audio playback test: `nokiatool expert audiotest <start|stop> <sound id> <style> [duration]` - MediaTek audio test (`style` can vary from 0 to 3)
- Audio loopback test: `nokiatool.sh expert loopback <on|off>` - whatever you say into the microphone is played in the speaker
- Audio routing: `nokiatool.sh expert audioroute <normal|headset|speaker>` - force routing all audio to speaker or headset or return to the normal mode

Raw AT control
--------------

Though this way is even more dangerous than `expert` section commands and it's advisable to use full-featured terminal application like Minicom for this, you can also send any raw AT command with:

`nokiatool.sh sendATcmd '<your_cmd>'`

Quotes (either single or double, single preferred) around `<your_cmd>` are mandatory. CR and/or LF characters are not needed (they are inserted automatically, you don't have to worry about line endings). Note that this command is write-only, i.e. it __will not__ read any response from the device. So use it only if you're absolutely sure about the result.

For example, you can also reboot your phone with a raw AT command in such a way: `nokiatool.sh sendATcmd 'AT+CFUN=1,1'`

If you send an AT command after which the device awaits some raw text data following (for example, `AT+CMGW`) using this method, you'll have to complete the command sequence using a terminal application (like Minicom) or use `sendTextData` subcommand as the following:

`nokiatool.sh sendTextData '<your text>'`

Quotes around `<your text>` are mandatory here too. So, for example, you can save a simple Latin-based SMS draft with the following sequence:

```
nokiatool.sh sendATcmd 'AT+CMGF=1'
nokiatool.sh sendATcmd 'AT+CMGW'
nokiatool.sh sendTextData "Don\'t forget to buy some milk"
```

But again, be very careful!

Future development plans
------------------------

### For sooner development

- Information commands
- Ability to use a number from CSV phonebook dump for dialing/SMS

### For far-future development

- Concatenated SMS
- GUI frontend

### Will never be implemented (due to lack of device support)

- File system interaction (`AT+ESUO=3` and respective file system commands are not supported)
- GPRS modem functionality (`AT+CG` commands are not supported at all)
- SMS listings (`AT+CMGL` is not supported)
- USSD queries (`AT+CUSD` / `AT+ECUSD` are not supported)
- Phonebook immediate on-device search (`AT+CPBF` isn't supported)