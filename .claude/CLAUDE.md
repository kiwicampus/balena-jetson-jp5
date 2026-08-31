This is a git repo that contains the Yocto recipes for Jetson Xavier devices running Balena OS.

You will focus in the coustom device kiwi-xavier, and the recipes in the folder `layers/meta-balena-jetson`.

When developing a new feature, understand the context before proposing changes, look for things that may be missing in the prompt and ask clarifying questions.

Save a change log bitacore to know what have you tried

The build command of for this image is:

```bash
./balena-yocto-scripts/build/barys -m kiwi-xavier
```

after build an image you need to link it to our balena fleet, do it using this commands:

```bash
source /home/wilmer/Documents/Kronos-Project/rover/configs/session_credentials.sh
balena login --token $BALENA_TOKEN
IMAGE_PATH="/home/wilmer/balena-jetson-jp5/build/tmp/deploy/images/kiwi-xavier/balena-image-kiwi-xavier.balenaos-img"
balena os configure $IMAGE_PATH --fleet RKiwi-4X-Develop
```



