/**
 * Service Worker para Acordeón Diatónico Pro (PWA)
 * Estrategia Network-First con fallback a caché para soporte offline confiable
 */
const CACHE_NAME = 'acordeon-pro-v63';
const ASSETS_TO_CACHE = [
    './',
    './index.html',
    './manifest.json',
    './css/variables.css',
    './css/reset.css',
    './css/layout.css',
    './css/diapason.css',
    './css/controls.css',
    './css/sheet_music.css',
    './css/main.css',
    './src/app.js',
    './src/core/Constants.js',
    './src/core/EventBus.js',
    './src/core/StateMachine.js',
    './src/audio/IAudioEngine.js',
    './src/audio/WebAudioSynth.js',
    './src/audio/AudioEngine.js',
    './src/audio/AudioChordAnalyzer.js',
    './src/audio/AudioPlayerController.js',
    './src/audio/MetronomeEngine.js',
    './src/models/AccordionData.js',
    './src/models/Tunings.js',
    './src/models/SheetMusicData.js',
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
    './src/ui/ExecutionView.js',
    './src/ui/AudioTrackView.js',
    './src/ui/CadenceView.js',
    './src/ui/DiapasonChordSidebarView.js',
    './src/ui/SheetMusicModalView.js',
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

// Estrategia Network-First: Siempre obtiene los cambios más recientes de la red,
// y recurre al caché solo cuando no hay conexión (offline).
self.addEventListener('fetch', (e) => {
    if (e.request.method !== 'GET') return;

    e.respondWith(
        fetch(e.request)
            .then((networkResponse) => {
                if (networkResponse && networkResponse.status === 200) {
                    const clone = networkResponse.clone();
                    caches.open(CACHE_NAME).then((cache) => {
                        cache.put(e.request, clone);
                    });
                }
                return networkResponse;
            })
            .catch(() => {
                return caches.match(e.request).then((cachedResponse) => {
                    if (cachedResponse) return cachedResponse;
                    if (e.request.destination === 'document') {
                        return caches.match('./index.html');
                    }
                });
            })
    );
});
