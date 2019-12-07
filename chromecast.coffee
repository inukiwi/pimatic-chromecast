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

		class Chromecast extends env.devices.AVPlayer

			_client = null
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
										app.on('status', (status) ->
											_device.updatePlayerState(status);
										);
									) 
						);
					);
				);

			updateVolume: (status) ->
				volume = status?.volume?.level
				if volume
					_device._setVolume(Math.round(volume * 100))

			updatePlayerState: (status) ->
				playerstate = status?.playerState?.toLowerCase()
				if playerstate
					_device._setState(playerstate)
				artist = status?.media?.metadata?.artist
				if artist
					_device._setCurrentArtist(artist)
				title = status?.media?.metadata?.title
				if title
					_device._setCurrentTitle(title)

			checkIfIdle: (status) ->
				idlescreen = status?.applications?[0].isIdleScreen
				if idlescreen
					_device._setState('stopped')
					_device._setCurrentArtist()
					_device._setCurrentTitle()

			destroy: () ->
				super()

	myPlugin = new ChromecastPlugin
	return myPlugin
