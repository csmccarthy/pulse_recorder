
sink_name=$1

sink_inp=''
stdbuf -oL pactl subscribe |
  while IFS= read -r line
  do
    echo hi
    if test "$(echo $line | grep $'\'new\' on sink-input \#[0-9]*')" != ''
    then
        line_arr=($(echo $line | grep $'\'new\' on sink-input \#[0-9]*'))
        sink_inp=${line_arr[4]:1}
        pacmd move-sink-input ${line_arr[4]:1} $sink_name
        echo "switching sink input index $sink_inp to sink $sink_name"
        kill $$
        break
    fi
  done