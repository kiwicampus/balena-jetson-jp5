deviceTypesCommon = require '@resin.io/device-types/common'
{ networkOptions, commonImg, instructions } = deviceTypesCommon

BOARD_PREPARE  = 'Put the Kiwi-Xavier AGX board in recovery mode'
FLASH_TOOL = 'Unzip BalenaOS image and use the Jetson Flash tool to flash the board. Jetson Flash tool can be found at https://github.com/balena-os/jetson-flash'
DONE_FLASHING  = 'After flashing is completed, please wait until the board is rebooted'
module.exports =
	version: 1
	slug: 'jetson-xavier'
	aliases: [ 'jetson-xavier' ]
	name: 'Kiwi Xavier AGX'
	arch: 'aarch64'
	state: 'new'
	community: true
	private: false

	instructions: [
		BOARD_PREPARE
		FLASH_TOOL
		DONE_FLASHING
	]

	gettingStartedLink:
		windows: 'https://docs.resin.io/jetson-xavier/nodejs/getting-started/#adding-your-first-device'
		osx: 'https://docs.resin.io/jetson-xavier/nodejs/getting-started/#adding-your-first-device'
		linux: 'https://docs.resin.io/jetson-xavier/nodejs/getting-started/#adding-your-first-device'

	supportsBlink: false

	yocto:
		machine: 'kiwi-xavier'
		image: 'balena-image'
		fstype: 'balenaos-img'
		version: 'yocto-honister'
		deployArtifact: 'balena-image-kiwi-xavier.balenaos-img'
		compressed: true

	options: [ networkOptions.group ]

	configuration:
		config:
			partition:
				primary: 37
			path: '/config.json'

	initialization: commonImg.initialization