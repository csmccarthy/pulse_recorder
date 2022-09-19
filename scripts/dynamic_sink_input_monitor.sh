
monitor_idx=$1
file_name=$2
run_time=$3

echo monitor $$ "$SINK_INP_IDX"
SINK_NAME="record$monitor_idx"


pacmd load-module module-null-sink sink_name=$SINK_NAME sink_properties=device.description=$SINK_NAME
echo "sink $SINK_NAME created"

./move_input.sh $SINK_NAME # await new sink input creation and move it to $SINK_NAME when detected

echo monitor $$ index $monitor_idx recording to file $file_name.wav...
parecord --channels=2 -d $SINK_NAME.monitor "transient/$file_name.wav" &
RECORD_PID=$!

touch "transient/monitor_${monitor_idx}_pids.txt"
echo "${RECORD_PID}:::$$" > "transient/monitor_${monitor_idx}_pids.txt"

sleep $(( ${run_time} ))

read -r CHROME_PID < "transient/chrome_${monitor_idx}_pid.txt"
echo monitor $$ index $monitor_idx killing recording $RECORD_PID...
kill $RECORD_PID
echo monitor $$ index $monitor_idx killing chrome $CHROME_PID...
kill $CHROME_PID

echo monitor $$ converting "$file_name.wav" to mp3
sox "transient/$file_name.wav" "transient/$file_name.mp3"
rm -f "transient/$file_name.wav"
mv "transient/$file_name.mp3" "music/$file_name.mp3"
./get_bpm_tag.sh "$file_name" # tag mp3 with its bpm and create the .bpm-tag file alongside it

# file cleanup
rm -f "transient/chrome_${monitor_idx}_pid.txt"
rm -f "transient/song_${monitor_idx}_info.txt"
rm -f "transient/monitor_${monitor_idx}_pids.txt"

echo monitor $$ index $monitor_idx terminating...
