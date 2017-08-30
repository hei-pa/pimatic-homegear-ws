
WebSocket = require('ws');
UUID = require('uuid');
Rx = require('rxjs');

random = require('random-number').generator({
  min:  1000000,
  max:  9999999,
  integer: true
});

homegearId = `Pimatic-${UUID.v4()}`;
serverSocket = clientSocket = null;

module.exports = (env) => {

  requestSubject = new Rx.ReplaySubject(20).timestamp().scan((acc, curr) => {

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

  const homegear = {

    connect: (host, port, username, password) => {

      const serverOpenObserver = {
        next: (e) => {

          env.logger.debug(`Connected to homegear system [${homegearId}]. ${e.target.protocol}`);

          if(username) {
            serverSocket.next(JSON.stringify({
              user: username,
              password: password
            }));
          }

        }
      };

      const clientOpenObserver = {
        next: (e) => {

          env.logger.debug(`Connected to homegear system [${homegearId}]. ${e.target.protocol}`);

          if(username) {
            clientSocket.next(JSON.stringify({
              user: username,
              password: password
            }));
          } else {

            // connect the sending if no username was provied (homegear.webSocketAuthType = none)
            requestSubject.subscribe((request) => {
              env.logger.debug(`Sending Request: ${JSON.stringify(request)}`);
              clientSocket.next(JSON.stringify(request));
            });

          }

        }
      };

      env.logger.debug(`Connecting to ${host}:${port}`);

      serverSocket = Rx.Observable.webSocket({
        url: `ws://${host}:${port}/${homegearId}`,
        openObserver: serverOpenObserver,
        WebSocketCtor: WebSocket,
        protocol: 'client'
      });

      // acknowledge all incomming messages
      serverSocket.subscribe((message) => {

        env.logger.debug(`MESSAGE (Client): ${JSON.stringify(message)}`);

        if(!("auth" in message)) {
          serverSocket.next("{}");
        } else if(message.auth == "success") {
          env.logger.debug('Server authenticated.');
        } else {
          env.logger.error('Server Authentication failed.');
        }

      });

      clientSocket = Rx.Observable.webSocket({
        url: `ws://${host}:${port}/${homegearId}`,
        openObserver: clientOpenObserver,
        WebSocketCtor: WebSocket,
        protocol: 'server'
      });

      clientSocket.subscribe((message) => {

        env.logger.debug(`MESSAGE (Server): ${JSON.stringify(message)}`);

        if("auth" in message) {
          if(message.auth == 'success') {
            env.logger.debug("Client authenticated.");

            // now connect the sending
            requestSubject.subscribe((request) => {
              env.logger.debug(`Sending Request: ${JSON.stringify(request)}`);
              clientSocket.next(JSON.stringify(request));
            });

          } else {
            env.logger.error('Client Authentication failed.');
          }
        }

      });

    },

    sendRequest: (request) => {

      request.id = request.id || random();
      request.jsonrpc = "2.0";

      requestSubject.next(request);

      return clientSocket.filter((response) => {
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

      return serverSocket.filter((message) => {
        return message.method == "event" && message.params && message.params[1] == peerId;
      }).map((notification) => {
        return notification.params;
      });

    }

  };

  return homegear;

}
