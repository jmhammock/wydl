// App bootstrap + share-image bridge for the Elm app.
//
// Elm owns the results data; JS only draws the PNG and invokes the
// Web Share API. Kept as a plain script (no bundler) so index.html stays
// static and the service worker can cache it like elm.js.

(function () {
  'use strict';

  var app = Elm.Main.init({ node: document.getElementById('root') });

  if ('serviceWorker' in navigator) {
    window.addEventListener('load', function () {
      navigator.serviceWorker.register('sw.js').catch(function () {});
    });
  }

  function drawShareImage(title, score, sub) {
    var size = 1080;
    var canvas = document.createElement('canvas');
    canvas.width = size;
    canvas.height = size;
    var g = canvas.getContext('2d');

    g.fillStyle = '#1d3557';
    g.fillRect(0, 0, size, size);

    g.fillStyle = '#ffffff';
    g.textAlign = 'center';
    g.textBaseline = 'middle';
    g.font = '600 72px system-ui, -apple-system, "Segoe UI", sans-serif';
    g.fillText(title, size / 2, 320);
    g.font = '700 190px system-ui, -apple-system, "Segoe UI", sans-serif';
    g.fillText(score, size / 2, 560);
    g.font = '400 64px system-ui, -apple-system, "Segoe UI", sans-serif';
    g.fillText(sub, size / 2, 750);

    return canvas;
  }

  function toBlob(canvas) {
    return new Promise(function (resolve, reject) {
      if (canvas.toBlob) {
        canvas.toBlob(function (blob) {
          if (blob) {
            resolve(blob);
          } else {
            reject(new Error('toBlob returned null'));
          }
        }, 'image/png');
      } else {
        reject(new Error('canvas.toBlob not supported'));
      }
    });
  }

  function download(blob, filename) {
    var url = URL.createObjectURL(blob);
    var a = document.createElement('a');
    a.href = url;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    a.remove();
    setTimeout(function () {
      URL.revokeObjectURL(url);
    }, 5000);
  }

  if (app.ports && app.ports.requestShare) {
    app.ports.requestShare.subscribe(function (payload) {
      var send = function (state) {
        if (app.ports.shareStatus) {
          app.ports.shareStatus.send(state);
        }
      };

      var title = payload.title || 'Driver Test';
      var score = payload.score || '';
      var sub = payload.sub || '';
      var text = title + ': ' + score + ' ' + sub;
      var canvas = drawShareImage(title, score, sub);

      toBlob(canvas).then(function (blob) {
        var file = new File([blob], 'driver-test-result.png', { type: 'image/png' });

        if (navigator.canShare && navigator.canShare({ files: [file] })) {
          return navigator.share({ files: [file], title: title, text: text }).then(
            function () {
              send('Shared!');
            },
            function (err) {
              if (err && err.name !== 'AbortError') {
                send('Share was dismissed.');
              } else {
                send('');
              }
            }
          );
        }

        download(blob, 'driver-test-result.png');

        if (navigator.share) {
          return navigator.share({ title: title, text: text }).then(
            function () {
              send('Image downloaded – thanks for sharing!');
            },
            function () {
              send('Image downloaded – share it!');
            }
          );
        }

        send('Image downloaded – share it!');
        return undefined;
      }).catch(function () {
        send('Could not create the image.');
      });
    });
  }
})();
