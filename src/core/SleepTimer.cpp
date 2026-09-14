#include "SleepTimer.h"
#include <QtGlobal>

SleepTimer::SleepTimer(AudioEngine *audioEngine, QObject *parent)
    : QObject(parent)
    , m_audioEngine(audioEngine)
    , m_tickTimer(new QTimer(this)) {

    m_tickTimer->setInterval(1000);
    m_tickTimer->setTimerType(Qt::CoarseTimer);
    connect(m_tickTimer, &QTimer::timeout, this, &SleepTimer::onTick);
}

bool SleepTimer::isActive() const {
    return m_tickTimer->isActive();
}

int SleepTimer::remainingSeconds() const {
    return m_remainingSeconds;
}

void SleepTimer::startTimer(int minutes) {
    if (minutes <= 0 || !m_audioEngine) return;

    m_remainingSeconds = minutes * 60;
    m_initialVolume = m_audioEngine->volume();

    m_tickTimer->start();
    emit activeChanged(true);
    emit remainingSecondsChanged(m_remainingSeconds);
}

void SleepTimer::cancelTimer() {
    if (m_tickTimer->isActive()) {
        m_tickTimer->stop();
        m_remainingSeconds = 0;

        if (m_audioEngine) {
            m_audioEngine->setVolume(m_initialVolume);
        }

        emit activeChanged(false);
        emit remainingSecondsChanged(0);
    }
}

void SleepTimer::onTick() {
    if (!m_audioEngine) {
        m_tickTimer->stop();
        return;
    }

    if (m_remainingSeconds > 0) {
        m_remainingSeconds--;
        emit remainingSecondsChanged(m_remainingSeconds);


        if (m_remainingSeconds <= FADE_DURATION_SEC) {
            float fadeProgress = static_cast<float>(m_remainingSeconds) / static_cast<float>(FADE_DURATION_SEC);
            float currentFadeVolume = m_initialVolume * fadeProgress;
            m_audioEngine->setVolume(qMax(0.0f, currentFadeVolume));
        }
    } else {

        m_tickTimer->stop();
        m_audioEngine->pause();
        m_audioEngine->setVolume(m_initialVolume);

        emit activeChanged(false);
        emit remainingSecondsChanged(0);
        emit timerCompleted();
    }
}