import AVFoundation

enum SoundManager {

    static var settings: AppSettingsStore?

    private static var player: AVAudioPlayer?

    // Keep a strong reference so the engine isn't deallocated mid-playback
    private static var chimeEngine: AVAudioEngine?
    private static var chimeNode: AVAudioPlayerNode?

    static func play(_ name: String) {
        guard settings?.soundsEnabled ?? true else { return }
        guard let url = Bundle.main.url(forResource: name, withExtension: "mp3") else { return }
        player = try? AVAudioPlayer(contentsOf: url)
        player?.play()
    }

    static func start()   { play("start") }
    static func tap()     { play("tap") }
    static func success() { play("success") }
    static func error()   { play("error") }
    static func pause()   { play("pause") }

    // MARK: - Session chimes

    /// Deep, warm bowl strike — focus block complete.
    /// Low fundamental, long ring, invites rest.
    static func focusComplete() {
        guard settings?.soundsEnabled ?? true else { return }
        playBell(
            fundamental: 432,
            partials: [
                // (frequency ratio, relative amplitude, decay multiplier)
                (1.000, 1.00, 1.0),   // fundamental — longest sustain
                (2.756, 0.35, 2.8),   // inharmonic 1st overtone (real bowl ratio)
                (5.404, 0.18, 5.5),   // inharmonic 2nd overtone
                (8.933, 0.08, 10.0),  // high shimmer, fades very fast
            ],
            duration: 3.0,
            amplitude: 0.52
        )
    }

    /// Brighter, shorter bowl — break complete, refocus.
    static func breakComplete() {
        guard settings?.soundsEnabled ?? true else { return }
        playBell(
            fundamental: 528,
            partials: [
                (1.000, 1.00, 1.0),
                (2.756, 0.30, 3.2),
                (5.404, 0.14, 6.0),
                (8.933, 0.06, 11.0),
            ],
            duration: 2.2,
            amplitude: 0.46
        )
    }

    // MARK: - Synthesis

    private static func playBell(
        fundamental: Float,
        partials: [(ratio: Float, amp: Float, decayMul: Float)],
        duration: Float,
        amplitude: Float
    ) {
        let sampleRate: Double = 44_100
        // Stereo — gives the sound air and prevents it feeling mono/flat
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!

        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, options: .mixWithOthers)
        try? session.setActive(true)

        let engine = AVAudioEngine()
        let node   = AVAudioPlayerNode()
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)

        chimeEngine = engine
        chimeNode   = node
        guard (try? engine.start()) != nil else { return }

        let frameCount = AVAudioFrameCount(duration * Float(sampleRate))
        guard let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
        buf.frameLength = frameCount

        let left  = buf.floatChannelData![0]
        let right = buf.floatChannelData![1]
        let twoPi = Float.pi * 2

        // Base decay: controls how fast the fundamental fades
        // Higher fundamental → slightly faster decay (smaller bells ring shorter)
        let baseDecay: Float = 1.8 + (528 / fundamental) * 0.4

        // Very small per-channel detuning creates natural stereo width
        let detuneL: Float =  0.0015   // +0.15 % left
        let detuneR: Float = -0.0015   // -0.15 % right

        for frame in 0..<Int(frameCount) {
            let t = Float(frame) / Float(sampleRate)

            // Strike noise: broadband click lasting ~4 ms, models mallet/finger impact
            let noiseT   = min(1.0, t / 0.004)
            let noiseEnv = noiseT * exp(-t * 600)
            // Simple noise via deterministic sawtooth — avoids random seed issues
            let noiseSaw  = (Float(frame % 7) / 3.5) - 1.0
            let strikeL   = noiseSaw * noiseEnv * amplitude * 0.18
            let strikeR   = noiseSaw * noiseEnv * amplitude * 0.18

            // 1.2 ms smooth attack on tone partials
            let attack = min(1.0, t / 0.0012)

            var sL: Float = strikeL
            var sR: Float = strikeR

            for p in partials {
                let freq   = fundamental * p.ratio
                let decay  = baseDecay * p.decayMul
                let env    = attack * exp(-decay * t)

                // Tiny inharmonic wobble at strike (pitch stabilises within 20 ms)
                let wobble = 1.0 + 0.003 * exp(-t * 120)

                sL += amplitude * p.amp * env * sin(twoPi * freq * (1 + detuneL) * wobble * t)
                sR += amplitude * p.amp * env * sin(twoPi * freq * (1 + detuneR) * wobble * t)
            }

            // Soft limiter — prevents clipping if partials stack at t≈0
            left[frame]  = tanh(sL)
            right[frame] = tanh(sR)
        }

        node.scheduleBuffer(buf, at: nil, options: []) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                chimeEngine?.stop()
                chimeEngine = nil
                chimeNode   = nil
            }
        }
        node.play()
    }
}
