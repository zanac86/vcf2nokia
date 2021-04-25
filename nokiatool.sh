#!/bin/bash
# NokiaTool - control MediaTek-based Nokia phones from your PC
# (c) Suborg 2016

# change two following lines for your specific device, mine are for MediaTek-based Nokia 130 and new 105
MODEM='/dev/ttyUSB1' # Nokia opens two serial ports, we need the second one to send control commands
DRIVERINIT='modprobe usbserial vendor=0x0421 product=0x069a' # init Nokia usb2serial driver (not needed for some models if they are autodetected)

# modem interaction API

CR="$(echo -e '\r')"
FD=8

function prepareModem {
	stty -F $MODEM -parenb -parodd -cmspar cs8 hupcl -cstopb cread clocal -crtscts ignbrk -brkint -ignpar -parmrk -inpck -istrip -inlcr -igncr -icrnl -ixon -ixoff -iuclc -ixany -imaxbel -iutf8 -opost -olcuc -ocrnl -onlcr -onocr -onlret -ofill -ofdel nl0 cr0 tab0 bs0 vt0 ff0 -isig -icanon -iexten -echo -echoe -echok -echonl -noflsh -xcase -tostop -echoprt -echoctl -echoke -extproc
}

function sendATcmd {
	local cmd="$1"
	echo -ne "$cmd$CR" >&${FD}
	sleep 1
}

function sendTextData {
	local text="$*"
	echo -ne "$text\x1A" >&${FD}
	sleep 1
}

function readResponse {
	expectedString="$1"
	timeout="$2"
	[[ -z $timeout ]] && timeout=1
	respString=''
	while read -d "$CR" -u$FD -t $timeout -s -r RESP; do
		if [[ $? -ge 128 ]] ; then return 1 ; fi
		if [[ $RESP == "ERROR" ]] ; then return 1; fi
		[[ $RESP == ${expectedString}* ]] && respString="$respString$RESP\n"
	done
	echo -ne "$respString"
	return 0
}

# encoder

function utf8topdu {
	echo -n "$*"|iconv -f utf-8 -t ucs-2be|od -t x1 -An |tr -d '\n '|tr 'a-f' 'A-F'
}

# decoder 

function pdutoutf8 {
	echo -ne "$(echo -n $* | sed -e 's/../\\x&/g')" | iconv -f ucs-2be -t utf-8
}

# print info messages

function printinfo {
	echo "$@" 1>&2;
}

# encode PDU: encodePDU <destination number> <normal|flash> text

function encodePDU {
	local num="$(echo $1|sed 's/[^0-9]*//g')"
	local type="$2"
	shift 2
	local text="$*"
	local numlen=${#num}
	[[ $((numlen%2)) -eq 1 ]] && num="${num}F"
	
	local PDU="003100$(printf '%02X' $numlen)91$(echo -n $num|iconv -f utf-16le -t utf-16be)00"
	
	if [[ $type == 'flash' ]]; then
		PDU="${PDU}1"
	else
		PDU="${PDU}0"
	fi

	PDU="${PDU}8FF$(printf '%02X' $((${#text}*2)))$(utf8topdu $text)"
	echo -n "$PDU"
	
}

function encodeDraftPDU {
	local type="$1"
	shift 1
	local text="$*"
	local typevar=0
	[[ $type == 'flash' ]] && typevar=1
	echo -n "001100009100${typevar}8AA$(printf '%02X' $((${#text}*2)))$(utf8topdu $text)"
}


# Send SMS: nokiatool sms number message
# number in international format, message can be passed with no quotes
# Unicode messages mustn't exceed 70 characters

function sms {
	sendATcmd 'ATZ'
	local number="$1"
	shift 1
	local text="$*"
	printinfo "Sending SMS..."
	if [[ -n "$(echo $text|grep -P '[^\x00-\x7f]')" ]]; then #unicode detected
		local PDU="$(encodePDU $number normal $text)"
		sendATcmd 'AT+CMGF=0'
		sendATcmd "AT+CMGS=$(( ${#PDU}/2-1 ))"
		sendTextData "$PDU"
	else #latin encoding detected
		sendATcmd 'AT+CMGF=1'
		sendATcmd "AT+CMGS=\"$number\""
		sendTextData "$text"
	fi
	local resp=$(readResponse '+CMGS')
	if [[ $? -eq 0 ]]; then
		printinfo "SMS sent"
	else
		printinfo "SMS error occurred, please try again"
	fi
}

# Send Flash SMS: nokiatool flash-sms number message
# number in international format, message can be passed with no quotes
# Unicode only, all messages mustn't exceed 70 characters

function flash-sms {
	sendATcmd 'ATZ'
	local number="$1"
	shift 1
	local text="$*"
	printinfo "Sending Flash SMS..."
	local PDU="$(encodePDU $number flash $text)"
	sendATcmd 'AT+CMGF=0'
	sendATcmd "AT+CMGS=$(( ${#PDU}/2-1 ))"
	sendTextData "$PDU"
	local resp=$(readResponse '+CMGS')
	if [[ $? -eq 0 ]]; then
		printinfo "Flash SMS sent"
	else
		printinfo "SMS error occurred, please try again"
	fi
}

# Save SMS draft (as a note): nokiatool draft message
# message can be passed with no quotes
# Unicode messages mustn't exceed 70 characters

function draft {
	sendATcmd 'ATZ'
	local text="$*"
	printinfo "Saving draft to SMS memory..."
	if [[ -n "$(echo $text|grep -P '[^\x00-\x7f]')" ]]; then #unicode detected
		sendATcmd 'AT+CMGF=0'
		local PDU="$(encodeDraftPDU normal $text)"
		sendATcmd "AT+CMGW=$(( ${#PDU}/2-1 )),7"
		sendTextData "$PDU"
	else #latin encoding detected
		sendATcmd 'AT+CMGF=1'
		sendATcmd 'AT+CMGW'
		sendTextData "$text"
	fi
	local resp=$(readResponse '+CMGW')
	if [[ $? -eq 0 ]]; then
		printinfo "Draft saved"
	else
		printinfo "Saving error occurred, please try again"
	fi
}

# Reboot the phone

function reboot {
	sendATcmd 'AT+CFUN=1,1'
	printinfo "Phone rebooted"
}

# Dial a number: nokiatool dial 466

function dial {
	sendATcmd 'ATZ'
	local num="$1"
	sendATcmd "ATD${num};"
	printinfo "Number $num dialed"
}


# Answer a call

function pickup {
	sendATcmd 'ATA'
	printinfo "Call answered"
}

# Hangup active call

function hangup {
	sendATcmd 'AT+CHUP'
	printinfo "Hangup"
}

# SIM related functions

function sim {
	local arg="$1"
	case "$arg" in
		off)
			sendATcmd 'AT+CFUN=4,0' #could also use AT+EFUN=0 but AT+CFUN=4,0 is better documented
			printinfo "Flight mode active"
			;;
		current-off)
			sendATcmd 'AT+CFUN=0,0'
			printinfo "Current selected SIM card disabled"
			;;
		first)
			sendATcmd 'AT+EFUN=1'
			printinfo "First SIM only active"
			;;
		second)
			sendATcmd 'AT+EFUN=2'
			printinfo "Second SIM only active"
			;;
		both)
			sendATcmd 'AT+EFUN=3'
			printinfo "Both SIMs active"
			;;
		select-first)
			sendATcmd 'AT+ESUO=4'
			printinfo "First SIM selected for terminal operations"
			;;
		select-second)
			sendATcmd 'AT+ESUO=5'
			printinfo "Second SIM selected for terminal operations"
			;;
	esac
} 

# keypad emulation

function keypad {
	local sequence="$*"
	sendATcmd "AT+CKPD=\"$sequence\""
	printinfo "Keypad sequence sent"
}

function keypad-help {
	printinfo 'Special characters for "nokiatool keypad" command:'
	printinfo 'Softkeys: [ - left, m - central (menu), ] - right'
	printinfo 'Operating keys: s - send (call) key, e - hangup key'
	printinfo 'Arrows: < - left, > - right, ^ - up, v - down'
}

# expert mode functions (run them only if you REALLY know what you're doing!)

function expert {
	local arg="$1"
	local arg2="$2"
	case "$arg" in
		band)
			case "$arg2" in
				900)
					sendATcmd 'AT+EPBSE=2,0'
					printinfo 'GSM900-only mode selected if supported'
					;;
				euro)
					sendATcmd 'AT+EPBSE=10,1'
					printinfo 'European GSM bands (900/1800) selected if supported'
					;;
				amer)
					sendATcmd 'AT+EPBSE=144,0'
					printinfo 'American GSM bands (850/1900) selected if supported'
					;;
				auto)
					sendATcmd 'AT+EPBSE=255,65535'
					printinfo 'Bands selected automatically'
					;;
			esac
			;;
		loopback)
			case "$arg2" in
				on)
					sendATcmd 'AT+EALT=1'
					printinfo 'Loopback test mode on'
					;;
				off)
					sendATcmd 'AT+EALT=0'
					printinfo 'Loopback test mode off'
					;;
			esac
			;;
		audioroute)
			case "$arg2" in
				speaker)
					sendATcmd 'AT+ESAM=2'
					printinfo 'Audio routed to speaker only'
					;;
				headset)
					sendATcmd 'AT+ESAM=1'
					printinfo 'Audio routed to headset only'
					;;
				normal)
					sendATcmd 'AT+ESAM=0'
					printinfo 'Audio routed in normal mode'
					;;
			esac
			;;
		backlight)
			case "$arg2" in
				constant)
					sendATcmd 'AT+ELSM=0'
					printinfo 'Switched backlight to constant-on mode'
					;;
				normal)
					sendATcmd 'AT+ELSM=1'
					printinfo 'Switched backlight to normal mode'
					;;
			esac
			;;
		audiotest)
			case "$arg2" in
				start)
					id="$3"
					style="$4"
					duration="$5"
					finalcmd="AT+CASP=1,$id,$style"
					if [[ "$duration" ]]; then
						finalcmd="$finalcmd,$duration"
					fi
					sendATcmd "$finalcmd"
					printinfo "Started sound with ID $id"
					;;
				stop)
					id="$3"
					sendATcmd "AT+CASP=2,$id"
					printinfo "Stopped sound with ID $id"
					;;
			esac
			;;
	esac
}


#phonebook manipulation

function phonebook-type-convert {
	case "$1" in
		sim) #current SIM phonebook
			echo 'SM'
		;;
		phone) #device phonebook
			echo 'ME'
		;;
		outgoing) #outgoing call log
			echo 'DC'
		;;
		last) #last dial call log
			echo 'LD'
		;;
		missed) #missed incoming call log
			echo 'MC'
		;;
		received) #received incoming call log
			echo 'RC'
		;;
		fdn)  #FDN number list
			echo 'FD'
		;;
		own) #own number list
			echo 'ON'
		;;
	esac
}

function phonebook-read {
	local type="$(phonebook-type-convert $1)"
	local omit="$2"
	sendATcmd 'ATZ'
	sendATcmd 'AT+CSCS="UCS2"'
	sendATcmd "AT+CPBS=\"$type\""
	printinfo -e "Scanning entries (may take some time)...\n"
	local rangeArg=''
	until [[ -n "$rangeArg" ]]; do
		sendATcmd 'AT+CPBR=?'
		rangeArg=$(readResponse '+CPBR'|grep -Po '\(.*\)'|tr -d '()'|tr - ,)
	done
	sendATcmd "AT+CPBR=${rangeArg}"
	local rawResponse="$(readResponse '+CPBR')"
	local IFS=$'\n'
	if [[ $type == 'SM' || $type == 'ME' || $type == 'ON' || $type == 'FD' ]]; then
		for entry in $rawResponse; do
			local localEntry=$(echo $entry|tr -d ',"')
			local index=$(echo $localEntry|cut -d ' ' -f 2)
			local phone=$(echo $localEntry|cut -d ' ' -f 3)
			local numtype=$(echo $localEntry|cut -d ' ' -f 4)
			local name=$(pdutoutf8 $(echo $localEntry|cut -d ' ' -f 5)|sed 's/\"/""/g')
			[[ $numtype == "145" ]] && phone="+$phone"
			if [[ $omit == "short" ]]; then
				echo -e "\"${name}\",$phone"
			else
				echo -e "$index,\"${name}\",$phone"
			fi
		done
	else
		for entry in $rawResponse; do
			local localEntry=$(echo $entry|sed 's/\+CPBR:\ //g'|tr -d '"')
			local index=$(echo $localEntry|cut -d ',' -f 1)
			local phone=$(echo $localEntry|cut -d ',' -f 2)
			local numtype=$(echo $localEntry|cut -d ',' -f 3)
			local date=$(echo $localEntry|cut -d ',' -f 5)
			local time=$(echo $localEntry|cut -d ',' -f 6)
			[[ $numtype == "145" ]] && phone="+$phone"
			if [[ $omit == "short" ]]; then
				echo -e "$phone,\"${date}\",\"${time}\""
			else
				echo -e "$index,$phone,\"${date}\",\"${time}\""
			fi
		done
	fi
	printinfo -e "\nDone"
}

# phonebook modification commands

function phonebook-create {
	local type="$(phonebook-type-convert $1)"
	local number="$2"
	shift 2
	local name="$(utf8topdu $*)"
	local numtype=129
	if [[ $number == "+"* ]]; then
		numtype=145
		number="${number:1}"
	fi
	sendATcmd 'AT+CSCS="UCS2"'
	sendATcmd "AT+CPBS=\"$type\""
	sendATcmd "AT+CPBW=,\"${number}\",$numtype,\"${name}\""
	printinfo "New entry written to $type memory"
}

function phonebook-update {
	local type="$(phonebook-type-convert $1)"
	local index="$2"
	local number="$3"
	shift 3
	local name="$(utf8topdu $*)"
	local numtype=129
	if [[ $number == "+"* ]]; then
		numtype=145
		number="${number:1}"
	fi
	sendATcmd 'AT+CSCS="UCS2"'
	sendATcmd "AT+CPBS=\"$type\""
	sendATcmd "AT+CPBW=$index,\"${number}\",$numtype,\"${name}\""
	printinfo "Entry $index updated in $type memory"
}

function phonebook-delete {
	local type="$(phonebook-type-convert $1)"
	local index="$2"
	sendATcmd "AT+CPBS=\"$type\""
	sendATcmd "AT+CPBW=$index"
	printinfo "Entry $index deleted from $type memory"
}

# import command: replaces when indexes present, writes to new cells when they are omitted (short format)
# accepts phonebook type (sim or phone)
# csv is read from stdin line-by-line (you can redirect a file with e.g. nokiatool.sh phonebook-import phone < phones.csv)

function phonebook-import {
	local type="$(phonebook-type-convert $1)"
	local count=0
	printinfo "Importing contacts (please be patient)..."
	sendATcmd 'AT+CSCS="UCS2"'
	sendATcmd "AT+CPBS=\"$type\""
	while read csvline; do
		if [[ ! "$csvline" =~ ^[0-9]+,.* ]]; then
			csvline=",$csvline"
		fi
		local index=$(echo -n "$csvline"|cut -d ',' -f 1)
		local number=$(echo -n "$csvline"|rev|cut -d ',' -f 1|rev)
		local name=$(echo -n "$csvline"|cut --complement -d ',' -f 1|rev|cut --complement -d ',' -f 1|rev)
		[[ $index == '"'* && $index == *'"' ]] && index="${index:1:-1}"
		[[ $number == '"'* && $number == *'"' ]] && number="${number:1:-1}"
		[[ $name == '"'* && $name == *'"' ]] && name="${name:1:-1}"
		name="$(echo -n $name| sed 's/\"\"/\"/g')"
		local numtype=129
		if [[ $number == "+"* ]]; then
			numtype=145
			number="${number:1}"
		fi
		sendATcmd "AT+CPBW=$index,\"${number}\",$numtype,\"$(utf8topdu $name)\""
		count=$(( $count + 1 ))
	done
	printinfo "$count contacts imported into $type memory"
}


# actual command runner

function suexecWrap {
	printinfo "Connecting to device..."
	cmd="$1"
	shift 1
	local args=$*
	$DRIVERINIT
	if [[ ! -c $MODEM ]]; then
		printinfo "Device connection failed!"
		exit 1
	fi
	printinfo ''
	prepareModem
	eval "exec ${FD}<>$MODEM"
	$cmd $args
	eval "exec ${FD}<&-"
	eval "exec ${FD}>&-"
}

if [[ "$1" == "help" ]]; then
	${2}-help
	exit 1
fi

CURSCRIPT="$(readlink -f $0)"
ARGS=$*
if [[ "$EUID" -ne 0 ]]; then
	printinfo "Please authorize device access"
	sudo bash -c "$CURSCRIPT $ARGS"
else
	printinfo "Device access granted"
	suexecWrap $ARGS
fi