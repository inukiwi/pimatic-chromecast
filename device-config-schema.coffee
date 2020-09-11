module.exports ={
  title: "pimatic-chromecast device config schemas"
  Chromecast: {
    title: "Chromecast config options"
    type: "object"
    properties:
      ip:
        description: "The ip of the Chromecast device"
        type: "string"
      port:
        description: "The port of the Chromecast device"
        type: "number"
        default: 8009
  }
}