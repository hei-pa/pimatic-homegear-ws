module.exports = (env) ->

  deviceConfigDef = require("./device-config-schema");

  Homegear = require('./homegear')(env);
  Rx = require('rxjs');

  class Homematic extends env.plugins.Plugin

    init: (app, @framework, @config) =>

      Homegear.connect(@config.host, @config.port, @config.username, @config.password);

      @framework.deviceManager.registerDeviceClass("HomematicSwitch", {
        configDef: deviceConfigDef.HomematicSwitch,
        createCallback: (config, lastState) => new HomematicSwitch(config, lastState)
      });

      @framework.deviceManager.registerDeviceClass("HomematicPowerSwitch", {
        configDef: deviceConfigDef.HomematicPowerSwitch,
        createCallback: (config, lastState) => new HomematicPowerSwitch(config, lastState)
      });

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

      env.logger.debug("#{@name} [#{@id}] LastState: ", !!@lastState?.state?.value);
      @_state = !!@lastState?.state?.value;

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

      env.logger.debug("#{@name} [#{@id}] LastState: ", !!@lastState?.state?.value);
      @_state = !!@lastState?.state?.value;

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
