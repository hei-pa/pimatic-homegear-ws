module.exports = (env) ->

  DeviceConfigDef = require("./device-config-schema");
  Homegear = require('./homegear')(env);
  Rx = require('rxjs');

  class Homematic extends env.plugins.Plugin

    init: (app, @framework, @config) =>

      Homegear.connect(@config.host, @config.port, @config.username, @config.password);

      @framework.deviceManager.registerDeviceClass("HomematicSwitch", {
        configDef: DeviceConfigDef.HomematicSwitch,
        createCallback: (config, lastState) => new HomematicSwitch(config, lastState)
      });

      @framework.deviceManager.registerDeviceClass("HomematicPowerSwitch", {
        configDef: DeviceConfigDef.HomematicPowerSwitch,
        createCallback: (config, lastState) => new HomematicPowerSwitch(config, lastState)
      });

      @framework.deviceManager.registerDeviceClass("HomematicThermostat", {
        configDef: DeviceConfigDef.HomematicThermostat,
        createCallback: (config, lastState) => new HomematicThermostat(config, lastState)
      });

  class HomematicThermostat extends env.devices.HeatingThermostat

    attributes:
      temperatureSetpoint:
        label: "Temperature Setpoint"
        description: "The temp that should be set"
        type: "number"
        discrete: true
        unit: "°C"
      temperature:
        label: "Actual Temperature"
        description: "The actual temperature"
        type: "number"
        discrete: true
        unit: "°C"
      valve:
        description: "Position of the valve"
        type: "number"
        discrete: true
        unit: "%"
      mode:
        description: "The current mode"
        type: "string"
        enum: ["auto", "manu", "boost"]
      battery:
        description: "Battery Voltage"
        type: "number"
        discrete: true
        unit: "V"
      synced:
        description: "Pimatic and thermostat in sync"
        type: "boolean"

    actions:
      changeModeTo:
        params:
          mode:
            type: "string"
      changeTemperatureTo:
        params:
          temperatureSetpoint:
            type: "number"

    template: "thermostat"

    constructor: (@config, @lastState) ->
      @name = @config.name;
      @id = @config.id;
      super();

      Homegear.subscribePeer(@config.peerId);
      Homegear.onNotification(@config.peerId).subscribe((notification) =>
        env.logger.debug("Received Notification for #{@config.peerId}: #{JSON.stringify(notification)}");
        switch notification[3]
          when "CONTROL_MODE" then @emit("mode", @_mode = @convertModeState(notification[4]));
          when "BATTERY_STATE" then @emit("battery", @_battery = notification[4]);
          when "SET_TEMPERATURE" then @emit("temperatureSetpoint", @_temperatureSetpoint = notification[4]);
          when "ACTUAL_TEMPERATURE" then @emit("temperature", @_temperature = notification[4]);
          when "VALVE_STATE" then @emit("valve", @_valve = notification[4]);
      );

      # set last values or request current
      @_mode = @lastState?.mode?.value || @getMode();
      @_battery = @lastState?.battery?.value || @getBattery();
      @_temperatureSetpoint = @lastState?.temperatureSetpoint?.value || @getTemperatureSetpoint();
      @_temperature = @lastState?.temperature?.value || @getTemperature();
      @_valve = @lastState?.valve?.value || @getValve();
      @_synced = true;

    convertModeState: (state) =>
      switch state
        when 0 then return "auto"
        when 1 then return "manu"
        when 2 then return "party"
        when 3 then return "boost"

    convertModeStateReverse: (state) =>
      switch state
        when "auto" then return 0
        when "manu" then return 1
        when "party" then return 2
        when "boost" then return 3

    getMode: () =>
      if @_mode? then return Rx.Observable.of(@_mode).toPromise();
      return Homegear.sendRequest({
        method: 'getValue',
        params: [@config.peerId, 4, "CONTROL_MODE"]
      }).map((response) =>
        return @_mode = @convertModeState(response.result);
      ).toPromise();

    getTemperatureSetpoint: () =>
      if @_temperatureSetpoint? then return Rx.Observable.of(@_temperatureSetpoint).toPromise();
      return Homegear.sendRequest({
        method: 'getValue',
        params: [@config.peerId, 4, "SET_TEMPERATURE"]
      }).map((response) =>
        return @_temperatureSetpoint = response.result;
      ).toPromise();

    getTemperature: () =>
      if @_temperature? then return Rx.Observable.of(@_temperature).toPromise();
      return Homegear.sendRequest({
        method: 'getValue',
        params: [@config.peerId, 4, "ACTUAL_TEMPERATURE"]
      }).map((response) =>
        return @_temperature = response.result;
      ).toPromise();

    getValve: () =>
      if @_valve? then return Rx.Observable.of(@_valve).toPromise();
      return Homegear.sendRequest({
        method: 'getValue',
        params: [@config.peerId, 4, "VALVE_STATE"]
      }).map((response) =>
        return @_valve = response.result;
      ).toPromise();

    getBattery: =>
      if @_battery? then return Rx.Observable.of(@_battery).toPromise();
      return Homegear.sendRequest({
        method: 'getValue',
        params: [@config.peerId, 4, "BATTERY_STATE"]
      }).map((response) =>
        return @_battery = response.result;
      ).toPromise();

    changeModeTo: (mode) ->
      if @_mode is mode then return Rx.Observable.of(@_mode).toPromise();
      @_synced = false;

      # set default to auto
      params = [@config.peerId, 4, "AUTO_MODE", true];

      switch mode
        when "auto" then params = [@config.peerId, 4, "AUTO_MODE", true]
        when "manu" then params = [@config.peerId, 4, "MANU_MODE", @_temperatureSetpoint]
        when "party" then params = [@config.peerId, 4, "PARTY_MODE_SUBMIT", true]
        when "boost" then params = [@config.peerId, 4, "BOOST_MODE", true]

      return Homegear.sendRequest({
        method: 'setValue',
        params: params
      }).map((response) =>
        @_synced = true;
        @emit("mode", @_mode = mode);
        return @_mode;
      ).toPromise();

    changeTemperatureTo: (temperatureSetpoint) ->
      if @_temperatureSetpoint is temperatureSetpoint then return Rx.Observable.of(@_temperatureSetpoint).toPromise();
      @_synced = false;
      return Homegear.sendRequest({
        method: 'setValue',
        params: [@config.peerId, 4, "SET_TEMPERATURE", temperatureSetpoint]
      }).map((response) =>
        @_synced = true;
        @emit("temperatureSetpoint", @_temperatureSetpoint = temperatureSetpoint);
        return @_temperatureSetpoint;
      ).toPromise();

    destroy: () =>
      env.logger.debug('Destroy HomematicThermostat');
      super();

  class HomematicSwitch extends env.devices.PowerSwitch

    attributes:
      state:
        description: "state of the switch"
        type: "boolean"
        labels: ['on', 'off']

    constructor: (@config, @lastState) ->
      @name = @config.name;
      @id = @config.id;
      super();

      # set last values or request current
      @_state = !!@lastState?.state?.value || @getState();

      Homegear.subscribePeer(@config.peerId);
      Homegear.onNotification(@config.peerId).subscribe((notification) =>
        env.logger.debug("Received Notification for #{@config.peerId}: #{JSON.stringify(notification)}");
        switch notification[3]
          when "STATE" then @emit("state", @_state = notification[4]);
      );

    getState: =>
      if @_state? then return Rx.Observable.of(@_state).toPromise();
      return Homegear.sendRequest({
        method: 'getValue',
        params: [@config.peerId, 1, "STATE"]
      }).map((response) =>
        return @_state = response.result;
      ).toPromise();

    changeStateTo: (state) =>
      if @_state is state then return Rx.Observable.of(@_state).toPromise();
      return Homegear.sendRequest({
        method: 'setValue',
        params: [@config.peerId, 1, "STATE", state]
      }).map((response) =>
        @emit("state", @_state = state);
        return @_state;
      ).toPromise();

    destroy: () =>
      env.logger.debug('Destroy HomematicSwitch');
      super();

  class HomematicPowerSwitch extends env.devices.PowerSwitch

    attributes:
      state:
        description: "state of the switch"
        type: "boolean"
        labels: ['on', 'off']
      power:
        description: "power of the switch"
        type: "number"
        unit: "W"
      current:
        description: "current of the switch"
        type: "number"
        unit: "A"
      voltage:
        description: "voltage of the switch"
        type: "number"
        unit: "V"
      frequency:
        description: "frequency of the switch"
        type: "number"
        unit: "Hz"
      energy:
        description: "energy counter of the switch"
        type: "number"
        unit: "kWh"

    constructor: (@config, @lastState) ->
      @name = @config.name;
      @id = @config.id;
      super();

      # set last values or request current
      @_state = !!@lastState?.state?.value || @getState();
      @_voltage = @lastState?.voltage?.value || @getVoltage();
      @_current = @lastState?.current?.value || @getCurrent();
      @_frequency = @lastState?.frequency?.value || @getFrequency();
      @_energy = @lastState?.energy?.value || @getEnergy();
      @_power = @lastState?.power?.value || @getPower();

      Homegear.subscribePeer(@config.peerId);
      Homegear.onNotification(@config.peerId).subscribe((notification) =>
        env.logger.debug("Received Notification for #{@config.peerId}: #{JSON.stringify(notification)}");
        switch notification[3]
          when "STATE" then @emit("state", @_state = notification[4]);
          when "VOLTAGE" then @emit("voltage", @_voltage = notification[4]);
          when "CURRENT" then @emit("current", @_current = notification[4] / 1000.0);
          when "FREQUENCY" then @emit("frequency", @_frequency = notification[4]);
          when "POWER" then @emit("power", @_power = notification[4]);
          when "ENERGY_COUNTER" then @emit("energy", @_energy = notification[4]);
      );

    getState: =>
      if @_state? then return Rx.Observable.of(@_state).toPromise();
      return Homegear.sendRequest({
        method: 'getValue',
        params: [@config.peerId, 1, "STATE"]
      }).map((response) =>
        return @_state = response.result;
      ).toPromise();

    getVoltage: =>
      if @_voltage? then return Rx.Observable.of(@_voltage).toPromise();
      return Homegear.sendRequest({
        method: 'getValue',
        params: [@config.peerId, 2, "VOLTAGE"]
      }).map((response) =>
        return @_voltage = response.result;
      ).toPromise();

    getCurrent: =>
      if @_current? then return Rx.Observable.of(@_current).toPromise();
      return Homegear.sendRequest({
        method: 'getValue',
        params: [@config.peerId, 2, "CURRENT"]
      }).map((response) =>
        return @_current = response.result;
      ).toPromise();

    getFrequency: =>
      if @_frequency? then return Rx.Observable.of(@_frequency).toPromise();
      return Homegear.sendRequest({
        method: 'getValue',
        params: [@config.peerId, 2, "FREQUENCY"]
      }).map((response) =>
        return @_frequency = response.result;
      ).toPromise();

    getPower: =>
      if @_power? then return Rx.Observable.of(@_power).toPromise();
      return Homegear.sendRequest({
        method: 'getValue',
        params: [@config.peerId, 2, "POWER"]
      }).map((response) =>
        return @_power = response.result;
      ).toPromise();

    getEnergy: =>
      if @_energy? then return Rx.Observable.of(@_energy).toPromise();
      return Homegear.sendRequest({
        method: 'getValue',
        params: [@config.peerId, 2, "ENERGY_COUNTER"]
      }).map((response) =>
        return @_energy = response.result;
      ).toPromise();

    changeStateTo: (state) =>
      if @_state is state then return Rx.Observable.of(@_state).toPromise();
      return Homegear.sendRequest({
        method: 'setValue',
        params: [@config.peerId, 1, "STATE", state]
      }).map((response) =>
        @emit("state", @_state = state);
        return @_state;
      ).toPromise();

    destroy: () =>
      env.logger.debug('Destroy HomematicPowerSwitch');
      super();

  return new Homematic;
