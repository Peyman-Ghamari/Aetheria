#pragma once

#include <QObject>
#include <QTimer>
#include "AudioEngine.h"

class SleepTimer : public QObject {
    Q_OBJECT

    Q_PROPERTY(bool isActive READ isActive NOTIFY activeChanged)
    Q_PROPERTY(int remainingSeconds READ remainingSeconds NOTIFY remainingSecondsChanged)

public:
    explicit SleepTimer(AudioEngine *audioEngine, QObject *parent = nullptr);
    ~SleepTimer() override = default;

    bool isActive() const;
    int remainingSeconds() const;

public slots:
    void startTimer(int minutes);
    void cancelTimer();

    signals:
        void activeChanged(bool active);
    void remainingSecondsChanged(int seconds);
    void timerCompleted();

private slots:
    void onTick();

private:
    AudioEngine *m_audioEngine;
    QTimer *m_tickTimer;
    int m_remainingSeconds = 0;
    float m_initialVolume = 1.0f;
    const int FADE_DURATION_SEC = 30;
};