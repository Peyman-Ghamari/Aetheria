#pragma once

#include <QObject>
#include <QAudioFormat>
#include <QByteArray>
#include <QMutex>
#include <QIODevice>
#include <QMediaPlayer>
#include <QAudioOutput>
#include <QMediaDevices>
#include <QAudioDevice>
#include <QAudioSink>
#include <QThread>
#include <QTimer>
#include <QStringList>
#include <vector>
#include <atomic>

class QAudioDecoder;
class EqualizerModel;
class AudioEngine;


class AudioPushWorker : public QObject {
    Q_OBJECT
public:
    explicit AudioPushWorker(AudioEngine *engine, QObject *parent = nullptr);
    ~AudioPushWorker() override;

public slots:
    void initSink(const QAudioDevice &device, const QAudioFormat &format);
    void startPlayback();
    void pausePlayback();
    void stopPlayback();
    void flushAudio();

private slots:
    void feedAudio();

private:
    void cleanupSink();

    AudioEngine *m_engine = nullptr;
    QAudioSink *m_sink = nullptr;
    QIODevice *m_outputDevice = nullptr;
    QTimer *m_feedTimer = nullptr;
    QAudioDevice m_currentDev;
    QAudioFormat m_currentFmt;
};

class AudioEngine : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool isPlaying READ isPlaying NOTIFY playingChanged)
    Q_PROPERTY(qint64 position READ position NOTIFY positionChanged)
    Q_PROPERTY(qint64 duration READ duration NOTIFY durationChanged)
    Q_PROPERTY(float volume READ volume WRITE setVolume NOTIFY volumeChanged)
    Q_PROPERTY(QString currentSource READ currentSource NOTIFY currentSourceChanged)
    Q_PROPERTY(bool isShuffle READ isShuffle WRITE setShuffle NOTIFY shuffleChanged)
    Q_PROPERTY(int repeatMode READ repeatMode WRITE setRepeatMode NOTIFY repeatModeChanged)
    Q_PROPERTY(QStringList outputDevices READ outputDevices NOTIFY outputDevicesChanged)
    Q_PROPERTY(QString currentDeviceName READ currentDeviceName NOTIFY currentDeviceNameChanged)

    friend class AudioPushWorker;

public:
    enum RepeatMode {
        RepeatOff = 0,
        RepeatAll,
        RepeatOne
    };
    Q_ENUM(RepeatMode)

    explicit AudioEngine(QObject *parent = nullptr);
    ~AudioEngine() override;

    bool isPlaying() const;
    qint64 position() const;
    qint64 duration() const;
    float volume() const;
    QString currentSource() const;
    bool isShuffle() const;
    int repeatMode() const;
    QStringList outputDevices() const;
    QString currentDeviceName() const;

    void setEqualizerModel(EqualizerModel *eqModel);

    Q_INVOKABLE void loadSource(const QString &source);
    Q_INVOKABLE void play();
    Q_INVOKABLE void pause();
    Q_INVOKABLE void stop();
    Q_INVOKABLE void togglePlayPause();
    Q_INVOKABLE void setPosition(qint64 position);
    Q_INVOKABLE void setVolume(float volume);
    Q_INVOKABLE void setShuffle(bool shuffle);
    Q_INVOKABLE void toggleShuffle();
    Q_INVOKABLE void setRepeatMode(int mode);
    Q_INVOKABLE void cycleRepeatMode();
    Q_INVOKABLE void playUrl(const QString &url);
    Q_INVOKABLE void setAudioOutputDevice(const QString &deviceName);

signals:
    void playingChanged(bool isPlaying);
    void positionChanged(qint64 position);
    void durationChanged(qint64 duration);
    void volumeChanged(float volume);
    void currentSourceChanged(const QString &source);
    void shuffleChanged(bool isShuffle);
    void repeatModeChanged(int repeatMode);
    void outputDevicesChanged();
    void currentDeviceNameChanged();

private slots:
    void handleBufferReady();
    void handleDecoderFinished();

private:
    void setupLocalAudio();
    void setupStreamPlayer();
    void updateAudioDevices();
    static bool isRemoteSource(const QString &source);

    QMediaPlayer *m_streamPlayer = nullptr;
    QAudioOutput *m_streamAudioOutput = nullptr;

    QAudioDecoder *m_decoder = nullptr;
    AudioPushWorker *m_pushWorker = nullptr;
    QThread m_audioThread;
    EqualizerModel *m_equalizerModel = nullptr;

    QMediaDevices *m_devices = nullptr;
    QList<QAudioDevice> m_availableDevices;
    QAudioDevice m_currentOutputDevice;

    QAudioFormat m_format;
    QByteArray m_pcmBuffer;
    mutable QMutex m_bufferMutex;

    std::atomic<qint64> m_atomicReadOffset{0};
    std::atomic<bool> m_isSeeking{false};

    std::vector<float> m_leftChannel;
    std::vector<float> m_rightChannel;

    bool m_isPlaying = false;
    bool m_isCurrentStream = false;
    qint64 m_durationMs = 0;
    float m_volume = 0.70f;
    QString m_currentSource;
    bool m_isShuffle = false;
    int m_repeatMode = RepeatOff;

    QTimer *m_uiPositionTimer = nullptr;
};