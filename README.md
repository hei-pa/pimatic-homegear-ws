Pimatic Homegear WebSocket Plugin
=================================

Plugin to interface with homegear (https://www.homegear.eu) to control Homematic Switches.

Configuration
-------------
You can load the plugin by editing your `config.json` to include (host = Homegear IP port=Homegear Port (default:2001)).

````json
{
   "plugin": "homegear-ws",
   "host": "127.0.0.1",
   "port": 2001
}
````

Use the debug output in pimatic to find out the peerId and channel of the devices.

Switches can be defined by adding them to the `devices` section in the config file.
Set the `class` attribute to `HomematicSwitch` or `HomematicPowerSwitch`. For example:

```json
{
  "id": "switch-1",
  "class": "HomematicSwitch",
  "name": "TV Switch",
  "peerId": 1
}
```
