#include "AudioEngine.h"
#include "EqualizerModel.h"

#include <QUrl>
#include <QAudioDecoder>
#include <QAudioSink>
#include <QAudioDevice>
#include <QMediaDevices>
#include <QFileInfo>
#include <QDir>
#include <QSettings>
#include <QDebug>
#include <algorithm>

// =========================================================================
// Audio Push Worker Implementation Using Push Stream Pattern
// =========================================================================

AudioPushWorker::AudioPushWorker(AudioEngine *engine, QObject *parent)
    : QObject(parent), m_engine(engine) {
    m_feedTimer = new QTimer(this);
    m_feedTimer->setInterval(15);
    connect(m_feedTimer, &QTimer::timeout, this, &AudioPushWorker::feedAudio);
}

AudioPushWorker::~AudioPushWorker() {
    cleanupSink();
}

void AudioPushWorker::cleanupSink() {
    if (m_feedTimer) m_feedTimer->stop();
    if (m_sink) {
        m_sink->stop();
        delete m_sink;
        m_sink = nullptr;
    }
    m_outputDevice = nullptr;
}

void AudioPushWorker::initSink(const QAudioDevice &device, const QAudioFormat &format) {
    cleanupSink();
    m_currentDev = device;
    m_currentFmt = format;

    m_sink = new QAudioSink(device, format, this);
    m_sink->setVolume(1.0f);

    int bytesPerSec = format.sampleRate() * format.channelCount() * sizeof(float);
    if (bytesPerSec > 0) {

        m_sink->setBufferSize(bytesPerSec / 10);
    }

    m_outputDevice = m_sink->start();
    m_feedTimer->start();
}

void AudioPushWorker::startPlayback() {
    if (!m_sink && !m_currentDev.isNull()) {
        initSink(m_currentDev, m_currentFmt);
    }
    if (m_sink) {
        if (m_sink->state() == QtAudio::SuspendedState) {
            m_sink->resume();
        } else if (m_sink->state() == QtAudio::StoppedState) {
            m_outputDevice = m_sink->start();
        }
    }
    if (m_feedTimer && !m_feedTimer->isActive()) {
        m_feedTimer->start();
    }
}

void AudioPushWorker::pausePlayback() {
    if (m_sink) m_sink->suspend();
    if (m_feedTimer) m_feedTimer->stop();
}

void AudioPushWorker::stopPlayback() {
    cleanupSink();
}

void AudioPushWorker::flushAudio() {

}

void AudioPushWorker::feedAudio() {
    if (!m_sink || !m_outputDevice || !m_engine) return;

    qint64 bytesFree = m_sink->bytesFree();
    if (bytesFree <= 0) return;

    if (m_engine->m_isSeeking.load(std::memory_order_acquire)) return;

    qint64 currentOffset = m_engine->m_atomicReadOffset.load(std::memory_order_relaxed);

    QByteArray chunk;
    {
        QMutexLocker locker(&m_engine->m_bufferMutex);
        qint64 available = m_engine->m_pcmBuffer.size() - currentOffset;
        if (available <= 0) {
            bool decoderFinished = (m_engine->m_decoder && !m_engine->m_decoder->isDecoding());
            if (decoderFinished && m_engine->m_pcmBuffer.size() > 0 && m_sink->state() == QtAudio::IdleState) {
                QMetaObject::invokeMethod(m_engine, [this]() {
                    if (m_engine->m_repeatMode == AudioEngine::RepeatOne) {
                        m_engine->setPosition(0);
                        m_engine->play();
                    } else {
                        emit m_engine->positionChanged(m_engine->m_durationMs);
                    }
                }, Qt::QueuedConnection);
            }
            return;
        }

        qint64 toRead = std::min(bytesFree, available);
        int sampleSize = sizeof(float) * 2;
        toRead = (toRead / sampleSize) * sampleSize;
        if (toRead <= 0) return;

        chunk = QByteArray(m_engine->m_pcmBuffer.constData() + currentOffset, toRead);
        m_engine->m_atomicReadOffset.store(currentOffset + toRead, std::memory_order_release);
    }

    int sampleSize = sizeof(float) * 2;
    int frameCount = chunk.size() / sampleSize;
    auto *srcDstPtr = reinterpret_cast<float *>(chunk.data());

    if (m_engine->m_leftChannel.size() < static_cast<size_t>(frameCount)) {
        m_engine->m_leftChannel.resize(frameCount);
        m_engine->m_rightChannel.resize(frameCount);
    }

    for (int i = 0; i < frameCount; ++i) {
        m_engine->m_leftChannel[i] = srcDstPtr[i * 2];
        m_engine->m_rightChannel[i] = srcDstPtr[i * 2 + 1];
    }

    if (m_engine->m_equalizerModel && m_engine->m_equalizerModel->isEnabled()) {
        m_engine->m_equalizerModel->processStereo(m_engine->m_leftChannel.data(), m_engine->m_rightChannel.data(), frameCount);
    }

    float vol = m_engine->m_volume;
    for (int i = 0; i < frameCount; ++i) {
        srcDstPtr[i * 2]     = std::clamp(m_engine->m_leftChannel[i] * vol, -1.0f, 1.0f);
        srcDstPtr[i * 2 + 1] = std::clamp(m_engine->m_rightChannel[i] * vol, -1.0f, 1.0f);
    }

    m_outputDevice->write(chunk.constData(), chunk.size());
}

// =========================================================================
// AudioEngine Implementation
// =========================================================================

bool AudioEngine::isRemoteSource(const QString &source) {
    return source.startsWith("http://", Qt::CaseInsensitive) ||
           source.startsWith("https://", Qt::CaseInsensitive);
}

AudioEngine::AudioEngine(QObject *parent)
    : QObject(parent) {

    m_pushWorker = new AudioPushWorker(this);
    m_pushWorker->moveToThread(&m_audioThread);

    connect(&m_audioThread, &QThread::finished, m_pushWorker, &QObject::deleteLater);
    m_audioThread.start(QThread::TimeCriticalPriority);

    m_uiPositionTimer = new QTimer(this);
    m_uiPositionTimer->setInterval(100);
    connect(m_uiPositionTimer, &QTimer::timeout, this, [this]() {
        if (m_isPlaying && !m_isCurrentStream) {
            emit positionChanged(position());
        }
    });
    m_uiPositionTimer->start();

    QSettings settings;
    m_volume = settings.value("audio/volume", 0.70f).toFloat();
    m_isShuffle = settings.value("audio/shuffle", false).toBool();
    m_repeatMode = settings.value("audio/repeatMode", 0).toInt();

    m_devices = new QMediaDevices(this);
    m_currentOutputDevice = QMediaDevices::defaultAudioOutput();
    updateAudioDevices();

    connect(m_devices, &QMediaDevices::audioOutputsChanged, this, &AudioEngine::updateAudioDevices);

    setupLocalAudio();
    setupStreamPlayer();
}

AudioEngine::~AudioEngine() {
    stop();

    if (m_streamPlayer) {
        m_streamPlayer->stop();
    }
    if (m_decoder) {
        m_decoder->stop();
    }

    m_audioThread.quit();
    m_audioThread.wait();
}

void AudioEngine::updateAudioDevices() {
    m_availableDevices = QMediaDevices::audioOutputs();
    emit outputDevicesChanged();
}

QStringList AudioEngine::outputDevices() const {
    QStringList names;
    for (const auto &dev : m_availableDevices) {
        names << dev.description();
    }
    return names;
}

QString AudioEngine::currentDeviceName() const {
    return m_currentOutputDevice.description();
}

void AudioEngine::setAudioOutputDevice(const QString &deviceName) {
    for (const auto &dev : m_availableDevices) {
        if (dev.description() == deviceName) {
            if (m_currentOutputDevice == dev) return;

            m_currentOutputDevice = dev;

            if (m_streamAudioOutput) {
                m_streamAudioOutput->setDevice(dev);
            }

            if (!m_currentOutputDevice.isFormatSupported(m_format)) {
                m_format = m_currentOutputDevice.preferredFormat();
                m_format.setSampleFormat(QAudioFormat::Float);
                m_format.setChannelCount(2);
            }

            QMetaObject::invokeMethod(m_pushWorker, "initSink", Qt::QueuedConnection,
                                      Q_ARG(QAudioDevice, m_currentOutputDevice),
                                      Q_ARG(QAudioFormat, m_format));

            emit currentDeviceNameChanged();
            break;
        }
    }
}

void AudioEngine::setupLocalAudio() {
    m_format.setSampleRate(44100);
    m_format.setChannelCount(2);
    m_format.setSampleFormat(QAudioFormat::Float);

    m_decoder = new QAudioDecoder(this);
    m_decoder->setAudioFormat(m_format);

    connect(m_decoder, &QAudioDecoder::bufferReady, this, &AudioEngine::handleBufferReady);
    connect(m_decoder, &QAudioDecoder::finished, this, &AudioEngine::handleDecoderFinished);
    connect(m_decoder, &QAudioDecoder::durationChanged, this, [this](qint64 dur) {
        if (!m_isCurrentStream) {
            m_durationMs = dur;
            emit durationChanged(dur);
        }
    });

    if (!m_currentOutputDevice.isFormatSupported(m_format)) {
        m_format = m_currentOutputDevice.preferredFormat();
        m_format.setSampleFormat(QAudioFormat::Float);
        m_format.setChannelCount(2);
    }

    QMetaObject::invokeMethod(m_pushWorker, "initSink", Qt::QueuedConnection,
                              Q_ARG(QAudioDevice, m_currentOutputDevice),
                              Q_ARG(QAudioFormat, m_format));
}

void AudioEngine::setupStreamPlayer() {
    m_streamPlayer = new QMediaPlayer(this);
    m_streamAudioOutput = new QAudioOutput(this);
    m_streamAudioOutput->setDevice(m_currentOutputDevice);

    m_streamPlayer->setAudioOutput(m_streamAudioOutput);
    m_streamAudioOutput->setVolume(m_volume);

    connect(m_streamPlayer, &QMediaPlayer::positionChanged, this, [this](qint64 pos) {
        if (m_isCurrentStream) {
            emit positionChanged(pos);
        }
    });

    connect(m_streamPlayer, &QMediaPlayer::durationChanged, this, [this](qint64 dur) {
        if (m_isCurrentStream) {
            m_durationMs = dur;
            emit durationChanged(dur);
        }
    });

    connect(m_streamPlayer, &QMediaPlayer::playbackStateChanged, this, [this](QMediaPlayer::PlaybackState state) {
        if (m_isCurrentStream) {
            bool playing = (state == QMediaPlayer::PlayingState);
            if (m_isPlaying != playing) {
                m_isPlaying = playing;
                emit playingChanged(m_isPlaying);
            }
        }
    });

    connect(m_streamPlayer, &QMediaPlayer::mediaStatusChanged, this, [this](QMediaPlayer::MediaStatus status) {
        if (m_isCurrentStream && status == QMediaPlayer::EndOfMedia) {
            if (m_repeatMode == RepeatOne) {
                setPosition(0);
                play();
            } else {
                emit positionChanged(m_durationMs);
            }
        }
    });


    connect(m_streamPlayer, &QMediaPlayer::errorOccurred, this, [](QMediaPlayer::Error error, const QString &errorString) {
        qWarning() << "[AudioEngine - StreamPlayer Error]:" << error << errorString;
    });


}

void AudioEngine::setEqualizerModel(EqualizerModel *eqModel) {
    m_equalizerModel = eqModel;
    if (m_equalizerModel && m_format.sampleRate() > 0) {
        m_equalizerModel->setSampleRate(static_cast<float>(m_format.sampleRate()));
    }
}

bool AudioEngine::isPlaying() const { return m_isPlaying; }

qint64 AudioEngine::position() const {
    if (m_isCurrentStream) {
        return m_streamPlayer ? m_streamPlayer->position() : 0;
    }
    int sampleSize = sizeof(float) * 2;
    int bytesPerSec = m_format.sampleRate() * sampleSize;
    if (bytesPerSec <= 0) return 0;

    qint64 currentOffset = m_atomicReadOffset.load(std::memory_order_relaxed);
    return (currentOffset * 1000) / bytesPerSec;
}

qint64 AudioEngine::duration() const { return m_durationMs; }
float AudioEngine::volume() const { return m_volume; }
QString AudioEngine::currentSource() const { return m_currentSource; }
bool AudioEngine::isShuffle() const { return m_isShuffle; }
int AudioEngine::repeatMode() const { return m_repeatMode; }

void AudioEngine::loadSource(const QString &source) {
    if (source.isEmpty()) return;

    stop();

    m_currentSource = source;
    emit currentSourceChanged(m_currentSource);

    m_durationMs = 0;
    emit durationChanged(0);
    emit positionChanged(0);

    bool isRemote = isRemoteSource(source);
    bool isLargeLocalFile = false;
    QString cleanPath = source;

    if (!isRemote) {
        if (cleanPath.startsWith("file:///", Qt::CaseInsensitive)) {
            cleanPath = cleanPath.mid(8);
        } else if (cleanPath.startsWith("file:", Qt::CaseInsensitive)) {
            cleanPath = cleanPath.mid(5);
        }
        cleanPath = QDir::fromNativeSeparators(cleanPath);

        QFileInfo fileInfo(cleanPath);

        if (fileInfo.exists() && fileInfo.size() > (40LL * 1024 * 1024)) {
            isLargeLocalFile = true;
        }
    }

    m_isCurrentStream = (isRemote || isLargeLocalFile);

    if (m_isCurrentStream) {
        if (m_decoder) m_decoder->stop();
        {
            QMutexLocker locker(&m_bufferMutex);
            m_pcmBuffer.clear();
        }
        m_atomicReadOffset.store(0, std::memory_order_release);

        QUrl targetUrl = isRemote ? QUrl(source) : QUrl::fromLocalFile(cleanPath);
        m_streamPlayer->setSource(targetUrl);
    } else {
        m_streamPlayer->stop();
        m_streamPlayer->setSource(QUrl());

        {
            QMutexLocker locker(&m_bufferMutex);
            m_pcmBuffer.clear();
            m_pcmBuffer.reserve(30 * 1024 * 1024);
        }
        m_atomicReadOffset.store(0, std::memory_order_release);

        QUrl localUrl = QUrl::fromLocalFile(cleanPath);

        m_decoder->stop();
        m_decoder->setSource(localUrl);
        m_decoder->start();
    }
}

void AudioEngine::handleBufferReady() {
    if (m_isCurrentStream || !m_decoder) return;

    QAudioBuffer buffer = m_decoder->read();
    if (!buffer.isValid()) return;


    if (buffer.format() != m_format && m_pcmBuffer.isEmpty()) {
        m_format = buffer.format();
        if (m_equalizerModel) {
            m_equalizerModel->setSampleRate(static_cast<float>(m_format.sampleRate()));
        }
        QMetaObject::invokeMethod(m_pushWorker, "initSink", Qt::QueuedConnection,
                                  Q_ARG(QAudioDevice, m_currentOutputDevice),
                                  Q_ARG(QAudioFormat, m_format));
    }

    const auto *rawBytes = reinterpret_cast<const char *>(buffer.constData<float>());
    if (!rawBytes) {
        rawBytes = reinterpret_cast<const char *>(buffer.data<void>());
    }

    if (rawBytes) {
        QMutexLocker locker(&m_bufferMutex);
        m_pcmBuffer.append(rawBytes, buffer.byteCount());
    }

    if (m_isPlaying) {
        QMetaObject::invokeMethod(m_pushWorker, "startPlayback", Qt::QueuedConnection);
    }
}

void AudioEngine::handleDecoderFinished() {
    if (m_isCurrentStream) return;

    int sampleSize = sizeof(float) * 2;
    int bytesPerSec = m_format.sampleRate() * sampleSize;
    if (bytesPerSec > 0) {
        QMutexLocker locker(&m_bufferMutex);
        qint64 exactDuration = (m_pcmBuffer.size() * 1000) / bytesPerSec;

        if (m_durationMs <= 0) {
            m_durationMs = exactDuration;
            emit durationChanged(m_durationMs);
        }
    }
}

void AudioEngine::play() {
    m_isPlaying = true;
    emit playingChanged(true);

    if (m_isCurrentStream) {
        if (m_streamPlayer) {
            m_streamPlayer->play();
        }
    } else {
        QMetaObject::invokeMethod(m_pushWorker, "startPlayback", Qt::QueuedConnection);
    }
}

void AudioEngine::pause() {
    m_isPlaying = false;
    emit playingChanged(false);

    if (m_isCurrentStream) {
        if (m_streamPlayer) {
            m_streamPlayer->pause();
        }
    } else {
        QMetaObject::invokeMethod(m_pushWorker, "pausePlayback", Qt::QueuedConnection);
    }
}

void AudioEngine::stop() {
    m_isPlaying = false;
    emit playingChanged(false);

    if (m_streamPlayer) {
        m_streamPlayer->stop();
    }
    QMetaObject::invokeMethod(m_pushWorker, "stopPlayback", Qt::QueuedConnection);
    setPosition(0);
}

void AudioEngine::togglePlayPause() {
    if (m_isPlaying) {
        pause();
    } else {
        play();
    }
}

void AudioEngine::setPosition(qint64 position) {
    if (m_isCurrentStream) {
        if (m_streamPlayer) {
            m_streamPlayer->setPosition(position);
        }
        return;
    }

    int sampleSize = sizeof(float) * 2;
    int bytesPerSec = m_format.sampleRate() * sampleSize;
    if (bytesPerSec <= 0) return;

    qint64 targetByte = (position * bytesPerSec) / 1000;
    targetByte = (targetByte / sampleSize) * sampleSize;

    m_isSeeking.store(true, std::memory_order_release);

    {
        QMutexLocker locker(&m_bufferMutex);
        targetByte = std::clamp(targetByte, 0LL, static_cast<qint64>(m_pcmBuffer.size()));
        m_atomicReadOffset.store(targetByte, std::memory_order_release);
    }

    m_isSeeking.store(false, std::memory_order_release);

    if (m_isPlaying) {
        QMetaObject::invokeMethod(m_pushWorker, "startPlayback", Qt::QueuedConnection);
    }

    emit positionChanged(position);
}

void AudioEngine::setVolume(float volume) {
    m_volume = std::clamp(volume, 0.0f, 1.0f);
    QSettings settings;
    settings.setValue("audio/volume", m_volume);

    if (m_streamAudioOutput) {
        m_streamAudioOutput->setVolume(m_volume);
    }
    emit volumeChanged(m_volume);
}

void AudioEngine::setShuffle(bool shuffle) {
    if (m_isShuffle != shuffle) {
        m_isShuffle = shuffle;
        QSettings settings;
        settings.setValue("audio/shuffle", m_isShuffle);
        emit shuffleChanged(m_isShuffle);
    }
}

void AudioEngine::toggleShuffle() {
    setShuffle(!m_isShuffle);
}

void AudioEngine::setRepeatMode(int mode) {
    if (m_repeatMode != mode) {
        m_repeatMode = mode;
        QSettings settings;
        settings.setValue("audio/repeatMode", m_repeatMode);
        emit repeatModeChanged(m_repeatMode);
    }
}

void AudioEngine::cycleRepeatMode() {
    setRepeatMode((m_repeatMode + 1) % 3);
}

void AudioEngine::playUrl(const QString &url) {
    loadSource(url);
    play();
}