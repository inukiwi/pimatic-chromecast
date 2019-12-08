module.exports = (env) ->

	# Require the	bluebird promise library
	Promise = env.require 'bluebird'

	# Require the [cassert library](https://github.com/rhoot/cassert).
	assert = env.require 'cassert'

	Client = require('castv2-client').Client;
	DefaultMediaReceiver = require('castv2-client').DefaultMediaReceiver;
	mdns = require('mdns');

	class ChromecastPlugin extends env.plugins.Plugin

		init: (app, @framework, @config) =>

			deviceConfigDef = require("./device-config-schema")

			@framework.deviceManager.registerDeviceClass("Chromecast", {
				configDef: deviceConfigDef.Chromecast,
				createCallback: (config) => new Chromecast(config)
			})

			@framework.deviceManager.on "discover", @onDiscover

		onDiscover: (eventData) =>
			_deviceManager = @framework.deviceManager
			_deviceManager.discoverMessage( "pimatic-chromecast", "Searching for Chromecast devices on network")
			sequence = [
				mdns.rst.DNSServiceResolve()
				if 'DNSServiceGetAddrInfo' of mdns.dns_sd then mdns.rst.DNSServiceGetAddrInfo() else mdns.rst.getaddrinfo(families: [ 4 ])
				mdns.rst.makeAddressesUnique()
			]
			browser = mdns.createBrowser(mdns.tcp('googlecast'), {resolverSequence: sequence})

			_deviceManager = @framework.deviceManager

			browser.on('serviceUp', (service) ->
				name = service.txtRecord.fn
				ip = service.addresses[0]
				isnew = not _deviceManager.devicesConfig.some (deviceconf, iterator) =>
					deviceconf.ip is ip
				if isnew
					config =
						class: "Chromecast"
						name: name
						ip: ip
					_deviceManager.discoveredDevice( "pimatic-chromecast", config.name, config)
			);

			browser.start();
			setTimeout( ( => browser.stop() ), 20000)

		class Chromecast extends env.devices.AVPlayer

			_client = null
			_player = null
			_device = null
			_unreachable = false

			constructor: (@config, lastState) ->
				@name = @config.name
				@id = @config.id 
				@_volume = lastState?.volume?.value or 0
				@_state = lastState?.state?.value or off
				super()

				@init()

			init: () ->
				_device = this
				_client = new Client()
				_client.on('error', (err) ->
					if !_unreachable
						env.logger.error('Error: %s', err.message);
						_unreachable = true;
					_client.close();
					setTimeout( ( => _device.init() ), 5000)
				);
				_client.connect(@config.ip, ->
					_unreachable = false
					_client.on('status', (status) ->
						_device.updateVolume(status);
						_device.checkIfIdle(status);
						_client.getSessions((err,sessions) ->
							if (sessions.length > 0)
								session = sessions[0];
								if session.transportId
									_client.join(session, DefaultMediaReceiver, (err,app) ->
										_player = app
										_player.on('status', (status) ->
											_device.updatePlayerState(status);
										);
									) 
						);
					);
				);

			play: () ->
				_player?.play()

			pause: () ->
				_player?.pause()

			next: () ->
				_player?.media?.sessionRequest({ type: 'QUEUE_UPDATE', jump: 1 })

			previous: () ->
				_player?.media?.sessionRequest({ type: 'QUEUE_UPDATE', jump: -1 })

			stop: () ->
				if _player.connection
					_client.stop(_player, (err,response) ->
					)

			updateVolume: (status) ->
				volume = status?.volume?.level
				if volume
					_device._setVolume(Math.round(volume * 100))

			updatePlayerState: (status) ->
				playerstate = status?.playerState
				if playerstate == 'PLAYING'
					_device._setState('play')
				if playerstate == 'PAUSED'
					_device._setState('pause')
				artist = status?.media?.metadata?.artist
				if artist
					_device._setCurrentArtist(artist)
				title = status?.media?.metadata?.title
				if title
					_device._setCurrentTitle(title)

			checkIfIdle: (status) ->
				idlescreen = status?.applications?[0].isIdleScreen
				if idlescreen
					_device._setState('stop')
					_device._setCurrentArtist()
					_device._setCurrentTitle()

			destroy: () ->
				super()

	myPlugin = new ChromecastPlugin
	return myPlugin
