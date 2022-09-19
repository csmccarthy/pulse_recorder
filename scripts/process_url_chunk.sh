
starting_idx=$1
args=("$@")
url_arr=("${args[@]:1}")
echo $url_arr

name_arr=()
sec_arr=()
for url_idx in ${!url_arr[@]}
do
    current_idx=$(( $url_idx + $starting_idx ))
    echo ${url_arr[$url_idx]}
    node no_ad_song_info.js ${url_arr[$url_idx]} $current_idx
    song_info="$(cat transient/song_${current_idx}_info.txt)"
    readarray -td '' song_info_arr < <(awk '{ gsub(/:::/,"\0"); print; }' <<<"$song_info:::"); unset 'a[-1]';
    name_arr+=("${song_info_arr[0]}")
    sec_arr+=("${song_info_arr[1]}")
done


MONITOR_PIDS=()
RECORD_PIDS=()
AD_MONITOR_PIDS=()
for url_idx in ${!url_arr[@]}
do
    current_idx=$(( $url_idx + $starting_idx ))
    echo song $(($current_idx)): "${name_arr[$url_idx]}", runtime ${sec_arr[$url_idx]}s
	./dynamic_sink_input_monitor.sh $current_idx "${name_arr[$url_idx]}" "${sec_arr[$url_idx]}" &
    MONITOR_PIDS+=($!)
    node no_ad_record.js $current_idx ${url_arr[url_idx]} &
    RECORD_PIDS+=($!)
    ./recording_ad_monitor.sh $current_idx ${url_arr[url_idx]} &
    AD_MONITOR_PIDS+=($!)
    sleep 5
done

wait ${RECORD_PIDS[@]} ${MONITOR_PIDS[@]} ${AD_MONITOR_PIDS[@]}

for url_idx in ${!url_arr[@]}
do
    file_size=$(wc -c "music/${name_arr[$url_idx]}.mp3" | awk '{print $1}')
    if [ ! -f "music/${name_arr[$url_idx]}.mp3" ] \
        || [ ! -f "music/${name_arr[$url_idx]}.bpm-tag" ] \
        || [ $file_size -lt $(( 15602 * (${sec_arr[$url_idx]} - 10) )) ]
    then
        echo -e "\n${url_arr[url_idx]}" >> urls.txt
    fi
done

echo url chunk processor $$ terminating