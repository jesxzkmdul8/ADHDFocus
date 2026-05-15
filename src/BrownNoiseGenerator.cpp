#include "BrownNoiseGenerator.h"

#include <QAudioFormat>
#include <QAudioDeviceInfo>
#include <QAudioOutput>
#include <QDateTime>
#include <QtGlobal>
#include <limits>

// =========================================================================
// BrownNoiseSource
// =========================================================================

BrownNoiseSource::BrownNoiseSource(QObject *parent)
    : QIODevice(parent), m_y(0.0)
{
    // Seed qrand() once per process. We only need a non-deterministic seed
    // here; the listener can't perceive the difference between two well-
    // shaped 22 kHz noise streams, so a coarse seed is fine.
    static bool seeded = false;
    if (!seeded) {
        qsrand(static_cast<uint>(QDateTime::currentMSecsSinceEpoch() & 0xFFFFFFFFu));
        seeded = true;
    }
}

qint64 BrownNoiseSource::readData(char *data, qint64 maxSize)
{
    // Fill the buffer with as many 16-bit samples as fit. QAudioOutput will
    // call us again as soon as it needs more.
    const qint64 sampleCount = maxSize / static_cast<qint64>(sizeof(qint16));
    qint16 *out = reinterpret_cast<qint16 *>(data);

    // Leaky-integrator brown-noise constants.
    //   decay (a) just under 1 -> 1/f^2 spectrum with no DC drift.
    //   step  (b) controls the bed's loudness at unity output volume.
    // Values chosen empirically to land at a comfortable level when
    // QAudioOutput::volume == 1.0.
    const double decay = 0.99;
    const double step  = 0.05;

    for (qint64 i = 0; i < sampleCount; ++i) {
        const double white = (static_cast<double>(qrand()) / RAND_MAX) * 2.0 - 1.0;
        m_y = decay * m_y + step * white;

        // Belt-and-braces clamp. The leaky integrator on its own keeps |y|
        // well below 1 in the long run; this just guards against arithmetic
        // surprises on the first few samples after a process restart.
        if (m_y > 1.0)      m_y = 1.0;
        else if (m_y < -1.0) m_y = -1.0;

        out[i] = static_cast<qint16>(m_y * std::numeric_limits<qint16>::max());
    }

    return sampleCount * static_cast<qint64>(sizeof(qint16));
}

qint64 BrownNoiseSource::writeData(const char *, qint64)
{
    return 0;  // we are a pure producer
}

qint64 BrownNoiseSource::bytesAvailable() const
{
    // Reporting a huge value keeps QAudioOutput pulling indefinitely.
    return std::numeric_limits<qint64>::max();
}

// =========================================================================
// BrownNoiseGenerator
// =========================================================================

BrownNoiseGenerator::BrownNoiseGenerator(QObject *parent)
    : QObject(parent),
      m_source(new BrownNoiseSource(this)),
      m_output(nullptr)
{
    QAudioFormat fmt;
    fmt.setSampleRate(22050);   // 22.05 kHz: more than enough for brown noise.
    fmt.setChannelCount(1);     // mono: noise has no stereo content.
    fmt.setSampleSize(16);      // 16-bit signed PCM.
    fmt.setCodec(QStringLiteral("audio/pcm"));
    fmt.setByteOrder(QAudioFormat::LittleEndian);
    fmt.setSampleType(QAudioFormat::SignedInt);

    // If the default device doesn't support exactly this format, fall back
    // to its nearest equivalent. On Sailfish (PulseAudio) the requested
    // format is supported as-is, so this is just future-proofing.
    QAudioDeviceInfo info(QAudioDeviceInfo::defaultOutputDevice());
    if (!info.isFormatSupported(fmt)) {
        fmt = info.nearestFormat(fmt);
    }

    m_output = new QAudioOutput(fmt, this);
    m_output->setVolume(0.0);
}

BrownNoiseGenerator::~BrownNoiseGenerator()
{
    if (m_output) {
        m_output->stop();
    }
}

qreal BrownNoiseGenerator::volume() const
{
    return m_output ? m_output->volume() : 0.0;
}

void BrownNoiseGenerator::setVolume(qreal v)
{
    if (!m_output) return;
    if (v < 0.0) v = 0.0;
    if (v > 1.0) v = 1.0;
    m_output->setVolume(v);
    emit volumeChanged();
}

void BrownNoiseGenerator::play()
{
    if (!m_output) return;
    if (m_output->state() == QAudio::ActiveState) return;

    if (!m_source->isOpen()) {
        m_source->open(QIODevice::ReadOnly);
    }
    m_output->start(m_source);
}

void BrownNoiseGenerator::stop()
{
    if (!m_output) return;
    m_output->stop();
}
