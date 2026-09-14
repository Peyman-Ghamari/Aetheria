#pragma once

#include <QAbstractListModel>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QList>
#include <QString>
#include <QVariantList>
#include <QProcess>
#include <QPointer>
#include <atomic>

struct OnlineTrack {
    QString title;
    QString artist;
    QString streamUrl;
    QString coverUrl;
    QString duration;
    QString playCount;
};

class OnlineSearchEngine : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(bool isSearching READ isSearching NOTIFY searchingChanged)
    Q_PROPERTY(QString statusText READ statusText NOTIFY statusTextChanged)
    Q_PROPERTY(QString audioQuality READ audioQuality WRITE setAudioQuality NOTIFY audioQualityChanged)
    Q_PROPERTY(QVariantList chartTracks READ chartTracks NOTIFY chartTracksChanged)
    Q_PROPERTY(bool isLoadingCharts READ isLoadingCharts NOTIFY loadingChartsChanged)

public:
    enum OnlineTrackRoles {
        TitleRole = Qt::UserRole + 1,
        ArtistRole,
        StreamUrlRole,
        CoverUrlRole,
        DurationRole,
        PlayCountRole
    };

    explicit OnlineSearchEngine(QObject *parent = nullptr);
    ~OnlineSearchEngine() override;

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    bool isSearching() const;
    QString statusText() const;
    QString audioQuality() const;
    void setAudioQuality(const QString &quality);

    QVariantList chartTracks() const;
    bool isLoadingCharts() const;

    quint64 activePlaybackToken() const { return m_activePlaybackToken; }
    void registerActiveProcess(QProcess *proc);
    void registerActiveReply(QNetworkReply *reply);

    Q_INVOKABLE void searchOnline(const QString &query);
    Q_INVOKABLE void fetchTopCharts();
    Q_INVOKABLE void resolveAndPlay(const QString &title, const QString &artist, const QString &coverUrl);
    Q_INVOKABLE void resolveAndDownload(const QString &title, const QString &artist, const QString &coverUrl);
    Q_INVOKABLE void clear();
    Q_INVOKABLE void checkForYtDlpUpdate();

signals:
    void searchingChanged(bool isSearching);
    void statusTextChanged(const QString &statusText);
    void audioQualityChanged(const QString &audioQuality);
    void chartTracksChanged();
    void loadingChartsChanged(bool isLoading);
    void fullTrackResolved(const QString &streamUrl, const QString &title, const QString &artist, const QString &coverUrl, bool isDownload);

private slots:
    void onSearchResultsReceived();

private:
    void resolveInternal(const QString &title, const QString &artist, const QString &coverUrl, bool isDownload);
    void performYtDlpUpdate();
    void abortActiveResolution();

    QList<OnlineTrack> m_results;
    QVariantList m_chartTracks;
    bool m_isLoadingCharts = false;

    QNetworkAccessManager *m_networkManager;
    QNetworkReply *m_currentReply = nullptr;
    bool m_isSearching = false;
    QString m_statusText;
    QString m_audioQuality = "HQ 320K";
    std::atomic<bool> m_isUpdatingYtDlp{false};


    quint64 m_activePlaybackToken = 0;
    QPointer<QProcess> m_activeYtProcess;
    QPointer<QNetworkReply> m_activeResolveReply;
};