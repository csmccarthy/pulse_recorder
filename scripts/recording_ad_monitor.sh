
# in_chunk_idx=$1
monitor_idx=$1
url=$2

echo "ad monitor $$ initializing for song $monitor_idx"

wait_time=0
while [[ $wait_time -le 30 ]] && [[ ! -f "./song_${monitor_idx}_ad_signal.txt" ]]
do
  sleep 1
  wait_time=$(( $wait_time + 1 ))
done


if [[ -f "transient/song_${monitor_idx}_ad_signal.txt" ]]
then # This means that one of the recordings encountered an ad and will need to be rebooted

	echo ad monitor $$ "--- ad detected, killing old monitor and restarting ---"
	echo ad monitor $$ "checking song $monitor_idx info in recording ad monitor"

	song_info="$(cat transient/song_${monitor_idx}_info.txt)"
	readarray -td '' song_info_arr < <(awk '{ gsub(/:::/,"\0"); print; }' <<<"$song_info:::"); unset 'a[-1]';
	name="${song_info_arr[0]}"
	sec="${song_info_arr[1]}"


	pid_info="$(cat transient/monitor_${monitor_idx}_pids.txt)"
	readarray -td '' pid_info_arr < <(awk '{ gsub(/:::/,"\0"); print; }' <<<"$pid_info:::"); unset 'a[-1]';
	recording_pid="${pid_info_arr[0]}"
	monitor_pid="${pid_info_arr[1]}"
	read -r chrome_pid < "transient/chrome_${monitor_idx}_pid.txt"

	kill $recording_pid
	kill $monitor_pid
	kill $chrome_pid

	rm "transient/song_${monitor_idx}_ad_signal.txt"
	rm "transient/monitor_${monitor_idx}_pids.txt"
	rm "transient/chrome_${monitor_idx}_pid.txt"
	rm "transient/${name}.wav"

	echo ad monitor $$ $url
	echo ad monitor $$ $monitor_idx
	echo ad monitor $$ $name
	echo ad monitor $$ $sec

	# TODO: sleep only the minimum required time based on place in url_arr 
	sleep 60 # ensure that we've finished processing the other urls in the chunk before restarting
	./dynamic_sink_input_monitor.sh $monitor_idx "$name" $sec &
	MONITOR_PID=$!
	node no_ad_record.js $monitor_idx $url & # this process is killed by sink_input_monitor	
	RECORD_PID=$!
    ./recording_ad_monitor.sh $1 $2 &
	AD_RECORD_PID=$!

	wait $MONITOR_PID $RECORD_PID $AD_RECORD_PID

	echo ad monitor $$ terminating after handling ads
else
	echo ad monitor $$ did not detect ads, script terminating
fi