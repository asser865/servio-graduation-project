// Speech-to-text provider abstraction.
// Today: WebSpeechProvider (browser-native, free, Chrome/Edge/Safari).
// Tomorrow: swap to WhisperProvider with same interface — no UI change.

/**
 * @typedef {Object} SpeechProvider
 * @property {() => boolean} isSupported
 * @property {(opts: ProviderOptions) => void} start
 * @property {() => void} stop
 * @property {() => boolean} isActive
 */

/**
 * @typedef {Object} ProviderOptions
 * @property {string} lang           BCP-47 (e.g. 'en-US', 'ar-EG')
 * @property {(text: string) => void} onFinal      Final transcript chunk
 * @property {(text: string) => void} onInterim    Interim transcript (replaces previous)
 * @property {() => void} onStart
 * @property {() => void} onEnd
 * @property {(code: string) => void} onError     'denied' | 'no-mic' | 'no-speech' | 'network' | 'unknown'
 */

function createWebSpeechProvider() {
  const Recognition = window.SpeechRecognition || window.webkitSpeechRecognition;
  let recognition = null;
  let active = false;
  let manualStop = false;

  function isSupported() {
    return !!Recognition && window.isSecureContext !== false;
  }

  function start(opts) {
    if (!isSupported() || active) return;
    recognition = new Recognition();
    recognition.lang = opts.lang;
    recognition.continuous = true;
    recognition.interimResults = true;
    recognition.maxAlternatives = 1;
    manualStop = false;

    recognition.onstart = () => {
      active = true;
      opts.onStart?.();
    };

    recognition.onresult = (event) => {
      let interim = '';
      for (let i = event.resultIndex; i < event.results.length; i++) {
        const result = event.results[i];
        const transcript = result[0]?.transcript || '';
        if (result.isFinal) {
          opts.onFinal?.(transcript);
        } else {
          interim += transcript;
        }
      }
      if (interim) opts.onInterim?.(interim);
    };

    recognition.onerror = (event) => {
      const map = {
        'not-allowed': 'denied',
        'service-not-allowed': 'denied',
        'audio-capture': 'no-mic',
        'no-speech': 'no-speech',
        'network': 'network',
      };
      opts.onError?.(map[event.error] || 'unknown');
    };

    recognition.onend = () => {
      active = false;
      opts.onEnd?.();
      // Browsers auto-stop after silence; user wanted continuous → restart unless manual.
      if (!manualStop) {
        try { recognition.start(); active = true; } catch (_) { /* race */ }
      }
    };

    try {
      recognition.start();
    } catch (e) {
      opts.onError?.('unknown');
    }
  }

  function stop() {
    manualStop = true;
    if (recognition && active) {
      try { recognition.stop(); } catch (_) { /* noop */ }
    }
    active = false;
  }

  function isActive() {
    return active;
  }

  return { isSupported, start, stop, isActive };
}

// Public factory. Returns provider for current backend.
export function getSpeechProvider() {
  return createWebSpeechProvider();
}

// Map app lang ('en' | 'ar') → BCP-47 tag for recognition.
// ar-SA chosen over ar-EG: broader Chrome coverage and stronger acoustic model.
export function resolveSpeechLang(appLang) {
  return appLang === 'ar' ? 'ar-SA' : 'en-US';
}
