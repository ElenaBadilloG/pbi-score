/* Offline support for the PBI score calculator.
 *
 * The page itself is fetched network-first (with a short timeout for flaky
 * hospital Wi-Fi) so corrections to index.html reach users on their next
 * visit. Icons and the manifest are cache-first.
 *
 * Bump CACHE when you change icons, fonts or the manifest, or add files to SHELL.
 * Edits to index.html alone don't need a bump.
 */
"use strict";

var CACHE = "pbi-score-v2";
var NETWORK_TIMEOUT_MS = 3000;
var SHELL = [
  "./",
  "./index.html",
  "./manifest.webmanifest",
  "./fonts/EBGaramond.woff2",
  "./fonts/EBGaramond-Italic.woff2",
  "./icons/favicon.svg",
  "./icons/icon-192.png",
  "./icons/icon-512.png",
  "./icons/icon-maskable-512.png",
  "./icons/apple-touch-icon.png"
];

self.addEventListener("install", function (event) {
  event.waitUntil(
    caches.open(CACHE)
      .then(function (cache) { return cache.addAll(SHELL); })
      .then(function () { return self.skipWaiting(); })
  );
});

self.addEventListener("activate", function (event) {
  event.waitUntil(
    caches.keys()
      .then(function (keys) {
        return Promise.all(keys.filter(function (k) { return k !== CACHE; })
                               .map(function (k) { return caches.delete(k); }));
      })
      .then(function () { return self.clients.claim(); })
  );
});

function networkFirst(request) {
  return caches.open(CACHE).then(function (cache) {
    var fromNetwork = fetch(request).then(function (res) {
      if (res.ok) cache.put("./index.html", res.clone());
      return res;
    });

    var timeout = new Promise(function (resolve) {
      setTimeout(function () { resolve(null); }, NETWORK_TIMEOUT_MS);
    });

    return Promise.race([fromNetwork.catch(function () { return null; }), timeout])
      .then(function (res) {
        if (res) return res;
        return cache.match("./index.html").then(function (cached) {
          // Nothing cached yet: wait on the network after all.
          return cached || fromNetwork;
        });
      });
  });
}

function cacheFirst(request) {
  return caches.match(request).then(function (cached) {
    if (cached) return cached;
    return fetch(request).then(function (res) {
      if (res.ok) {
        var copy = res.clone();
        caches.open(CACHE).then(function (cache) { cache.put(request, copy); });
      }
      return res;
    });
  });
}

self.addEventListener("fetch", function (event) {
  var req = event.request;
  if (req.method !== "GET") return;
  if (new URL(req.url).origin !== self.location.origin) return; // e.g. the DOI link

  event.respondWith(req.mode === "navigate" ? networkFirst(req) : cacheFirst(req));
});
