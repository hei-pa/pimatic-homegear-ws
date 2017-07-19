module.exports = {
  title: "homematic device config schemas"
  HomematicPowerSwitch: {
    title: "HomematicPowerSwitch config options"
    type: "object"
    properties:
      peerId:
        description: "The Device PeerID"
        type: "number"
        default: 1
  }
  HomematicSwitch: {
    title: "HomematicSwitch config options"
    type: "object"
    properties:
      peerId:
        description: "The Device PeerID"
        type: "number"
        default: 1
  }
}
