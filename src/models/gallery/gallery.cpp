#include "gallery.h"

#include <QFileSystemWatcher>
#include <QDateTime>
#include <QDebug>
#include <QDir>
#include <QTimer>
#include <QThreadPool>
#include <QtConcurrent/QtConcurrent>
#include <QFuture>
#include <QCryptographicHash>
#include <QImageReader>
#include <QStandardPaths>

#include <KLocalizedString>

#include <MauiKit4/FileBrowsing/fileloader.h>
#include <MauiKit4/FileBrowsing/fmstatic.h>
#include <MauiKit4/FileBrowsing/tagging.h>
#include <MauiKit4/ImageTools/exiv2extractor.h>
#include <MauiKit4/ImageTools/textscanner.h>

#include <MauiKit4/ImageTools/cities.h>
#include <MauiKit4/ImageTools/city.h>

#include "pix.h"

static QHash<QString, QString> TextInImages; //[url:text] //global cache of text in images

static QString xdgThumbnailPath(const QUrl &url)
{
    const QByteArray hash = QCryptographicHash::hash(url.toString().toUtf8(), QCryptographicHash::Md5).toHex();
    // Use "large" (256×256) for better quality; "normal" is only 128×128
    return QStandardPaths::writableLocation(QStandardPaths::GenericCacheLocation)
           + QStringLiteral("/thumbnails/large/") + QString::fromLatin1(hash) + QStringLiteral(".png");
}

// Fast path: two stat() calls only, no file open, no decoding.
// Returns the cached thumbnail path if it exists and is newer than the source,
// or an empty string if the thumbnail needs to be (re)generated.
static QString cachedXdgThumbnail(const QUrl &url)
{
    const QFileInfo info(url.toLocalFile());
    if (!info.exists())
        return {};

    const qint64 srcMtime = info.lastModified().toSecsSinceEpoch();
    const QString thumbPath = xdgThumbnailPath(url);
    const QFileInfo thumbInfo(thumbPath);

    if (thumbInfo.exists() && thumbInfo.lastModified().toSecsSinceEpoch() >= srcMtime)
        return QUrl::fromLocalFile(thumbPath).toString();

    return {};
}

// Full generator: returns a valid thumbnail path, generating the file if needed.
// Called only from the background thread pool, never from the file scan path.
static QString ensureXdgThumbnail(const QUrl &url)
{
    const QString localPath = url.toLocalFile();
    const QFileInfo info(localPath);
    if (!info.exists())
        return {};

    const qint64 srcMtime = info.lastModified().toSecsSinceEpoch();
    const QString thumbPath = xdgThumbnailPath(url);
    const QFileInfo thumbInfo(thumbPath);

    // Fast path: already cached
    if (thumbInfo.exists() && thumbInfo.lastModified().toSecsSinceEpoch() >= srcMtime)
        return QUrl::fromLocalFile(thumbPath).toString();

    // Generate thumbnail. QImageReader::setScaledSize triggers JPEG DCT scaling
    // (native 1/2, 1/4, 1/8 decode), so large JPEGs never need a full decode.
    QImageReader reader(localPath);
    if (!reader.canRead())
        return {};

    const QSize sz = reader.size();
    if (!sz.isValid())
        return {};

    reader.setScaledSize(sz.scaled(256, 256, Qt::KeepAspectRatio));

    QImage thumb = reader.read();
    if (thumb.isNull())
        return {};

    thumb.setText(QStringLiteral("Thumb::URI"), url.toString());
    thumb.setText(QStringLiteral("Thumb::MTime"), QString::number(srcMtime));

    QDir().mkpath(QFileInfo(thumbPath).absolutePath());

    // Atomic write: write to a temp file then rename so a partial write is never visible
    const QString tmpPath = thumbPath + QStringLiteral(".tmp");
    if (thumb.save(tmpPath, "PNG"))
    {
        QFile::remove(thumbPath);
        if (QFile::rename(tmpPath, thumbPath))
            return QUrl::fromLocalFile(thumbPath).toString();
        QFile::remove(tmpPath);
    }

    return {};
}

static FMH::MODEL picInfo(const QUrl &url)
{
    const QFileInfo info(url.toLocalFile());
    // Use the fast cache-only check here. If no valid thumbnail exists yet the
    // field is left empty and Gallery::scheduleThumbnails() will generate it in
    // the background thread pool without blocking the file scan.
    return FMH::MODEL{{FMH::MODEL_KEY::URL, url.toString()},
                      {FMH::MODEL_KEY::THUMBNAIL, cachedXdgThumbnail(url)},
                      {FMH::MODEL_KEY::TITLE, info.fileName()},
                      {FMH::MODEL_KEY::SIZE, QString::number(info.size())},
                      {FMH::MODEL_KEY::SOURCE, QUrl::fromLocalFile(info.absoluteDir().absolutePath()).toString ()},
                      {FMH::MODEL_KEY::DATE, info.birthTime(QTimeZone::UTC).toString(Qt::TextDate)},
                      {FMH::MODEL_KEY::MODIFIED, info.lastModified(QTimeZone::UTC).toString(Qt::TextDate)},
                      {FMH::MODEL_KEY::FORMAT, info.completeSuffix()}};
}

Gallery::Gallery(QObject *parent)
    : MauiList(parent)
    , m_fileLoader(new FMH::FileLoader(this))
    , m_watcher(new QFileSystemWatcher(this))
    , m_futureWatcher(nullptr)
    , m_thumbPool(new QThreadPool(this))
    , m_scanTimer(new QTimer(this))
    , m_autoReload(true)
    , m_recursive(true)
{
    qDebug() << "CREATING GALLERY LIST";
    // Limit concurrency so thumbnail generation doesn't spike memory.
    // Two threads: one is usually decoding a source image, the other is saving.
    m_thumbPool->setMaxThreadCount(2);
    m_scanTimer->setSingleShot(true);
    m_scanTimer->setInterval(2000); // 2 s debounce: coalesces rapid filesystem events without feeling sluggish
}

Gallery::~Gallery()
{
    // Increment generation so any running thumbnail tasks see a stale gen and
    // return without touching 'this'. Then drain the queue (clear = remove
    // not-yet-started tasks) and wait for the at-most-2 running tasks to exit.
    ++m_generation;
    m_thumbPool->clear();
    m_thumbPool->waitForDone();

    if(m_futureWatcher)
    {
        m_futureWatcher->cancel();
        m_futureWatcher->waitForFinished();
        delete m_futureWatcher;
        m_futureWatcher = nullptr;
    }
}

const FMH::MODEL_LIST &Gallery::items() const
{
    return this->list;
}

void Gallery::setUrls(const QList<QUrl> &urls)
{
    qDebug() << "setting urls" << this->m_urls << urls;

    if(this->m_urls == urls)
        return;

    this->m_urls = urls;
    Q_EMIT this->urlsChanged();
}

QList<QUrl> Gallery::urls() const
{
    return m_urls;
}

void Gallery::setAutoReload(const bool &value)
{
    if (m_autoReload == value)
        return;

    m_autoReload = value;
    Q_EMIT autoReloadChanged();
}

bool Gallery::autoReload() const
{
    return m_autoReload;
}

QList<QUrl> Gallery::folders() const
{
    return m_folders;
}

bool Gallery::recursive() const
{
    return m_recursive;
}

int Gallery::limit() const
{
    return m_limit;
}

QStringList Gallery::files() const
{
    return FMH::modelToList(this->list, FMH::MODEL_KEY::URL);
}

void Gallery::scan(const QList<QUrl> &urls, const bool &recursive, const int &limit)
{
    if(m_urls.isEmpty())
    {
        this->setStatus(Status::Error, i18n("No sources found to scan."));
        return;
    }

    this->setStatus(Status::Loading);
    for(const auto &url : urls)
    {
        if(url.scheme() == "gps")
        {
            const auto gpsId = url.toString().replace("gps:///", "");
            qDebug() << "Collection images from GPS Tags" << gpsId;

            FMH::MODEL_LIST images;
            const auto urls = GpsImages::getInstance()->urls(gpsId);
            for (const auto &url : urls)
            {
                images << picInfo(url);
            }

            Q_EMIT preItemsAppended(images.size());
            this->list << images;
            Q_EMIT postItemAppended();
            Q_EMIT this->countChanged();
        }
    }

    m_fileLoader->requestPath(urls, recursive, QStringList() << FMStatic::FILTER_LIST[FMStatic::FILTER_TYPE::IMAGE], QDir::Files, limit);
}

QString getCityId(const QUrl &url)
{
    const Exiv2Extractor exiv2(url);
    QString cityId = exiv2.cityId();
    return cityId;
}

void Gallery::scanGpsTags()
{
    auto functor = [](FMH::MODEL &item)
    {
        auto url = QUrl::fromUserInput(item[FMH::MODEL_KEY::URL]);

        if(!url.isValid())
            return;

        QString cityId;
        const auto urlId = url.toString();

        if(GpsImages::getInstance()->contains(urlId))
        {
            cityId = GpsImages::getInstance()->gpsTag(urlId);
        }else
        {
            qDebug() << "CREATING A NEW CITY";
            cityId = getCityId(url);
            if(!cityId.isEmpty())
            {
                GpsImages::getInstance()->insert(urlId, cityId);
            }
        }
        if(!cityId.isEmpty())
            item[FMH::MODEL_KEY::CITY] = cityId;
    };

    if (m_futureWatcher)
    {
        m_futureWatcher->cancel();
        m_futureWatcher->deleteLater();
    }
    m_futureWatcher = new QFutureWatcher<void>;
    auto future = QtConcurrent::map(list, functor);
    m_futureWatcher->setFuture(future);

    connect(m_futureWatcher, &QFutureWatcher<void>::finished, [this]()
            {
                qDebug() << "FINISHED SCANNING GPS TAGS" << GpsImages::getInstance()->values();
                setCitiesModel();
            });
}

void Gallery::insertFolder(const QUrl &path)
{
    if (!m_folders.contains(path)) {
        m_folders << path;

        if (m_autoReload) {
            this->m_watcher->addPath(path.toLocalFile());
        }
    }
}

void Gallery::insertCity(const QString & cityId)
{
    if (!m_cities.contains(cityId) && !cityId.isEmpty ()) {

        qDebug() << "FOUND CITY <<" << cityId;
        m_cities << cityId;
    }
}

void Gallery::setCitiesModel()
{
    m_cities.clear();

    for(const auto &url : files())
    {
        if(m_activeGeolocationTags && GpsImages::getInstance()->contains(url))
        {
            this->insertCity( GpsImages::getInstance()->gpsTag(url));
        }
    }

    // for(const auto &city : GpsImages::getInstance()->cities())
    // {
    //     if(m_activeGeolocationTags && m_urls(GpsImages::getInstance()->urls(city)))
    //     {
    //         this->insertCity(city);
    //     }
    // }

    Q_EMIT citiesChanged();
}

void Gallery::setStatus(const Gallery::Status &status, const QString &error)
{
    qDebug() << "Setting up status" << status;
    this->m_status = status;
    Q_EMIT this->statusChanged();

    if(error != m_error)
    {
        this->m_error = error;
        Q_EMIT this->errorChanged(m_error);
    }
}

bool Gallery::remove(const int &index)
{
    Q_UNUSED(index)
    return false;
}

bool Gallery::deleteAt(const int &index)
{
    if (index >= this->list.size() || index < 0)
        return false;

    const auto index_ = index;

    Q_EMIT this->preItemRemoved(index_);
    auto item = this->list.takeAt(index_);
    FMStatic::removeFiles({item[FMH::MODEL_KEY::URL]});
    Q_EMIT this->postItemRemoved();

    return true;
}

void Gallery::removeFiles(const QStringList &urls)
{
    for (const auto &url : urls)
    {
        const auto index = this->indexOf(FMH::MODEL_KEY::URL, url);
        deleteAt(index);
    }
}

void Gallery::append(const QVariantMap &pic)
{
    Q_EMIT this->preItemAppended();
    this->list << FMH::toModel(pic);
    Q_EMIT this->postItemAppended();
}

void Gallery::append(const QString &url)
{
    Q_EMIT this->preItemAppended();
    this->list << picInfo(QUrl::fromUserInput(url));
    Q_EMIT this->postItemAppended();
}

void Gallery::clear()
{
    m_scanTimer->stop();

    // Invalidate all in-flight thumbnail tasks from the previous scan generation.
    // clear() removes queued (not yet started) tasks; the at-most-2 running tasks
    // will see the new generation value and exit without modifying the list.
    ++m_generation;
    m_thumbPool->clear();

    const auto watchedDirs = m_watcher->directories();
    if (!watchedDirs.isEmpty())
        m_watcher->removePaths(watchedDirs);
    const auto watchedFiles = m_watcher->files();
    if (!watchedFiles.isEmpty())
        m_watcher->removePaths(watchedFiles);

    Q_EMIT this->preListChanged();
    this->list.clear();
    Q_EMIT this->postListChanged();

    this->m_folders.clear();
    this->m_cities.clear();

    // GpsImages::getInstance()->clear();

    Q_EMIT citiesChanged();
    Q_EMIT foldersChanged();
    Q_EMIT filesChanged();
}

void Gallery::rescan()
{
    this->clear();
    this->load();
}

void Gallery::load()
{
    this->scan(m_urls, m_recursive, m_limit);
}

void Gallery::setRecursive(bool recursive)
{
    if (m_recursive == recursive)
        return;

    m_recursive = recursive;
    Q_EMIT recursiveChanged(m_recursive);
}

void Gallery::setlimit(int limit)
{
    if (m_limit == limit)
        return;

    m_limit = limit;
    Q_EMIT limitChanged(m_limit);
}

int Gallery::indexOfName(const QString &query)
{
    const auto it = std::find_if(this->items().constBegin(), this->items().constEnd(), [&](const FMH::MODEL &item) -> bool {
        return item[FMH::MODEL_KEY::TITLE].startsWith(query, Qt::CaseInsensitive);
    });

    if (it != this->items().constEnd())
        return (std::distance(this->items().constBegin(), it));
    else
        return -1;
}

void Gallery::setActiveGeolocationTags(bool activeGeolocationTags)
{
    if (m_activeGeolocationTags == activeGeolocationTags)
        return;

    m_activeGeolocationTags = activeGeolocationTags;
    Q_EMIT activeGeolocationTagsChanged(m_activeGeolocationTags);
}

void Gallery::reloadGpsTags()
{
    GpsImages::getInstance()->clear();
    if(m_activeGeolocationTags)
        scanGpsTags();
}

void Gallery::updateGpsTag(const QString &url)
{
    if(GpsImages::getInstance()->contains(url))
    {
       if(GpsImages::getInstance()->remove(url))
        {
            auto cityId = getCityId(QUrl::fromLocalFile(url));
            if(!cityId.isEmpty())
            {
                GpsImages::getInstance()->insert(url, cityId);
                setCitiesModel();
            }
       }
    }
}

void Gallery::scheduleThumbnails(const FMH::MODEL_LIST &newItems, int startIndex)
{
    const quint64 gen = m_generation.load(std::memory_order_relaxed);

    for (int i = 0; i < newItems.size(); ++i)
    {
        if (!newItems[i][FMH::MODEL_KEY::THUMBNAIL].isEmpty())
            continue; // Already cached — nothing to do

        const int listIndex = startIndex + i;
        const QString urlStr = newItems[i][FMH::MODEL_KEY::URL];

        m_thumbPool->start([this, urlStr, listIndex, gen]()
        {
            if (m_generation.load(std::memory_order_relaxed) != gen)
                return;

            const QString thumb = ensureXdgThumbnail(QUrl(urlStr));

            if (thumb.isEmpty() || m_generation.load(std::memory_order_relaxed) != gen)
                return;

            // Post the model update back to the main thread.
            // Qt automatically removes all posted events for a QObject when it is
            // destroyed, so this is safe even if Gallery is deleted first.
            QMetaObject::invokeMethod(this, [this, urlStr, listIndex, thumb, gen]()
            {
                if (m_generation.load(std::memory_order_relaxed) != gen)
                    return;
                if (listIndex < 0 || listIndex >= list.size())
                    return;
                // Verify the item at listIndex is still the one we generated for
                if (list[listIndex][FMH::MODEL_KEY::URL] != urlStr)
                    return;

                list[listIndex][FMH::MODEL_KEY::THUMBNAIL] = thumb;
                this->updateModel(listIndex, {FMH::MODEL_KEY::THUMBNAIL});
            }, Qt::QueuedConnection);
        });
    }
}

void Gallery::componentComplete()
{
    connect(m_fileLoader, &FMH::FileLoader::finished, [this](FMH::MODEL_LIST items) {
        Q_UNUSED(items)

        Q_EMIT this->filesChanged();
        Q_EMIT this->foldersChanged();

        if(m_activeGeolocationTags)
        {
            scanGpsTags();
        }

        this->setStatus(Status::Ready);
    });

    connect(m_fileLoader, &FMH::FileLoader::itemsReady, [this](FMH::MODEL_LIST items) {
        qDebug() << "Items ready" << items.size();

        if (items.isEmpty())
            return;

        const int startIndex = this->list.size();
        Q_EMIT preItemsAppended(items.size());
        this->list << items;
        Q_EMIT postItemAppended();
        Q_EMIT this->countChanged();

        // Queue thumbnail generation for any items whose thumbnails weren't cached.
        // This runs after the UI is already showing the scan results, so it doesn't
        // block first paint. Thumbnails appear progressively as they're generated.
        scheduleThumbnails(items, startIndex);
    });

    connect(m_fileLoader, &FMH::FileLoader::itemReady, [this](FMH::MODEL item) {
        this->insertFolder(item[FMH::MODEL_KEY::SOURCE]);
    });

    connect(m_watcher, &QFileSystemWatcher::directoryChanged, [this](QString dir) {
        qDebug() << "Dir changed" << dir;
        this->m_scanTimer->start();
    });

    connect(m_scanTimer, &QTimer::timeout, [this]() {
        this->rescan();
    });

    connect(this, &Gallery::urlsChanged, this, &Gallery::rescan);
    connect(this, &Gallery::activeGeolocationTagsChanged, [this](bool state)
            {
                if(state)
                {
                    this->scanGpsTags(); //TODO change to scanGpsTags
                }
            });

    m_fileLoader->setBatchCount(500);
    m_fileLoader->informer = &picInfo;

    this->load();
}

const QStringList &Gallery::cities() const
{
    return m_cities;
}

Gallery::Status Gallery::status() const
{
    return m_status;
}

QString Gallery::error() const
{
    return m_error;
}

bool Gallery::activeGeolocationTags() const
{
    return m_activeGeolocationTags;
}

void Gallery::scanImagesText()
{
    TextScanner scanner;
    int i = 0;

    for(auto &item : this->list)
    {
        if(!QString(item[FMH::MODEL_KEY::CONTEXT]).isEmpty())
        {
            qDebug() << "EXISTING TEXT" << item[FMH::MODEL_KEY::CONTEXT];
            continue;
        }

        QString text;
        QString url = item[FMH::MODEL_KEY::URL];

        if(TextInImages.contains(url))
        {
            text = TextInImages.value(url);
        }else
        {
            scanner.setUrl(url);
            text = scanner.getText();
            TextInImages.insert(url, text);
        }

        item[FMH::MODEL_KEY::CONTEXT] = text.isEmpty() ? "---" : text;
        qDebug() << "FOUND TEXT" << item[FMH::MODEL_KEY::CONTEXT];

        this->updateModel(i, {FMH::MODEL_KEY::CONTEXT});
        i++;
    }
}

QVariantMap Gallery::getFolderInfo(const QUrl &url)
{
    if(url.scheme() == "gps")
    {
        const auto id = url.toString().replace("gps:///", "");

        City city = Cities::getInstance()->city(id);
        return QVariantMap {{"label", QString(city.name() + " - " + city.country())}, {"icon", "gps"}, {"url", url.toString()}};
    }

    return FMStatic::getFileInfo(url);
}

Q_GLOBAL_STATIC(GpsImages, gpsInstance)
GpsImages *GpsImages::getInstance()
{
    return gpsInstance();

}

GpsImages::GpsImages() : QObject()
{
    connect(qApp, &QCoreApplication::aboutToQuit, [this]()
            {
                qDebug() << "Lets remove Tagging singleton instance and all opened Tagging DB connections.";
                this->deleteLater();
            });
}

GpsHash GpsImages::data() const
{
    return m_data;
}

QList<QString> GpsImages::cities() const
{
    auto data = m_data.values();
    data.removeDuplicates();
    return data;
}

void GpsImages::insert(const QString &url, const QString &gpsId)
{
    m_data.insert(url, gpsId);
}

QStringList GpsImages::urls(const QString &gpsId)
{
    QStringList res;
    for (auto i = m_data.constBegin(), end = m_data.constEnd(); i != end; ++i)
    {
        if(i.value() == gpsId)
        {
            res << i.key();
        }
    }

    return res;
}

QString GpsImages::gpsTag(const QString &url)
{
    if(m_data.contains(url))
    {
        return m_data.value(url);
    }

    return QString();
}

bool GpsImages::contains(const QString &url)
{
    return m_data.contains(url);
}

void GpsImages::clear()
{
    m_data.clear();
}

bool GpsImages::remove(const QString &url)
{
    return m_data.remove(url);
}

QStringList GpsImages::values()
{
    return m_data.values();
}
