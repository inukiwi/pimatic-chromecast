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

			actions = require("./actions") env
			@framework.ruleManager.addActionProvider(new actions.ChromecastCastActionProvider(@framework))

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
			_unreachable = false

			actions:
				play:
					description: "starts playing"
				pause:
					description: "pauses playing"
				stop:
					description: "stops playing"
				next:
					description: "play next song"
				previous:
					description: "play previous song"
				setVolume:
					description: "Change volume of player"
				castMedia:
					description: "Cast remote media to device"

			constructor: (@config, lastState) ->
				@name = @config.name
				@id = @config.id 
				@_volume = lastState?.volume?.value or 0
				@_state = lastState?.state?.value or off
				super()

				@init()

			init: () ->
				self = this
				@_client = new Client()
				@_client.on('error', (err) ->
					if !_unreachable
						env.logger.debug('%s: %s', self.name, err.message);
						self._unreachable = true;
						if err.message == 'Device timeout'
							env.logger.error('%s: Lost connection to device', self.name);
					self._client.close();
					setTimeout( ( => self.init() ), 5000)
				);
				@_client.connect(@config.ip, ->
					self._unreachable = false

					self._client.getStatus((err, status) ->
						self.onStatus(status)
						env.logger.info('Connected to %s', self.name);
					)

					self._client.on('status', (status) ->
						self.onStatus(status)
					);
				);

			onStatus: (status) ->
				self = this
				@updateVolume(status);
				@checkIfIdle(status);
				@_client.getSessions((err,sessions) ->
					if (sessions.length > 0)
						session = sessions[0];
						if session.transportId
							self._client.join(session, DefaultMediaReceiver, (err,app) ->
								self._player = app
								self._player.on('status', (status) ->
									self.updatePlayerState(status);
								);
							) 
				);

			play: () ->
				@_player?.play()

			pause: () ->
				@_player?.pause()

			next: () ->
				@_player?.media?.sessionRequest({ type: 'QUEUE_UPDATE', jump: 1 })

			previous: () ->
				@_player?.media?.sessionRequest({ type: 'QUEUE_UPDATE', jump: -1 })

			stop: () ->
				if @_player.connection
					@_client.stop(@._player, (err,response) ->
					)

			setVolume: (volume) ->
				options =
					level: volume / 100
				return Promise.resolve(@_client.setVolume(options, (err,response) ->))

			castMedia: (url) ->
				url = url[0].slice(1, -1);
				media =
					contentId: url
					streamType: 'BUFFERED'
					metadata: 
						type: 0
						metadataType: 0
						title: 'Pimatic'

				return @startStream(media)

			startStream: (media) ->
				return Promise.resolve(@_client.launch(DefaultMediaReceiver, (err,player) ->
					player.load(media, { autoplay: true}, (err,status) ->)
				))

			updateVolume: (status) ->
				volume = status?.volume?.level
				if volume
					@_setVolume(Math.round(volume * 100))

			updatePlayerState: (status) ->
				playerstate = status?.playerState
				if playerstate == 'PLAYING'
					@_setState('play')
				if playerstate == 'PAUSED'
					@_setState('pause')
				artist = status?.media?.metadata?.artist
				if artist
					@_setCurrentArtist(artist)
				title = status?.media?.metadata?.title
				if title
					@_setCurrentTitle(title)

			checkIfIdle: (status) ->
				idlescreen = status?.applications?[0].isIdleScreen
				if idlescreen
					@_setState('stop')
					@_setCurrentArtist('')
					@_setCurrentTitle('')

			destroy: () ->
				super()

	myPlugin = new ChromecastPlugin
	return myPlugin
