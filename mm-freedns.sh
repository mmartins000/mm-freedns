#!/bin/bash

DATE=`date`
VERSION="0.1"
debug_date=`date +"%d/%m/%y %H:%M:%S"`

addcron () {
  if [ -z $minutes ]; then
    wasblank=1
    minutes="5"
  fi
  if [ $wasblank -eq 1 ]; then
    params2=`echo $PARAMS | sed -e 's/-c //'`
  else
    params2=`echo $PARAMS | sed -e "s/-c $minutes //"`
  fi
  echo -e "*/$minutes * * * * $PWD/"`basename $0`" $params2" | crontab
  exit 0
}

writetarget () {
  if [ -z $dfile ]; then
    dfile="/etc/mm-freedns.conf"
    if [ -z /etc/mm-freedns.conf ]; then
      touch /etc/mm-freedns.conf
    else
      exit 1
    fi
  else
    if [[ -z ${dfile} ]]; then
      touch $dfile
    else
      exit 1
    fi
  fi
  
  echo "your.hostname.com|web|freedns" > $dfile
  echo "fake.hostname.com|script|/usr/local/get-ppp0-ip.sh" >> $dfile
  echo "" >> $dfile
  exit 0
}

log () {
  TYPE=$1
  MSG=$2  
  if [ "$TYPE" == "DEBUG" ]; then
    if [ "$debug" == "on" ]; then
      echo -e $MSG >> $logfile
    fi
  else
    if [ "$logopt" == "yes" ]; then
      echo -e $MSG >> $logfile
    fi
  fi
}

readopts () {
  PARAMS=$@
  while getopts "u:p:f:lsh:dcw" optname
  do
    case "$optname" in
      "u")
         duser=$OPTARG
         ;;
      "p")
         dpass=$OPTARG
         ;;
      "f")
         dfile=$OPTARG
         ;;
      "l")
         logopt="yes"
         logfile=$OPTARG
         if [[ -z $logfile ]]; then
           logfile="/var/log/mm-freedns.log"
         fi
         ;;
      "s")
         sslopt="yes"
         ;;
      "c")
         minutes=$OPTARG
         addcron
         ;;
      "w")
         dfile=$OPTARG
         writetarget
         ;;
      "h")
         dhash=$OPTARG
         ;;
      "d")
         debug="on"
         ;;
      *)
         # Should not occur
         #echo "$0: Unknown error while processing option $1"
         ;;
    esac
  done
  return $OPTIND
}

readopts "$@"

if [ ! $# -gt 0 ]; then
  echo -e "\nMM-FreeDNS (afraid.org) Updater, version $VERSION"
  echo -e "Author: Marcelo Martins\n"
  echo -e "Usage: $0 [options]"
  echo -e "Options:"
  echo -e "\t-u <username>\n\t\t\tYour FreeDNS username.\n"
  echo -e "\t-p <password>\n\t\t\tYour FreeDNS password.\n"
  echo -e "\t-h <SHA-1 hash>\n\t\t\tUse SHA-1 hash instead of user/pass. Hash is sha1(user|pass)\n"
  echo -e "\t-f <config file>\n\t\t\tConfig file where hosts and methods are defined. [default: mm-freedns.conf]\n"
  echo -e "\t-l <optional: log file>\n\t\t\tLogs to the specified file. [default location and name: /var/log/mm-freedns.log]\n"
  echo -e "\t-s \n\t\t\tEnables SSL.\n"
  echo -e "\t-d \n\t\t\tEnables Debug mode, prints more info.\n"
  echo -e "\t-c <optional: minutes>\n\t\t\tAdds itself to crontab. [*/5 * * * * $PWD/"`basename $0`" (options)]\n"
  echo -e "\t-w <optional: config file>\n\t\t\tCreates example target/config file. [default location and name: /etc/mm-freedns.conf]\n"
  echo -e "Config file examples:"
  echo -e "\t\t\tyour.hostname.com|web|freedns"
  echo -e "\t\t\tfake.hostname.com|script|/usr/local/bin/get-ppp0-ip.sh\n"
  echo -e "Script output and example:"
  echo -e "\t\t\tMust return a single IP address."
  echo -e "\t\t\te.g.: /usr/sbin/pppoe-status | grep ppp0 | grep inet | cut -d't' -f2 | cut -d'p' -f1 | tr -d ' '\n"
  exit 1
fi

if [ -z $dhash ]; then
  if [ -z $duser ]; then
    echo "$0: user not specified."
    exit 1
  fi
  if [ -z $dpass ]; then
    echo "$0: password not specified."
    exit 1
  fi
fi

if [[ ! -f $logfile ]]; then
  touch $logfile
fi

if [[ "$sslopt" == "yes" ]]; then
  PROTOCOL="https"
else
  PROTOCOL="http"
fi

if [[ ! -z $dfile ]]; then
  TARGETS_FILE=$dfile
else
  TARGETS_FILE="/etc/mm-freedns.conf"
fi

if [ -z $dhash ]; then
  SHA1=`echo -n $duser"|"$dpass | sha1sum | cut -d' ' -f1`
else
  SHA1=$dhash
fi

# paste in the info url from your account
get_info_url=$PROTOCOL'://freedns.afraid.org/api/?action=getdyndns&sha='
get_info_url+=$SHA1

if [ ! -e "$TARGETS_FILE" ]
then
   echo "$0: config file $TARGETS_FILE does not exist."
   exit 1
else
   TARGETS=`cat "$TARGETS_FILE"`
   TMPVAR=( $TARGETS )
   NO_OF_TARGETS=${#TMPVAR[@]}
fi

# get the current dns settings...
for each in `curl -s "$get_info_url"`
do
  domain=`echo "$each" | cut -d"|" -f1`
  dns_ip=`echo "$each" | cut -d"|" -f2`
  update_url=`echo "$each" | cut -d"|" -f3`
  for each in $TARGETS
  do
    target_domain=`echo "$each" | cut -d"|" -f1`
    target_use=`echo "$each" | cut -d"|" -f2`
    target_run=`echo "$each" | cut -d"|" -f3`
    
    if [ "$debug" == "on" ]; then
      echo -e "DEBUG: $debug_date Red "$target_domain" "$target_use" "$target_run >> $logfile
    fi
    
    if [ "$target_domain" == "$domain" ]; then
      if [ "$target_use" == "web" ]; then #web
        if [ "$debug" == "on" ]; then
          echo -e "DEBUG: $debug_date target_use: "$target_use" target_domain: "$target_domain" domain: "$domain" url: "$updateurl >> $logfile
        fi
        if [[ "$logopt" == "yes" ]]; then
          echo -e "$DATE: "\\c >> $logfile
          echo -e "$domain - "\\c >> $logfile
          curl -s "$update_url" >> $logfile
        else
          curl -s "$update_url" >> /dev/null
        fi
      else #script
        target_eval=`sh $target_run`
        if [ "$target_eval" != "$dns_ip" ]; then
          if [ ! -z $target_eval ]; then
            run_url=$update_url"&address="$target_eval
          else
            log DEBUG "DEBUG: $debug_date target_eval: <NONE>"
          fi
          log DEBUG "DEBUG: $debug_date target_eval: $target_eval run_url: $run_url"
          #if [ "$debug" == "on" ]; then
          #  echo -e "DEBUG: $debug_date target_eval: "$target_eval" run_url: "$run_url >> $logfile
          #fi
          if [[ "$logopt" == "yes" ]]; then
            echo -e "$DATE: "\\c >> $logfile
            echo -e "$domain - "\\c >> $logfile
            curl -s "$run_url" >> $logfile
          else
            curl -s "$run_url" >> /dev/null
          fi
        else #$target_eval == $dns_ip
          log DEBUG "DEBUG: $debug_date target_eval: $target_eval == dns_ip: $dns_ip"
          #if [ "$debug" == "on" ]; then
          #  echo -e "DEBUG: $debug_date target_eval: "$target_eval" == dns_ip: "$dns_ip >> $logfile
          #fi
        fi
      fi
    else #$target_domain != $domain
      log DEBUG "DEBUG: $debug_date target_domain: $target_domain != domain: $domain"
      #if [ "$debug" == "on" ]; then
      #  echo -e "DEBUG: $debug_date target_domain: "$target_domain" != domain: "$domain >> $logfile
      #fi
    fi
  done
done
