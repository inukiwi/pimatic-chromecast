module.exports = (env) ->

  Promise = env.require 'bluebird'
  _ = require('lodash')

  M = env.matcher
  assert = env.require 'cassert'

  class ChromecastCastActionProvider extends env.actions.ActionProvider
  
    constructor: (@framework) -> 
    # ### executeAction()
    ###
    This function handles action in the form of `execute "some string"`
    ###
    parseAction: (input, context) =>

      chromecasts = _(@framework.deviceManager.devices).values().filter( 
        (device) => device.hasAction("castMedia") 
      ).value()

      if chromecasts.length is 0 then return

      device = null
      valueTokens = null
      match = null
      mediaUrl = null

      setMediaUrl = (m, tokens) => mediaUrl = tokens
      onDeviceMatch = ( (m, d) -> device = d; match = m.getFullMatch() )

      m = M(input, context)
        .match("cast ")
        .matchStringWithVars(setMediaUrl)
        .match(" on ")
        .matchDevice(chromecasts, onDeviceMatch)

      if match?
        assert device?
        assert typeof match is "string"
        return {
          token: match
          nextInput: input.substring(match.length)
          actionHandler: new ChromecastCastActionHandler(device, mediaUrl)
        }
      else
        return null
        
  class ChromecastCastActionHandler extends env.actions.ActionHandler
    constructor: (@device, @url) -> #nop

    setup: ->
      @dependOnDevice(@device)
      super()

    executeAction: (simulate) => 
      return (
        if simulate
          Promise.resolve("would cast " + @url + " to " + @device.name)
        else
          @device.castMedia(@url).then( => "cast " + @url + " to " + @device.name)
      )

  return exports = {
    ChromecastCastActionProvider
  }