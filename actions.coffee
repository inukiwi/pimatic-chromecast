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
    constructor: (@device, @url) ->

    setup: ->
      @dependOnDevice(@device)
      super()

    executeAction: (simulate) => 
      return (
        if simulate
          Promise.resolve("would cast " + @url + " to " + @device.name)
        else
          @device.castMedia(url[0].slice(1, -1)).then( => "cast " + @url + " to " + @device.name)
      )

  class ChromecastTtsActionProvider extends env.actions.ActionProvider
  
    constructor: (@framework) -> 
    # ### executeAction()
    ###
    This function handles action in the form of `execute "some string"`
    ###
    parseAction: (input, context) =>

      chromecasts = _(@framework.deviceManager.devices).values().filter( 
        (device) => device.hasAction("castText") 
      ).value()

      if chromecasts.length is 0 then return

      device = null
      valueTokens = null
      match = null
      text = null
      lang = null

      setText = (m, tokens) => text = tokens
      setLang = (m, tokens) => lang = tokens
      onDeviceMatch = ( (m, d) -> device = d; match = m.getFullMatch() )

      m = M(input, context)
        .match("cast-text ")
        .matchStringWithVars(setText)
        .match(" in language ")
        .matchStringWithVars(setLang)
        .match(" on ")
        .matchDevice(chromecasts, onDeviceMatch)

      if match?
        assert device?
        assert typeof match is "string"
        return {
          token: match
          nextInput: input.substring(match.length)
          actionHandler: new ChromecastTtsActionHandler(device, text, lang)
        }
      else
        return null
        
  class ChromecastTtsActionHandler extends env.actions.ActionHandler
    constructor: (@device, @text, @lang) ->

    setup: ->
      @dependOnDevice(@device)
      super()

    executeAction: (simulate) => 
      return (
        if simulate
          Promise.resolve("would cast text \"" + @text + "\" in " + @lang + " to " + @device.name)
        else
          @device.castText(@text[0].slice(1, -1), @lang[0].slice(1, -1)).then( => "cast text " + @text + " in " + @lang + " to " + @device.name)
      )

  return exports = {
    ChromecastCastActionProvider,
    ChromecastTtsActionProvider,
  }