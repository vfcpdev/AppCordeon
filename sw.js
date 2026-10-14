/**
 * Service Worker para Acordeón Diatónico Pro (PWA)
 */
const CACHE_NAME = 'acordeon-pro-v1';
const ASSETS_TO_CACHE = [
    './',
    './index.html',
    './manifest.json',
    './css/variables.css',
    './css/reset.css',
    './css/layout.css',
    './css/diapason.css',
    './css/controls.css',
    './css/main.css',
    './src/app.js',
    './src/core/Constants.js',
    './src/core/EventBus.js',
    './src/core/StateMachine.js',
    './src/audio/IAudioEngine.js',
    './src/audio/WebAudioSynth.js',
    './src/audio/AudioEngine.js',
    './src/models/AccordionData.js',
    './src/models/Tunings.js',
    './src/theory/MusicTheory.js',
    './src/theory/Scales.js',
    './src/theory/ChordTemplates.js',
    './src/strategies/HarmonicAnalysisStrategy.js',
    './src/strategies/FeasibilityAnalysisStrategy.js',
    './src/ui/ButtonFactory.js',
    './src/ui/DiapasonView.js',
    './src/ui/ScaleBarView.js',
    './src/ui/ChordView.js',
    './src/ui/DetectorView.js',
    './src/audio/AudioChordAnalyzer.js',
    './src/audio/AudioPlayerController.js',
    './src/ui/AudioTrackView.js',
    './src/controllers/AppController.js'
];

self.addEventListener('install', (e) => {
    e.waitUntil(
        caches.open(CACHE_NAME).then((cache) => {
            return cache.addAll(ASSETS_TO_CACHE);
        })
    );
    self.skipWaiting();
});

self.addEventListener('activate', (e) => {
    e.waitUntil(
        caches.keys().then((keys) => {
            return Promise.all(
                keys.map((k) => {
                    if (k !== CACHE_NAME) {
                        return caches.delete(k);
                    }
                })
            );
        })
    );
    self.clients.claim();
});

self.addEventListener('fetch', (e) => {
    e.respondWith(
        caches.match(e.request).then((cachedResponse) => {
            return cachedResponse || fetch(e.request).catch(() => {
                // Modo offline fallback
                if (e.request.destination === 'document') {
                    return caches.match('./index.html');
                }
            });
        })
    );
});
