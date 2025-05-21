#!/bin/bash

# Get the current brightness using our DisplayHelper bridge
while true; do
    # The DisplayHelper class logs the brightness, so we can get it from the system log
    # This assumes the app is running and logging
    brightness=$(log show --predicate 'eventMessage contains "Current brightness:"' --last 1s | grep "Current brightness:" | tail -n 1 | cut -d":" -f2 | tr -d ' ')
    
    if [ ! -z "$brightness" ]; then
        # Convert to percentage
        percentage=$(echo "scale=2; $brightness * 100" | bc)
        echo "Current brightness: $percentage%"
    else
        echo "Could not get brightness (is SlimMate running?)"
    fi
    
    sleep 2
done 