Configure image to point to the develop fleet, set ethernet as Network Connection
```bash
source /home/wilmer/Documents/Kronos-Project/rover/configs/session_credentials.sh
balena login --token $BALENA_TOKEN
IMAGE_PATH="/home/wilmer/balena-jetson-jp5/build/tmp/deploy/images/kiwi-xavier/balena-image-kiwi-xavier.balenaos-img"
balena os configure $IMAGE_PATH --fleet RKiwi-4X-Develop --config-network ethernet
```

Check if there is an NVIDIA device connected to flash:
```bash
lsusb | grep NVIDIA
```

After that, you can flash the device using the following command:

```bash
IMAGE_PATH="/home/wilmer/balena-jetson-jp5/build/tmp/deploy/images/kiwi-xavier/balena-image-kiwi-xavier.balenaos-img"
cd /home/wilmer/jetson-custom/jetson-flash-jp5/
./bin/cmd.js -f $IMAGE_PATH -m jetson-xavier -p -o downloads --acceptLicense yes
```


