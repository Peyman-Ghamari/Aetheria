#pragma once

#include <QAbstractListModel>
#include <QNetworkAccessManager>
#include <QSqlDatabase>
#include <QStringList>
#include <QVariantMap>
#include <QVariantList>
#include <QVector>

struct LocalTrack {
    int id = 0;
    QString title;
    QString artist;
    QString album;
    QString filePath;
    QString duration;
    QString coverPath;
    bool isLiked = false;
    qint64 likedAt = 0;
    qint64 lastModified = 0;
};

class TrackModel : public QAbstractListModel {
    Q_OBJECT

    Q_PROPERTY(int count READ count NOTIFY countChanged)
    Q_PROPERTY(int currentIndex READ currentIndex WRITE setCurrentIndex NOTIFY currentIndexChanged)
    Q_PROPERTY(QString filterText READ filterText WRITE setFilterText NOTIFY filterTextChanged)
    Q_PROPERTY(bool showOnlyLiked READ showOnlyLiked WRITE setShowOnlyLiked NOTIFY showOnlyLikedChanged)
    Q_PROPERTY(QString currentPlaylist READ currentPlaylist WRITE setCurrentPlaylist NOTIFY currentPlaylistChanged)
    Q_PROPERTY(QStringList playlistNames READ playlistNames NOTIFY playlistNamesChanged)
    Q_PROPERTY(QString lastSelectedFolder READ lastSelectedFolder WRITE setLastSelectedFolder NOTIFY lastSelectedFolderChanged)

public:
    enum TrackRoles {
        IdRole = Qt::UserRole + 1,
        TitleRole,
        ArtistRole,
        AlbumRole,
        FilePathRole,
        DurationRole,
        CoverPathRole,
        IsLikedRole,
        LikedAtRole
    };
    Q_ENUM(TrackRoles)

    explicit TrackModel(QObject *parent = nullptr);
    ~TrackModel() override = default;

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    int count() const;
    int currentIndex() const;

    QString filterText() const;
    void setFilterText(const QString &filter);

    bool showOnlyLiked() const;
    void setShowOnlyLiked(bool onlyLiked);

    QString currentPlaylist() const;
    void setCurrentPlaylist(const QString &playlist);

    QStringList playlistNames() const;

public slots:
    void setCurrentIndex(int index);
    void scanDirectory(const QUrl &folderUrl);
    void playNext();
    void playPrevious();
    void playNextTrack(bool isShuffle);
    void toggleLike(int index);
    void toggleLikeByPath(const QString &filePath);
    bool isTrackLiked(const QString &filePath) const;
    QVariantMap getTrackAt(int index) const;
    QVariantList getAllTracks() const;
    void clear();
    Q_INVOKABLE void saveLyricsToDb(const QString &filePath, const QString &lyrics);
    Q_INVOKABLE QString getCachedLyricsFromDb(const QString &filePath);

    bool updateTrackMetadata(const QString &filePath, const QString &newTitle, const QString &newArtist, const QString &newAlbum = "");

    void createNewPlaylist(const QString &name);
    void removePlaylist(const QString &name);
    void addToPlaylist(const QString &playlistName, const QString &filePath);
    void addMultipleToPlaylist(const QString &playlistName, const QVariantList &filePaths);
    void removeFromPlaylist(const QString &playlistName, const QString &filePath);
    void deleteTrackFromLibrary(int index);
    void playExternalFile(const QString &filePath);
    QString lastSelectedFolder() const;
    void setLastSelectedFolder(const QString &folder);


signals:
    void countChanged();
    void currentIndexChanged(int index);
    void filterTextChanged();
    void showOnlyLikedChanged();
    void currentPlaylistChanged();
    void playlistNamesChanged();
    void trackSelected(const QString &title, const QString &artist, const QString &filePath, const QString &coverPath);
    void coverUpdated(const QString &filePath, const QString &newCoverPath);
    void likeStatusChanged(const QString &filePath, bool isLiked);
    void lastSelectedFolderChanged();

private:
    void initDatabase();
    void loadTracksFromDatabase();
    void validateDatabaseEntriesAsync();
    void applyFilter();
    void parseFileMetaData(const QString &filePath, LocalTrack &track);
    void fetchMissingCover(const QString &filePath, const QString &title, const QString &artist);
    QString findLocalFolderCover(const QString &filePath);
    void updateCoverInDb(const QString &filePath, const QString &coverPath);

    QSqlDatabase m_db;
    QNetworkAccessManager *m_networkManager;
    QVector<LocalTrack> m_allTracks;
    QVector<LocalTrack> m_filteredTracks;
    int m_currentIndex = -1;
    QString m_filterText;
    bool m_showOnlyLiked = false;
    QString m_currentPlaylist = "";
};