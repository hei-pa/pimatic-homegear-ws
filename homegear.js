
const Rx = require('rxjs');
const WebSocket = require('./websocket');
const random = require('random-number').generator({
  min:  1000000,
  max:  9999999,
  integer: true
});

serverSocket = clientSocket = null;

module.exports = (env) => {

  requestSubject = new Rx.ReplaySubject(100).timestamp().scan((acc, curr) => {

    let delay = 0;
    if (acc !== null) {
      const timeDelta = curr.timestamp - acc.timestamp;
      delay = timeDelta > 100 ? 0 : (100 - timeDelta);
    }

    env.logger.debug(`Delay message for ${delay}`);

    return {
      timestamp: curr.timestamp,
      value: curr.value,
      delay: delay
    }

  }, null).mergeMap(i => Rx.Observable.of(i.value).delay(i.delay), undefined, 1);

  let serverConnected = clientConnected = false;

  const homegear = {

    connect: (config) => {

      env.logger.debug(`Connecting to ${config.host}:${config.port}`);

      homegear.connectServer(config);
      homegear.connectClient(config);

      let requestSubscription;
      Rx.Observable.zip(serverSocket.connectionStatus, clientSocket.connectionStatus).subscribe((states) => {

        if(states.every((state) => state === (config.username ? "AUTHENTICATED" : "CONNECTED"))) {

          env.logger.debug('Connect request sending.');

          // connect the sending
          requestSubscription = requestSubject.subscribe((request) => {
            env.logger.debug(`Sending Request: ${JSON.stringify(request)}`);
            clientSocket.send(request);
          });

        } else {
          if(requestSubscription) {
            env.logger.debug('Disconnect request sending.');
            requestSubscription.unsubscribe();
          }
        }

      });

    },

    connectServer: (config) => {

      serverSocket = WebSocket(env, config, 'client');
      serverSocket.connectionStatus.subscribe((state) => {

        switch(state) {
          case "CONNECTED":

            env.logger.debug(`Connected to homegear system [${homegearId}]. Protocol 'client'`);

            if(config.username) {
              serverSocket.send({
                user: config.username,
                password: config.password
              });
            }

            break;

          case "DISCONNECTED":
            env.logger.error(`Connection to homegear system CLOSED. ${serverSocket.url}`);
            break;

        }

      });

      // acknowledge all incomming messages
      serverSocket.catch(val => Rx.Observable.of({error: val})).subscribe((message) => {

        if("error" in message) {
          env.logger.error('MESSAGE (Server): ', message.error);
          return;
        }

        //env.logger.debug(`MESSAGE (Client): ${JSON.stringify(message)}`);

        if(!("auth" in message)) {
          serverSocket.send("{}");
        } else if(message.auth == "success") {
          env.logger.debug('Server authenticated.');
          serverSocket.connectionObserver.next("AUTHENTICATED");
        } else {
          env.logger.error('Server Authentication failed.');
        }

      }, (err) => {
        env.logger.error("Server Socket ERROR");
      }, () => {
        env.logger.debug("Server Socket COMPLETE");
      });

    },

    connectClient: (config) => {

      clientSocket = WebSocket(env, config, 'server');
      clientSocket.connectionStatus.subscribe((state) => {

        switch(state) {
          case "CONNECTED":

            env.logger.debug(`Connected to homegear system [${homegearId}]. Protocol 'server'`);

            if(config.username) {
              clientSocket.send({
                user: config.username,
                password: config.password
              });
            }

            break;

          case "DISCONNECTED":
            env.logger.error(`Connection to homegear system CLOSED. ${clientSocket.url}`);
            break;

        }

      });

      clientSocket.catch(val => Rx.Observable.of({error: val})).subscribe((message) => {

        if("error" in message) {
          env.logger.error('MESSAGE (Server): ', message.error);
          return;
        }

        //env.logger.debug(`MESSAGE (Server): ${JSON.stringify(message)}`);

        if("auth" in message) {
          if(message.auth == 'success') {
            env.logger.debug("Client authenticated.");
            clientSocket.connectionObserver.next("AUTHENTICATED");
          } else {
            env.logger.error('Client Authentication failed.');
          }
        }

      }, (err) => {
        env.logger.error("Client Socket ERROR");
      }, () => {
        env.logger.debug("Client Socket COMPLETE");
      });

    },

    sendRequest: (request) => {

      request.id = request.id || random();
      request.jsonrpc = "2.0";

      requestSubject.next(request);

      return clientSocket.catch(val => {
        env.logger.error(val.toString());
        return Rx.Observable.empty()
      }).filter((response) => {
        return response.id == request.id;
      }).first();

    },

    subscribePeer: (peerId) => {

      return homegear.sendRequest({
        method: "subscribePeers",
        params: [homegearId, [peerId]]
      });

    },

    onNotification: (peerId) => {

      return serverSocket.catch(val => {
        env.logger.error(val.toString());
        return Rx.Observable.empty()
      }).filter((message) => {
        return message.method == "event" && message.params && message.params[1] == peerId;
      }).map((notification) => {
        return notification.params;
      });

    }

  };

  return homegear;

}
