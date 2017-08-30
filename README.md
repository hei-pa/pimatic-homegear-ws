Pimatic Homegear WebSocket Plugin
=================================

Plugin to interface with homegear (https://www.homegear.eu) to control Homematic Switches/Thermostates.

Configuration
-------------
You can load the plugin by editing your `config.json` to include (host = Homegear IP port=Homegear Port (default:2001)).

````javascript
{
   "plugin": "homegear-ws",
   "username": "your-username", // (blank string if auth none)
   "password": "your-password", // (blank string if auth none)
   "host": "127.0.0.1",
   "port": 2001
}
````

Use the debug output in pimatic to find out the peerId and channel of the devices.
Or use `homegear -r` to bring up the homegear console, select the bidcosfamily `families select 0`
and show up your peers with `peers list`.

Switches can be defined by adding them to the `devices` section in the config file.
Set the `class` attribute to `HomematicSwitch` or `HomematicPowerSwitch`. For example:

```javascript
{
  "id": "switch-1",
  "class": "HomematicSwitch",
  "name": "TV Switch",
  "peerId": 1
}
```
```javascript
{
  "id": "power-switch-1",
  "class": "HomematicPowerSwitch",
  "name": "Light Power Switch",
  "peerId": 2
}
```

Thermostates also can be defined by adding them to the `devices` section in the config file.
Set the `class` attribute to `HomematicThermostate`. For example:

```javascript
{
  "id": "thermostate-1",
  "class": "HomematicThermostate",
  "name": "Thermostate kitchen",
  "peerId": 3
}
```
