#include "EqualizerModel.h"
#include <QSettings>
#include <QVariantList>
#include <QtMath>

static const float FREQUENCIES[10] = {
    31.0f, 63.0f, 125.0f, 250.0f, 500.0f, 1000.0f, 2000.0f, 4000.0f, 8000.0f, 16000.0f
};

EqualizerModel::EqualizerModel(QObject *parent)
    : QObject(parent)
    , m_gains(10, 0.0f) {
    loadSettings();
    updateAllCoefficients();
}

bool EqualizerModel::isEnabled() const {
    return m_isEnabled;
}

QString EqualizerModel::currentPreset() const {
    return m_currentPreset;
}

QStringList EqualizerModel::availablePresets() const {
    return { "Flat", "Bass Boost", "Vocal Boost", "Treble Boost", "Rock", "Pop", "Jazz", "Electronic" };
}

QStringList EqualizerModel::bandLabels() const {
    return { "31Hz", "63Hz", "125Hz", "250Hz", "500Hz", "1kHz", "2kHz", "4kHz", "8kHz", "16kHz" };
}

float EqualizerModel::getBandGain(int index) const {
    if (index >= 0 && index < m_gains.size()) {
        return m_gains[index];
    }
    return 0.0f;
}

void EqualizerModel::setIsEnabled(bool enabled) {
    if (m_isEnabled != enabled) {
        m_isEnabled = enabled;
        saveSettings();
        emit isEnabledChanged();
    }
}

void EqualizerModel::setBandGain(int index, float gainDb) {
    if (index < 0 || index >= m_gains.size()) return;
    m_gains[index] = gainDb;
    m_currentPreset = "Custom";
    updateCoefficients(index);
    saveSettings();
    emit bandGainsChanged();
    emit currentPresetChanged();
}

void EqualizerModel::resetToFlat() {
    setCurrentPreset("Flat");
}

void EqualizerModel::setCurrentPreset(const QString &presetName) {
    m_currentPreset = presetName;

    if (presetName == "Flat") {
        m_gains = {0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f};
    } else if (presetName == "Bass Boost") {
        m_gains = {7.0f, 5.5f, 3.5f, 1.5f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f};
    } else if (presetName == "Vocal Boost") {
        m_gains = {-2.0f, -1.0f, 0.0f, 2.5f, 5.0f, 4.0f, 1.5f, 0.0f, -1.0f, -2.0f};
    } else if (presetName == "Treble Boost") {
        m_gains = {0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 1.0f, 3.0f, 5.0f, 6.5f, 7.0f};
    } else if (presetName == "Rock") {
        m_gains = {5.5f, 3.5f, -1.5f, -2.0f, -0.5f, 1.5f, 3.5f, 5.0f, 5.5f, 5.5f};
    } else if (presetName == "Pop") {
        m_gains = {-1.5f, 1.0f, 3.5f, 5.0f, 3.5f, 0.0f, -1.0f, -1.5f, -1.5f, -1.5f};
    } else if (presetName == "Jazz") {
        m_gains = {4.0f, 2.5f, 0.0f, 1.5f, -1.5f, -1.5f, 0.0f, 2.0f, 3.5f, 4.0f};
    } else if (presetName == "Electronic") {
        m_gains = {6.0f, 4.5f, 1.5f, 0.0f, -2.0f, 2.0f, 1.5f, 3.5f, 5.5f, 6.0f};
    }

    updateAllCoefficients();
    saveSettings();
    emit bandGainsChanged();
    emit currentPresetChanged();
}

void EqualizerModel::setSampleRate(float sampleRate) {
    if (sampleRate > 1000.0f && std::abs(m_sampleRate - sampleRate) > 1.0f) {
        m_sampleRate = sampleRate;
        updateAllCoefficients();
    }
}

void EqualizerModel::updateCoefficients(int index) {
    if (index < 0 || index >= 10) return;

    float f0 = FREQUENCIES[index];
    float gainDb = m_gains[index];
    float Q = 1.414f;

    if (f0 >= (m_sampleRate / 2.0f) * 0.95f) {
        m_filters[index].b0 = 1.0f;
        m_filters[index].b1 = m_filters[index].b2 = m_filters[index].a1 = m_filters[index].a2 = 0.0f;
        return;
    }

    float A = std::pow(10.0f, gainDb / 40.0f);
    float omega = 2.0f * static_cast<float>(M_PI) * f0 / m_sampleRate;
    float alpha = std::sin(omega) / (2.0f * Q);
    float cos_w = std::cos(omega);

    float b0 = 1.0f + alpha * A;
    float b1 = -2.0f * cos_w;
    float b2 = 1.0f - alpha * A;
    float a0 = 1.0f + alpha / A;
    float a1 = -2.0f * cos_w;
    float a2 = 1.0f - alpha / A;

    m_filters[index].b0 = b0 / a0;
    m_filters[index].b1 = b1 / a0;
    m_filters[index].b2 = b2 / a0;
    m_filters[index].a1 = a1 / a0;
    m_filters[index].a2 = a2 / a0;
}

void EqualizerModel::updateAllCoefficients() {
    for (int i = 0; i < 10; ++i) {
        updateCoefficients(i);
        m_filters[i].reset();
    }
}

void EqualizerModel::processStereo(float *left, float *right, int frameCount) {
    if (!m_isEnabled) return;

    for (int i = 0; i < 10; ++i) {
        if (std::abs(m_gains[i]) < 0.01f) continue;
        auto &filter = m_filters[i];
        for (int f = 0; f < frameCount; ++f) {
            filter.process(left[f], right[f]);
        }
    }
}

void EqualizerModel::loadSettings() {
    QSettings settings;
    m_isEnabled = settings.value("equalizer/enabled", false).toBool();
    m_currentPreset = settings.value("equalizer/preset", "Flat").toString();

    QVariantList list = settings.value("equalizer/gains").toList();
    if (list.size() == 10) {
        for (int i = 0; i < 10; ++i) {
            m_gains[i] = list[i].toFloat();
        }
    }
}

void EqualizerModel::saveSettings() {
    QSettings settings;
    settings.setValue("equalizer/enabled", m_isEnabled);
    settings.setValue("equalizer/preset", m_currentPreset);

    QVariantList list;
    for (float g : m_gains) {
        list.append(g);
    }
    settings.setValue("equalizer/gains", list);
}