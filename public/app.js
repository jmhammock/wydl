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

  // Buy Me a Coffee widget loader.
  //
  // Elm renders an empty slot (`[data-bmc-slot]`) plus a plain fallback
  // link on the setup and results screens only. The official BMC script
  // only processes script tags present at its own load time, and Elm
  // re-creates the footer as screens change, so a fresh copy of the
  // widget script is injected each time a slot appears. The fallback
  // link stays visible offline or when the CDN is blocked, and hides
  // once the widget renders.
  function mountBmc(slot) {
    if (slot.querySelector('script[data-name="bmc-button"]') || slot.getAttribute('data-bmc-error')) {
      return;
    }
    var fallback = slot.querySelector('.coffee-btn');
    var s = document.createElement('script');
    s.type = 'text/javascript';
    s.src = 'https://cdnjs.buymeacoffee.com/1.0.0/button.prod.min.js';
    s.setAttribute('data-name', 'bmc-button');
    s.setAttribute('data-slug', slot.getAttribute('data-bmc-slot') || 'jhammock');
    s.setAttribute('data-color', '#FFDD00');
    s.setAttribute('data-emoji', '');
    s.setAttribute('data-font', 'Cookie');
    s.setAttribute('data-text', 'Buy me a coffee');
    s.setAttribute('data-outline-color', '#000000');
    s.setAttribute('data-font-color', '#000000');
    s.setAttribute('data-coffee-color', '#ffffff');
    s.onload = function () {
      if (fallback) {
        fallback.style.display = 'none';
      }
    };
    s.onerror = function () {
      // Mark the slot so the observer does not retry in a loop; a fresh
      // slot (new screen) will try again. The fallback link stays visible.
      slot.setAttribute('data-bmc-error', '1');
      s.remove();
    };
    slot.appendChild(s);
  }

  function scanBmc() {
    var slots = document.querySelectorAll('[data-bmc-slot]');
    for (var i = 0; i < slots.length; i++) {
      mountBmc(slots[i]);
    }
  }

  scanBmc();
  if ('MutationObserver' in window) {
    var root = document.getElementById('root');
    if (root) {
      new MutationObserver(scanBmc).observe(root, { childList: true, subtree: true });
    }
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
