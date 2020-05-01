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
    hostname:
      description: "Optional custom hostname on which Pimatic is reachable by your Chromecast"
      type: "string"
      default: ""
    port:
      description: "Custom port on which Pimatic is reachable by your Chromecast. Only used when using custom hostname"
      type: "string"
      default: ""
}