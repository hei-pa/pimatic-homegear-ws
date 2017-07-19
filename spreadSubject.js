
Rx = require('rxjs');

module.exports = (spread) => {

  return new Rx.Subject().timestamp().scan((acc, curr) => {

    let delay = 0;
    if (acc !== null) {
      const timeDelta = curr.timestamp - acc.timestamp;
      delay = timeDelta > spread ? 0 : (spread - timeDelta);
    }

    return {
      timestamp: curr.timestamp,
      value: curr.value,
      delay: delay
    }

  }, null).mergeMap(i => Rx.Observable.of(i.value).delay(i.delay), undefined, 1);

}
