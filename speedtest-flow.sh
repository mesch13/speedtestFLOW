#!/usr/bin/env bash
###########################################################################
# Originally written by: Henrik Bengtsson, 2014
# https://github.com/HenrikBengtsson/speedtest-cli-extras
# Modified to use IFTTT by: Alasdair Allan, 2015
# License: GPL (>= 2.1) [http://www.gnu.org/licenses/gpl.html]
# Modified again for use with FLOW by Ryan Mesches 2016
###########################################################################

# Character for separating values
# (commas are not safe, because some servers return speeds with commas)
sep=";"

# Temporary file holding speedtest-cli output
user=$USER
if test -z $user; then
  user=$USERNAME
fi
log=/tmp/$user/speedtest-csv.log

# Local functions
function str_extract() {
 pattern=$1
 # Extract
 res=`grep "$pattern" $log | sed "s/$pattern//g"`
 # Drop trailing ...
 res=`echo $res | sed 's/[.][.][.]//g'`
 # Trim
 res=`echo $res | sed 's/^ *//g' | sed 's/ *$//g'`
 echo $res
}

# Display header?
if test "$1" = "--header"; then
  start="start"
  stop="stop"
  from="from"
  from_ip="from_ip"
  server="server"
  server_dist="server_dist"
  server_ping="server_ping"
  download="download"
  upload="upload"
  share_url="share_url"
else
  mkdir -p `dirname $log`

  start=`date +"%Y-%m-%d %H:%M:%S"`

  if test -n "$SPEEDTEST_CSV_SKIP" && test -f "$log"; then
    # Reuse existing results (useful for debugging)
    1>&2 echo "** Reusing existing results: $log"
  else
    # Query Speedtest
    /usr/local/bin/speedtest-cli --share > $log
  fi
  
  stop=`date +"%Y-%m-%d %H:%M:%S"`
  
  # Parse
  from=`str_extract "Testing from "`
  from_ip=`echo $from | sed 's/.*(//g' | sed 's/).*//g'`
  from=`echo $from | sed 's/ (.*//g'`
  
  server=`str_extract "Hosted by "`
  server_ping=`echo $server | sed 's/.*: //g'`
  server=`echo $server | sed 's/: .*//g'`
  server_dist=`echo $server | sed 's/.*\\[//g' | sed 's/\\].*//g'`
  server=`echo $server | sed 's/ \\[.*//g'`
  
  download=`str_extract "Download: "`
  upload=`str_extract "Upload: "`
  share_url=`str_extract "Share results: "`
fi

# Standardize units?
if test "$1" = "--standardize"; then
  download=`echo $download | sed 's/Mbits/Mbit/'`
  upload=`echo $upload | sed 's/Mbits/Mbit/'`
fi

# Send to FLOW
value1=`echo $server_ping | cut -d" " -f1`
value2=`echo $download | cut -d" " -f1`
value3=`echo $upload | cut -d" " -f1` 
json="{\"value1\":\"${value1}\",\"value2\":\"${value2}\",\"value3\":\"${value3}\"}"
curl -X POST -H "Content-Type: application/json" -d "${json}" https://prod-04.logic.azure.com:443/workflows/26e5518c69634f9f861a5588d205caaa/triggers/manual/run?api-version=2015-08-01-preview&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=B2USgtW523WyJyRN_W30sbdm_V3jCkscnaDNoGw-WZY
