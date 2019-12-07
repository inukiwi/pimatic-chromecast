# #my-plugin configuration options
# Declare your config option for your plugin here. 
module.exports = {
  title: "Chromecast plugin options"
  type: "object"
  properties:
    debug:
      description: "Enable debugging output"
      type: "boolean"
      default: false
}