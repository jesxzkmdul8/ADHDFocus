// BrownNoiseGenerator
// ===================
// Synthesizes brown (1/f^2) noise on the device instead of streaming it from
// a recorded file. The package therefore does not need to ship a multi-MB
// audio bed for the session's focus phases.
//
// Two classes:
//   - BrownNoiseSource     : a QIODevice that produces samples on demand.
//   - BrownNoiseGenerator  : a QML-friendly QObject that pairs the source
//                            with a QAudioOutput and exposes a `volume`
//                            property + `play()` / `stop()` slots, mirroring
//                            the surface the QML Audio element used to give
//                            us so that the QML Behavior-driven fade still
//                            works unchanged.
//
// Audio format: 22.05 kHz, 16-bit signed PCM, mono, little-endian.
// Brown noise has essentially no energy above ~2 kHz, so 22 kHz of
// bandwidth is comfortable. Mono is sufficient because the signal has no
// inter-channel content. Total bit-rate: ~352 kbit/s of synthesized audio
// data, generated on the fly with negligible CPU cost.

#ifndef BROWNNOISEGENERATOR_H
#define BROWNNOISEGENERATOR_H

#include <QObject>
#include <QIODevice>

class QAudioOutput;

// Produces brown-noise samples into the buffer that QAudioOutput pulls from.
// The algorithm is a leaky integrator: y[n] = a*y[n-1] + b*white[n], which
// gives a 1/f^2 power spectrum and prevents the DC drift a plain integrator
// would accumulate over time.
class BrownNoiseSource : public QIODevice
{
    Q_OBJECT
public:
    explicit BrownNoiseSource(QObject *parent = nullptr);

    // QIODevice contract. We only ever produce samples; writeData is a
    // silent no-op, and bytesAvailable() reports "effectively infinite" so
    // QAudioOutput keeps pulling without ever thinking it has reached EOF.
    qint64 readData(char *data, qint64 maxSize) override;
    qint64 writeData(const char *data, qint64 maxSize) override;
    qint64 bytesAvailable() const override;

private:
    double m_y;  // current integrator state, kept inside [-1, 1]
};

// Public QML-facing component. Registered as a QML type from main.cpp so QML
// can write:
//   import BrownNoise 1.0
//   BrownNoiseGenerator { id: bed; volume: 0.0 }
//
// Behavior on `volume` works because volume is a NOTIFY-able Q_PROPERTY:
// the Behavior intercepts each assignment, drives intermediate values, and
// each step lands in setVolume() which forwards to QAudioOutput::setVolume.
class BrownNoiseGenerator : public QObject
{
    Q_OBJECT
    Q_PROPERTY(qreal volume READ volume WRITE setVolume NOTIFY volumeChanged)
public:
    explicit BrownNoiseGenerator(QObject *parent = nullptr);
    ~BrownNoiseGenerator();

    qreal volume() const;
    void setVolume(qreal v);

    Q_INVOKABLE void play();
    Q_INVOKABLE void stop();

signals:
    void volumeChanged();

private:
    BrownNoiseSource *m_source;
    QAudioOutput *m_output;
};

#endif // BROWNNOISEGENERATOR_H
