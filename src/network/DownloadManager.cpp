#include "DownloadManager.h"
#include <QStandardPaths>
#include <QDir>
#include <QDesktopServices>
#include <QUrl>
#include <QRegularExpression>
#include <QProcess>
#include <QCoreApplication>
#include <QFileInfo>
#include <QDebug>

DownloadManager::DownloadManager(QObject *parent)
    : QObject(parent)
    , m_networkManager(new QNetworkAccessManager(this))
    , m_isDownloading(false)
    , m_showDownloadBar(false)
    , m_progressPercent(0)
    , m_currentReply(nullptr)
    , m_outputFile(nullptr)
    , m_autoHideTimer(nullptr) {
}

bool DownloadManager::isDownloading() const {
    return m_isDownloading;
}

bool DownloadManager::showDownloadBar() const {
    return m_showDownloadBar;
}

int DownloadManager::progressPercent() const {
    return m_progressPercent;
}

QString DownloadManager::statusMessage() const {
    return m_statusMessage;
}

void DownloadManager::dismissDownloadBar() {
    if (m_showDownloadBar) {
        m_showDownloadBar = false;
        emit showDownloadBarChanged(false);
    }
}

void DownloadManager::openDownloadFolder() {
    QString musicPath = QStandardPaths::writableLocation(QStandardPaths::MusicLocation);
    QDesktopServices::openUrl(QUrl::fromLocalFile(musicPath));
}

void DownloadManager::startDownload(const QString &mediaUrl, const QString &saveFileName) {
    if (m_isDownloading || mediaUrl.isEmpty()) {
        qDebug() << "[DownloadManager] Ignored: Already downloading or URL is empty.";
        return;
    }


    static const QRegularExpression illegalCharsRx(R"([\\/:*?"<>|])");
    QString sanitizedFileName = saveFileName;
    sanitizedFileName.remove(illegalCharsRx);
    if (sanitizedFileName.trimmed().isEmpty()) {
        sanitizedFileName = "Downloaded_Track";
    }
    if (sanitizedFileName.endsWith(".mp3", Qt::CaseInsensitive)) {
        sanitizedFileName.chop(4);
    }

    QString musicPath = QStandardPaths::writableLocation(QStandardPaths::MusicLocation);
    QDir().mkpath(musicPath);

    m_savePath = musicPath + "/" + sanitizedFileName + ".mp3";

    m_isDownloading = true;
    m_showDownloadBar = true;
    m_progressPercent = 0;
    m_statusMessage = "Starting download: " + sanitizedFileName + ".mp3";

    emit downloadingChanged(true);
    emit showDownloadBarChanged(true);
    emit progressChanged(0);
    emit statusMessageChanged(m_statusMessage);


    if (mediaUrl.startsWith("http") && mediaUrl.contains(".mp3") && !mediaUrl.contains(".m3u8")) {
        if (m_outputFile) {
            if (m_outputFile->isOpen()) m_outputFile->close();
            delete m_outputFile;
            m_outputFile = nullptr;
        }

        m_outputFile = new QFile(m_savePath, this);
        if (!m_outputFile->open(QIODevice::WriteOnly)) {
            m_statusMessage = "Could not create destination file.";
            emit statusMessageChanged(m_statusMessage);
            emit downloadFailed(m_statusMessage);
            delete m_outputFile;
            m_outputFile = nullptr;
            m_isDownloading = false;
            emit downloadingChanged(false);
            return;
        }

        QUrl url(mediaUrl);
        QNetworkRequest request(url);
        request.setHeader(QNetworkRequest::UserAgentHeader, "Mozilla/5.0 (Windows NT 10.0; Win64; x64)");
        request.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);

        m_currentReply = m_networkManager->get(request);

        connect(m_currentReply, &QNetworkReply::downloadProgress, this, &DownloadManager::onDownloadProgress);
        connect(m_currentReply, &QNetworkReply::readyRead, this, &DownloadManager::onReadyRead);
        connect(m_currentReply, &QNetworkReply::finished, this, &DownloadManager::onDownloadFinished);
        return;
    }


    QString appDir = QCoreApplication::applicationDirPath();
    QString ytDlpPath = QDir(appDir).filePath("yt-dlp.exe");
    if (!QFile::exists(ytDlpPath)) {
        ytDlpPath = "yt-dlp";
    }

    auto *process = new QProcess(this);
    QStringList args;
    args << mediaUrl
         << "-o" << (musicPath + "/" + sanitizedFileName + ".%(ext)s")
         << "-x"
         << "--audio-format" << "mp3"
         << "--audio-quality" << "0"
         << "--no-warnings"
         << "--newline";

    connect(process, &QProcess::readyReadStandardOutput, this, [this, process]() {
        QString out = QString::fromUtf8(process->readAllStandardOutput());
        static const QRegularExpression progRx(R"(\[\s*download\s*\]\s+([\d\.]+)%)");
        QRegularExpressionMatch match = progRx.match(out);
        if (match.hasMatch()) {
            int percent = static_cast<int>(match.captured(1).toDouble());
            if (percent != m_progressPercent) {
                m_progressPercent = percent;
                m_statusMessage = QString("Downloading Track (%1%)").arg(percent);
                emit progressChanged(m_progressPercent);
                emit statusMessageChanged(m_statusMessage);
            }
        }
    });

    connect(process, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished), this, [this, process](int exitCode, QProcess::ExitStatus) {
        m_isDownloading = false;
        emit downloadingChanged(false);

        if (exitCode == 0) {
            m_progressPercent = 100;
            emit progressChanged(100);
            m_statusMessage = "Download Complete! Saved to your Music library.";
            emit statusMessageChanged(m_statusMessage);
            emit downloadCompleted(m_savePath);
        } else {
            m_statusMessage = "Download error occurred.";
            emit statusMessageChanged(m_statusMessage);
            emit downloadFailed(m_statusMessage);
            QFile::remove(m_savePath);
        }
        process->deleteLater();
    });

    process->start(ytDlpPath, args);
    process->closeWriteChannel();
}

void DownloadManager::cancelDownload() {
    if (m_currentReply && m_isDownloading) {
        m_currentReply->abort();
    }
    if (m_outputFile) {
        if (m_outputFile->isOpen()) m_outputFile->close();
        delete m_outputFile;
        m_outputFile = nullptr;
    }
    QFile::remove(m_savePath);
    m_isDownloading = false;
    emit downloadingChanged(false);
    dismissDownloadBar();
}

void DownloadManager::onDownloadProgress(qint64 bytesReceived, qint64 bytesTotal) {
    if (bytesTotal > 0) {
        int percent = static_cast<int>((bytesReceived * 100) / bytesTotal);
        if (percent != m_progressPercent) {
            m_progressPercent = percent;
            m_statusMessage = QString("Downloading Track (%1%)").arg(percent);
            emit progressChanged(m_progressPercent);
            emit statusMessageChanged(m_statusMessage);
        }
    }
}

void DownloadManager::onReadyRead() {
    if (m_outputFile && m_currentReply) {
        m_outputFile->write(m_currentReply->readAll());
    }
}

void DownloadManager::onDownloadFinished() {
    m_isDownloading = false;
    emit downloadingChanged(false);

    if (m_outputFile) {
        m_outputFile->flush();
        m_outputFile->close();
        delete m_outputFile;
        m_outputFile = nullptr;
    }

    if (!m_currentReply) return;

    if (m_currentReply->error() == QNetworkReply::NoError) {
        m_progressPercent = 100;
        emit progressChanged(100);
        m_statusMessage = "Download Complete! Saved to your Music library.";
        emit statusMessageChanged(m_statusMessage);
        emit downloadCompleted(m_savePath);
    } else if (m_currentReply->error() != QNetworkReply::OperationCanceledError) {
        m_statusMessage = "Download failed: " + m_currentReply->errorString();
        emit statusMessageChanged(m_statusMessage);
        emit downloadFailed(m_statusMessage);
        QFile::remove(m_savePath);
    } else {
        QFile::remove(m_savePath);
    }

    m_currentReply->deleteLater();
    m_currentReply = nullptr;
}