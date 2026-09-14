#pragma once

#include <QObject>
#include <QVector>
#include <QStringList>
#include <array>
#include <cmath>

class EqualizerModel : public QObject {
    Q_OBJECT

    Q_PROPERTY(bool isEnabled READ isEnabled WRITE setIsEnabled NOTIFY isEnabledChanged)
    Q_PROPERTY(QString currentPreset READ currentPreset WRITE setCurrentPreset NOTIFY currentPresetChanged)
    Q_PROPERTY(QStringList availablePresets READ availablePresets CONSTANT)
    Q_PROPERTY(QStringList bandLabels READ bandLabels CONSTANT)

public:
    struct BiquadCoeffs {
        float b0 = 1.0f, b1 = 0.0f, b2 = 0.0f;
        float a1 = 0.0f, a2 = 0.0f;
        float x1_l = 0.0f, x2_l = 0.0f, y1_l = 0.0f, y2_l = 0.0f;
        float x1_r = 0.0f, x2_r = 0.0f, y1_r = 0.0f, y2_r = 0.0f;

        void reset() {
            x1_l = x2_l = y1_l = y2_l = 0.0f;
            x1_r = x2_r = y1_r = y2_r = 0.0f;
        }

        inline void process(float &left, float &right) {
            float out_l = b0 * left + b1 * x1_l + b2 * x2_l - a1 * y1_l - a2 * y2_l;
            x2_l = x1_l; x1_l = left; y2_l = y1_l; y1_l = out_l;
            left = out_l;

            float out_r = b0 * right + b1 * x1_r + b2 * x2_r - a1 * y1_r - a2 * y2_r;
            x2_r = x1_r; x1_r = right; y2_r = y1_r; y1_r = out_r;
            right = out_r;
        }
    };

    explicit EqualizerModel(QObject *parent = nullptr);

    bool isEnabled() const;
    QString currentPreset() const;
    QStringList availablePresets() const;
    QStringList bandLabels() const;

    Q_INVOKABLE float getBandGain(int index) const;
    Q_INVOKABLE void setBandGain(int index, float gainDb);
    Q_INVOKABLE void resetToFlat();

    void setSampleRate(float sampleRate);
    void processStereo(float *left, float *right, int frameCount);

public slots:
    void setIsEnabled(bool enabled);
    void setCurrentPreset(const QString &presetName);

signals:
    void isEnabledChanged();
    void bandGainsChanged();
    void currentPresetChanged();

private:
    void loadSettings();
    void saveSettings();
    void updateCoefficients(int index);
    void updateAllCoefficients();

    bool m_isEnabled = false;
    QVector<float> m_gains;
    QString m_currentPreset = "Flat";
    float m_sampleRate = 44100.0f;
    std::array<BiquadCoeffs, 10> m_filters;
};