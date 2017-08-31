
const WebSocket = require('ws');
const UUID = require('uuid');
const Rx = require('rxjs');

homegearId = `Pimatic-${UUID.v4()}`;

module.exports = (env, config, protocol, resultSelector, serializer) => {

  let socket, reconnectionObservable;
  const RxWebsocketSubject = new Rx.Subject();

  /// by default, when a message is received from the server, we are trying to decode it as JSON
  /// we can override it in the constructor
  const defaultResultSelector = (e) => {
    return JSON.parse(e.data);
  }

  /// when sending a message, we encode it to JSON
  /// we can override it in the constructor
  const defaultSerializer = (data) => {
    return JSON.stringify(data);
  }

  RxWebsocketSubject.url = `ws://${config.host}:${config.port}/${homegearId}`;
  RxWebsocketSubject.protocol = protocol || undefined;
  RxWebsocketSubject.reconnectInterval = config.reconnectInterval || 5000;  /// pause between connections
  RxWebsocketSubject.reconnectAttempts = config.reconnectAttempts || 10;  /// number of connection attempts
  RxWebsocketSubject.resultSelector = resultSelector ? resultSelector : defaultResultSelector;
  RxWebsocketSubject.serializer = serializer ? serializer : defaultSerializer;

  RxWebsocketSubject.connectionStatus = new Rx.Observable((observer) => {
    RxWebsocketSubject.connectionObserver = observer;
  }).share().distinctUntilChanged();

  const wsSubjectConfig = {
    url: RxWebsocketSubject.url,
    protocol: RxWebsocketSubject.protocol,
    WebSocketCtor: WebSocket,
    closeObserver: {
      next: (e) => {
        socket = null;
        RxWebsocketSubject.connectionObserver.next("DISCONNECTED");
      }
    },
    openObserver: {
      next: (e) => {
        RxWebsocketSubject.connectionObserver.next("CONNECTED");
      }
    }
  };

  RxWebsocketSubject.connect = () => {

    socket = Rx.Observable.webSocket(wsSubjectConfig);
    socket.subscribe((m) => {
      RxWebsocketSubject.next(m); /// when receiving a message, we just send it to our Subject
    }, (err) => {
      if (!socket) {
        /// in case of an error with a loss of connection, we restore it
        if (!reconnectionObservable) {
          RxWebsocketSubject.reconnect();
        }
      }
    });

  };

  RxWebsocketSubject.reconnect = () => {

    env.logger.debug(`Scheduling reconnect in ${RxWebsocketSubject.reconnectInterval} ms`);
    reconnectionObservable = Rx.Observable.interval(RxWebsocketSubject.reconnectInterval).takeWhile((v, index) => {
      return index < RxWebsocketSubject.reconnectAttempts && !socket
    });

    reconnectionObservable.subscribe((index) => {
      env.logger.debug(`Performing reconnect [${RxWebsocketSubject.reconnectAttempts - index} left] to ${RxWebsocketSubject.url} [${RxWebsocketSubject.protocol}]`);
      RxWebsocketSubject.connect();
    }, null, () => {
      // if the reconnection attempts are failed, then we call complete of our Subject and status
      reconnectionObservable = null;
      if (!socket) {
        RxWebsocketSubject.complete();
        RxWebsocketSubject.connectionObserver.complete();
        env.logger.error('Failed to connect to Homegear');
      }
    });

  };

  // sending the message
  RxWebsocketSubject.send = (data) => {
    socket.next(RxWebsocketSubject.serializer(data));
  }

  // we connect
  RxWebsocketSubject.connect();

  // we follow the connection status and run the reconnect while losing the connection
  RxWebsocketSubject.connectionStatus.subscribe((state) => {
    if (!reconnectionObservable && state === "DISCONNECTED") {
      RxWebsocketSubject.reconnect();
    }
  });

  return RxWebsocketSubject;

}
