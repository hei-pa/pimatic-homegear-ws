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
  HomematicThermostat: {
    title: "HomematicThermostat config options"
    type: "object"
    properties:
      peerId:
        description: "The Device PeerID"
        type: "number"
        default: 1
      guiShowModeControl:
        description: "Show the mode buttons in the gui"
        type: "boolean"
        default: true
      guiShowPresetControl:
        description: "Show the preset temperatures in the gui"
        type: "boolean"
        default: false
      guiShowTemperatureInput:
        description: "Show the temperature input spinbox in the gui"
        type: "boolean"
        default: true
  }
}
