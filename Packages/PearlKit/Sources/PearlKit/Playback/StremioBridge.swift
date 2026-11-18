import Foundation

/// Talking back to Stremio.
///
/// When Stremio hands a stream to an external player it can pass an `x-success`
/// URL. stremio-web reads a `position` search parameter off that URL when it
/// lands back on the detail page and stores it as the watched position
/// (see `useExternalPlayerCallback.ts` in stremio-web). So Pearl can report
/// where the user stopped, which is the one thing neither VLC nor Outplayer
/// does on iOS.
public enum StremioBridge {
    /// Builds the URL to open on exit. Returns nil when the handoff gave us no
    /// callback, which is the case for the plain dropdown handoff.
    public static func progressURL(
        callback: URL,
        position: TimeInterval,
        lastPlayedURL: URL? = nil,
        markWatched: Bool = false
    ) -> URL? {
        guard callback.scheme != nil else { return nil }
        guard var components = URLComponents(url: callback, resolvingAgainstBaseURL: false) else {
            return nil
        }
        var items = components.queryItems ?? []
        items.removeAll { $0.name == "position" || $0.name == "lastPlayedUrl" }
        let seconds = max(position, 0)
        items.append(URLQueryItem(name: "position", value: String(format: "%.3f", seconds)))
        if let lastPlayedURL {
            items.append(URLQueryItem(name: "lastPlayedUrl", value: lastPlayedURL.absoluteString))
        }
        _ = markWatched
        components.queryItems = items
        return components.url
    }

    /// The detail URL for a Stremio item, for the cases where the handoff gave
    /// us ids rather than a full callback URL.
    public static func detailURL(
        type: String,
        id: String,
        videoID: String?,
        position: TimeInterval?
    ) -> URL? {
        guard !type.isEmpty, !id.isEmpty else { return nil }
        var path = "/detail/\(type)/\(id)"
        if let videoID, !videoID.isEmpty {
            path += "/\(videoID)"
        }
        // Built as text on purpose: URLComponents drops the empty host and
        // renders "stremio:/detail/...", while Stremio itself uses three
        // slashes and its own router matches on the path.
        var text = "stremio://" + path
        if let position {
            text += "?position=" + String(format: "%.3f", position)
        }
        return URL(string: text)
    }

    /// Reads the ids out of a Stremio detail URL, so a callback can be
    /// reconstructed after the fact.
    public struct DetailIDs: Equatable, Sendable {
        public var type: String
        public var id: String
        public var videoID: String?
    }

    public static func ids(fromDetailURL url: URL) -> DetailIDs? {
        let parts = url.path.split(separator: "/").map(String.init)
        guard parts.count >= 3, parts[0] == "detail" else { return nil }
        return DetailIDs(type: parts[1], id: parts[2], videoID: parts.count >= 4 ? parts[3] : nil)
    }
}

/// The Safari userscript that makes Stremio Web hand its streams to Pearl, with
/// a progress callback, without needing Stremio's own dropdown. Shown and
/// copied from the in-app setup screen.
public enum StremioUserScript {
    public static let source = """
        // ==UserScript==
        // @name         Pearl Player handoff for Stremio Web
        // @namespace    pearl.player
        // @version      1.0
        // @description  Opens Stremio Web streams in Pearl Player, and reports the position back.
        // @match        https://web.stremio.com/*
        // @match        https://web.strem.io/*
        // @match        https://stremio.com/*
        // @run-at       document-start
        // ==/UserScript==
        (function () {
          'use strict';
          var SCHEME = 'pearl://x-callback-url/play?url=';

          function detailCallback() {
            // Stremio Web keeps the route in the hash, for example
            // #/detail/movie/tt0111161/tt0111161
            var hash = (location.hash || '').replace(/^#/, '');
            if (hash.indexOf('/detail/') === 0) return 'stremio:/' + hash;
            return null;
          }

          function unwrap(href) {
            // outplayer://https://host/x.mkv   or   vlc-x-callback://x-callback-url/stream?url=...
            var m = /^(?:outplayer|vlc|vlc-x-callback):\\/\\/(.*)$/i.exec(href);
            if (!m) return null;
            var rest = m[1];
            var q = rest.indexOf('url=');
            if (q !== -1) {
              var raw = rest.slice(q + 4).split('&')[0];
              try { return decodeURIComponent(raw); } catch (e) { return raw; }
            }
            try { rest = decodeURIComponent(rest); } catch (e) {}
            while (rest.charAt(0) === '/') rest = rest.slice(1);
            if (/^(https?|rtsp|rtmp|sftp|ftp|smb):/i.test(rest)) return rest;
            return null;
          }

          function build(streamUrl) {
            var out = SCHEME + encodeURIComponent(streamUrl);
            var cb = detailCallback();
            if (cb) out += '&x-success=' + encodeURIComponent(cb);
            return out;
          }

          function rewrite(href) {
            var stream = unwrap(href);
            if (!stream) return null;
            return build(stream);
          }

          // 1. Anchor clicks.
          document.addEventListener('click', function (event) {
            var node = event.target;
            while (node && node.tagName !== 'A') node = node.parentElement;
            if (!node || !node.getAttribute) return;
            var href = node.getAttribute('href') || '';
            var pearl = rewrite(href);
            if (pearl) {
              event.preventDefault();
              event.stopPropagation();
              location.href = pearl;
            }
          }, true);

          // 2. Anything that assigns location or opens a window.
          var assign = function (value) {
            if (typeof value === 'string') {
              var pearl = rewrite(value);
              if (pearl) return pearl;
            }
            return value;
          };
          var nativeOpen = window.open;
          window.open = function (url) {
            var pearl = assign(url);
            if (pearl !== url) { location.href = pearl; return null; }
            return nativeOpen.apply(window, arguments);
          };

          // 3. A visible fallback: a floating button that sends the copied link.
          window.addEventListener('load', function () {
            var button = document.createElement('div');
            button.textContent = 'Pearl';
            button.style.cssText = [
              'position:fixed', 'z-index:2147483647', 'right:12px', 'bottom:78px',
              'padding:10px 14px', 'border-radius:999px', 'font:600 13px -apple-system,sans-serif',
              'background:#1d1d1f', 'color:#fff', 'box-shadow:0 4px 14px rgba(0,0,0,.4)'
            ].join(';');
            button.onclick = function () {
              navigator.clipboard.readText().then(function (text) {
                var url = text && text.trim();
                if (!url) { alert('Copy a stream link first.'); return; }
                location.href = build(url);
              }).catch(function () {
                alert('Long press a stream, copy the link, then tap Pearl.');
              });
            };
            document.body.appendChild(button);
          });
        })();
        """
}
