#pragma once

#include <QObject>
#include <QString>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QFile>
#include <QTimer>

class DownloadManager : public QObject {
    Q_OBJECT

    Q_PROPERTY(bool isDownloading READ isDownloading NOTIFY downloadingChanged)
    Q_PROPERTY(bool showDownloadBar READ showDownloadBar NOTIFY showDownloadBarChanged)
    Q_PROPERTY(int progressPercent READ progressPercent NOTIFY progressChanged)
    Q_PROPERTY(QString statusMessage READ statusMessage NOTIFY statusMessageChanged)

public:
    explicit DownloadManager(QObject *parent = nullptr);
    ~DownloadManager() override = default;

    bool isDownloading() const;
    bool showDownloadBar() const;
    int progressPercent() const;
    QString statusMessage() const;

public slots:
    void startDownload(const QString &mediaUrl, const QString &saveFileName);
    void cancelDownload();
    void dismissDownloadBar();
    void openDownloadFolder();

    signals:
        void downloadingChanged(bool downloading);
    void showDownloadBarChanged(bool show);
    void progressChanged(int percent);
    void statusMessageChanged(const QString &message);
    void downloadCompleted(const QString &filePath);
    void downloadFailed(const QString &error);

private slots:
    void onDownloadProgress(qint64 bytesReceived, qint64 bytesTotal);
    void onReadyRead();
    void onDownloadFinished();

private:
    QNetworkAccessManager *m_networkManager;
    QNetworkReply *m_currentReply = nullptr;
    QFile *m_outputFile = nullptr;
    QTimer *m_autoHideTimer;

    bool m_isDownloading = false;
    bool m_showDownloadBar = false;
    int m_progressPercent = 0;
    QString m_statusMessage;
    QString m_savePath;
};