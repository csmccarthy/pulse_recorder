#!/bin/bash
CHUNK_SIZE=4

touch 'transient/processing_signal.txt'

chunk=$(head -$CHUNK_SIZE urls.txt)
leftover=$(tail -n +$(($CHUNK_SIZE+1)) urls.txt)
touch "transient/temp.txt"
echo "$chunk" > "transient/temp.txt"
echo "$leftover" > "urls.txt"


i=0
while [[ -f "transient/temp.txt" ]]
do
  j=0
  url_arr=()
  echo "downloading the following songs:"
  while read -r line && [[ $j -lt $CHUNK_SIZE ]]
  do
    j=$(( $j + 1 ))
    url_arr+=($line)
    echo $line
  done < "transient/temp.txt"
  rm "transient/temp.txt"

  ./process_url_chunk.sh $i ${url_arr[@]}
  i=$(( $i + ${#url_arr[@]} ))

  chunk=$(head -$CHUNK_SIZE urls.txt)
  leftover=$(tail -n +$(($CHUNK_SIZE+1)) urls.txt)
  touch "transient/temp.txt"
  echo "$chunk" > "transient/temp.txt"
  echo "$chunk" > "processed_urls.txt"
  echo "$leftover" > "urls.txt"
  file_size=$(wc -c transient/temp.txt | awk '{print $1}')
  if [ $file_size == 1 ]
  then
    rm "transient/temp.txt"
  fi
done

rm 'transient/processing_signal.txt'
touch 'transient/finished_signal.txt'

pacmd unload-module module-null-sink
echo recording script $$ terminating