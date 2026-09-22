#!/usr/bin/env bash
set -u

root=/sys/class/power_supply
total_power_uw=0
total_energy_now_uwh=0
total_energy_full_uwh=0
capacity_sum=0
battery_count=0
has_power=0
status="Unknown"

read_int() {
  local path=$1 value
  [[ -r "$path" ]] || return 1
  value=$(tr -d '[:space:]' < "$path")
  [[ "$value" =~ ^-?[0-9]+$ ]] || return 1
  printf '%s' "$value"
}

for battery in "$root"/BAT*; do
  [[ -d "$battery" ]] || continue
  if [[ -r "$battery/type" ]] && [[ $(tr -d '[:space:]' < "$battery/type") != Battery ]]; then
    continue
  fi

  ((battery_count += 1))

  if [[ -r "$battery/status" ]]; then
    current_status=$(tr -d '\n' < "$battery/status")
    if [[ "$current_status" == Charging ]]; then
      status=Charging
    elif [[ "$current_status" == Discharging && "$status" != Charging ]]; then
      status=Discharging
    elif [[ "$status" == Unknown ]]; then
      status=$current_status
    fi
  fi

  if value=$(read_int "$battery/capacity"); then
    ((capacity_sum += value))
  fi

  if value=$(read_int "$battery/energy_now"); then
    ((total_energy_now_uwh += value))
  elif charge=$(read_int "$battery/charge_now") && voltage=$(read_int "$battery/voltage_now"); then
    ((total_energy_now_uwh += charge * voltage / 1000000))
  fi

  if value=$(read_int "$battery/energy_full"); then
    ((total_energy_full_uwh += value))
  elif charge=$(read_int "$battery/charge_full") && voltage=$(read_int "$battery/voltage_now"); then
    ((total_energy_full_uwh += charge * voltage / 1000000))
  fi

  if value=$(read_int "$battery/power_now"); then
    (( value < 0 )) && value=$((-value))
    ((total_power_uw += value))
    has_power=1
  elif voltage=$(read_int "$battery/voltage_now") && current=$(read_int "$battery/current_now"); then
    (( current < 0 )) && current=$((-current))
    ((total_power_uw += voltage * current / 1000000))
    has_power=1
  fi
done

if ((battery_count == 0)); then
  jq -cn '{available:false, watts:"N/A", watts_value:0, capacity:0, status:"Unavailable", energy_now:0, energy_full:0, time_seconds:0}'
  exit 0
fi

capacity=$((capacity_sum / battery_count))
watts_value=$(awk -v value="$total_power_uw" 'BEGIN { printf "%.4f", value / 1000000 }')
if ((has_power == 1)); then
  watts=$(awk -v value="$total_power_uw" 'BEGIN { printf "%.2fW", value / 1000000 }')
else
  watts="N/A"
fi
energy_now=$(awk -v value="$total_energy_now_uwh" 'BEGIN { printf "%.2f", value / 1000000 }')
energy_full=$(awk -v value="$total_energy_full_uwh" 'BEGIN { printf "%.2f", value / 1000000 }')
time_seconds=0
if ((total_power_uw > 0)); then
  if [[ "$status" == Charging ]] && ((total_energy_full_uwh > total_energy_now_uwh)); then
    time_seconds=$(((total_energy_full_uwh - total_energy_now_uwh) * 3600 / total_power_uw))
  elif [[ "$status" == Discharging ]]; then
    time_seconds=$((total_energy_now_uwh * 3600 / total_power_uw))
  fi
fi

jq -cn \
  --arg watts "$watts" \
  --arg status "$status" \
  --argjson watts_value "$watts_value" \
  --argjson capacity "$capacity" \
  --argjson energy_now "$energy_now" \
  --argjson energy_full "$energy_full" \
  --argjson time_seconds "$time_seconds" \
  '{available:true, watts:$watts, watts_value:$watts_value, capacity:$capacity, status:$status, energy_now:$energy_now, energy_full:$energy_full, time_seconds:$time_seconds}'
