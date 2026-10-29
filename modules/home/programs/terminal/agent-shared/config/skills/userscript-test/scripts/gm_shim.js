// GM_* compatibility shim for userscript-test. Runs in the page world at document-start.
// Storage and cross-origin requests are bridged to the Python runner, which performs
// the real work (Python has no CORS restrictions and persists values to disk).
(function () {
  if (window.__US_SHIM_READY__) return;
  window.__US_SHIM_READY__ = true;

  var CFG = window.__US_CFG__ || {};
  var LOG = function () {
    var a = Array.prototype.slice.call(arguments);
    console.log.apply(console, ['[userscript-test]'].concat(a));
  };

  // Bridge - Present in the page world as a Playwright binding. When the harness
  // runs the script inside a real userscript manager this is absent, so every call
  // degrades to a local no-op instead of throwing.
  function bridge(op, payload) {
    if (typeof window.__us_bridge !== 'function') return Promise.resolve(null);
    try {
      return Promise.resolve(window.__us_bridge(op, payload));
    } catch (e) {
      return Promise.reject(e);
    }
  }

  // URL Matching - Simplified @match/@include: '*' becomes '.*', other regex
  // metacharacters are literal. Sufficient for gating, not spec-exact.
  function globToRegex(pattern) {
    var escaped = pattern.replace(/[.+?^${}()|[\]\\]/g, '\\$&').replace(/\*/g, '.*');
    return new RegExp('^' + escaped + '$');
  }

  function asRegex(pattern) {
    if (pattern.length > 2 && pattern.charAt(0) === '/') {
      var end = pattern.lastIndexOf('/');
      if (end > 0) {
        try {
          return new RegExp(pattern.slice(1, end), pattern.slice(end + 1));
        } catch (e) {
          return null;
        }
      }
    }
    return globToRegex(pattern);
  }

  function urlMatches(href) {
    var patterns = (CFG.matches || []).concat(CFG.includes || []);
    if (!patterns.length) return true;
    for (var i = 0; i < patterns.length; i++) {
      var re = asRegex(patterns[i]);
      if (re && re.test(href)) return true;
    }
    return false;
  }

  // Storage - Local map keeps legacy sync getters working; the bridge persists.
  var store = Object.assign({}, CFG.storage || {});
  var pending = {};

  function getValue(key, def) {
    if (!(key in store) && key in pending) {
      var p = pending[key];
      delete pending[key];
      p.then(function (v) {
        if (v !== null && v !== undefined) store[key] = v;
      });
    }
    return key in store ? store[key] : def;
  }

  function setValue(key, value) {
    store[key] = value;
    bridge('setValue', { key: key, value: value });
  }

  function deleteValue(key) {
    delete store[key];
    bridge('deleteValue', { key: key });
  }

  function listValues() {
    return Object.keys(store);
  }

  function getValueAsync(key, def) {
    return bridge('getValue', { key: key }).then(function (r) {
      if (r && r.found) {
        store[key] = r.value;
        return r.value;
      }
      return def;
    });
  }

  function setValueAsync(key, value) {
    store[key] = value;
    return bridge('setValue', { key: key, value: value }).then(function () {
      return undefined;
    });
  }

  // Style Insertion - At document-start the document can be completely empty
  // (no documentElement yet), so defer until there is somewhere to append.
  function whenDocumentReady(fn) {
    if (document.documentElement) {
      fn(document.documentElement);
      return;
    }
    var observer = new MutationObserver(function () {
      if (!document.documentElement) return;
      observer.disconnect();
      fn(document.documentElement);
    });
    observer.observe(document, { childList: true, subtree: true });
  }

  function appendStyle(css, host) {
    var style = document.createElement('style');
    style.textContent = css;
    host.appendChild(style);
    if (document.head && style.parentNode !== document.head) document.head.appendChild(style);
    return style;
  }

  function addStyle(css) {
    var host = document.head || document.body || document.documentElement;
    if (host) return appendStyle(css, host);
    var handle = { textContent: css };
    whenDocumentReady(function (el) {
      handle.textContent = null;
      appendStyle(css, el);
    });
    return handle;
  }

  function addElement(parent, tag, attrs) {
    var el = document.createElement(tag);
    Object.keys(attrs || {}).forEach(function (k) {
      el.setAttribute(k, attrs[k]);
    });
    var host = parent || document.head || document.body || document.documentElement;
    if (host) host.appendChild(el);
    else whenDocumentReady(function (root) { root.appendChild(el); });
    return el;
  }

  // Menu Commands - Registered callbacks stay on window so the runner can invoke
  // them by name (mirrors clicking a userscript-manager menu entry).
  var menus = (window.__US_MENUS__ = window.__US_MENUS__ || {});
  var menuSeq = 0;

  function registerMenuCommand(name, fn, accessKey) {
    menuSeq += 1;
    var id = 'menu' + menuSeq;
    menus[id] = { id: id, name: name, fn: fn, accessKey: accessKey };
    bridge('menu', { id: id, name: name });
    return id;
  }

  function unregisterMenuCommand(id) {
    delete menus[id];
  }

  function makeResponse(r) {
    return {
      readyState: 4,
      status: r.status,
      statusText: r.statusText || '',
      responseText: r.text,
      response: r.text,
      responseHeaders: r.headers || '',
      finalUrl: r.url || '',
      responseType: '',
    };
  }

  function xmlhttpRequest(details) {
    var d = details || {};
    var settled = bridge('xhr', {
      method: d.method || 'GET',
      url: d.url,
      headers: d.headers || {},
      data: d.data === undefined ? null : d.data,
      timeout: d.timeout || null,
    });

    var promise = settled.then(function (r) {
      if (!r || r.error) throw new Error((r && r.error) || 'request failed');
      return makeResponse(r);
    });

    promise.then(
      function (resp) {
        if (typeof d.onload === 'function') d.onload(resp);
      },
      function (err) {
        if (typeof d.onerror === 'function') d.onerror({ error: String(err), status: 0 });
        else LOG('GM_xmlhttpRequest failed:', String(err));
      }
    );

    var handle = { abort: function () {} };
    handle.then = function (a, b) {
      return promise.then(a, b);
    };
    handle.catch = function (b) {
      return promise.catch(b);
    };
    return handle;
  }

  function unsupported(name) {
    return function () {
      LOG(name, 'is not supported by userscript-test (no-op):', arguments[0]);
    };
  }

  var GM = {
    info: (function () {
      var info = CFG.info || {};
      return Object.assign({ scriptHandler: 'userscript-test', version: '1.0' }, info);
    })(),
    getValue: getValueAsync,
    setValue: setValueAsync,
    deleteValue: function (k) {
      return Promise.resolve(deleteValue(k));
    },
    listValues: function () {
      return Promise.resolve(listValues());
    },
    addStyle: addStyle,
    addElement: addElement,
    registerMenuCommand: registerMenuCommand,
    unregisterMenuCommand: unregisterMenuCommand,
    xmlHttpRequest: xmlhttpRequest,
    // Managers accept both spellings; scripts in the wild use either.
    xmlhttpRequest: xmlhttpRequest,
    openInTab: function (url) {
      return bridge('openInTab', { url: url });
    },
    notification: unsupported('GM.notification'),
    download: unsupported('GM.download'),
    getResourceText: unsupported('GM.getResourceText'),
    getResourceUrl: unsupported('GM.getResourceUrl'),
    setClipboard: unsupported('GM.setClipboard'),
  };

  // Legacy underscore API, plus GM.* modern API. Both are provided regardless of
  // @grant because scripts in this repo mix the two styles freely.
  window.GM = GM;
  window.GM_info = GM.info;
  window.GM_getValue = getValue;
  window.GM_setValue = setValue;
  window.GM_deleteValue = deleteValue;
  window.GM_listValues = listValues;
  window.GM_addStyle = addStyle;
  window.GM_addElement = function (tag, attrs, parent) {
    return addElement(parent, tag, attrs);
  };
  window.GM_registerMenuCommand = registerMenuCommand;
  window.GM_unregisterMenuCommand = unregisterMenuCommand;
  window.GM_xmlhttpRequest = xmlhttpRequest;
  window.GM_xmlHttpRequest = xmlhttpRequest;
  window.GM_openInTab = GM.openInTab;
  window.GM_notification = GM.notification;
  window.GM_download = GM.download;
  window.GM_getResourceText = GM.getResourceText;
  window.GM_getResourceURL = GM.getResourceUrl;

  var realWindow = window;
  Object.defineProperty(window, 'unsafeWindow', {
    configurable: true,
    get: function () {
      return realWindow;
    },
  });

  // Exported for the runner's match gate and documentation.
  window.__US_MATCHES__ = urlMatches;
})();
