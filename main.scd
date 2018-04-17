// TODO:
//
// Control interpolation in SynthDef
// Main group volume controls
// FX output bus assignments
// Reverb FX
// Fix gate FX

(
    var kNUM_CHANNELS = 8;
    var kOUTPUT_OFFSET = 6;

    q = q ? ();

    s.options.numOutputBusChannels = 24; // adjust to interface max output channels

    q.init = {|self|
        self.path = "~/code/supercollider/intonal".standardizePath;

        self.analyzerInputBus = Bus.audio(s, 2);
        self.analyzerBuses = ();
        self.analyzerBuses.lpf = Bus.control(s, 1);
        self.analyzerBuses.bpf = Bus.control(s, 1);
        self.analyzerBuses.hpf = Bus.control(s, 1);

        self.outputBuses = { Bus.audio(s, 1) }.dup(kNUM_CHANNELS);

        self.srcGroup = Group.new;
        self.fxGroup = Group.after(self.srcGroup);
        self.diffusionGroup = Group.after(self.fxGroup);

        // diffusers
        self.grainGroup = Group.tail(self.diffusionGroup);
        self.ampmodGroup = Group.tail(self.diffusionGroup);
        self.gateGroup = Group.tail(self.diffusionGroup);
        self.muterGroup = Group.tail(self.diffusionGroup);

        // master
        self.masterGroup = Group.after(self.diffusionGroup);

        self.loadSoundFile;
        self.makeSynthDefs;
        s.sync;

        self.initController;
        self.makeDiffusers;
        s.sync;

        self.start;
    };

    q.initController = {|self|
        var drywet = \amp.asSpec;
        // var threshSpec = ControlSpec(0.07, 0.3, \exp);
        // var gateHpfFreqSpec = ControlSpec(250, 1000, \exp);

        var ampmod = ();
        var chopper = ();
        var grains = ();

        ampmod.freq = ControlSpec(1/2, 14, \exp);

        chopper.density = ControlSpec(8, 14, \exp);
        chopper.hpf = ControlSpec(20, 500, \exp);
        chopper.rel = ControlSpec(0.5, 0.1, \exp);
        chopper.gain = ControlSpec(0.5, 3, \exp);

        grains.fbGain = ControlSpec(0, 2, \sin);

        if (self.nano.isNil) {
            self.nano = NanoKontrol2();
        };

        self.nano.fader1.onChange = {arg val;
            var amount = drywet.map(val / 127);
            self.muterGroup.set(\drywet, amount);
        };

        self.nano.sBtn1.onPress = {
            if (self.mutePatterns.isPlaying) {
                self.mutePatterns.stop;
            } {
                self.mutePatterns = self.mutePatterns.play;
            };
        };

        self.nano.fader2.onChange = {arg val;
            var amount = drywet.map(val / 127);
            self.ampmodGroup.set(\drywet, amount);
        };

        self.nano.knob2.onChange = {arg val;
            var freq = ampmod.freq.map(val / 127);
            self.ampmodGroup.set(\freq, freq);
        };

        // self.nano.knob3.onChange = {arg val;
        //     var threshold = threshSpec.map(val / 127);
        //     var freq = gateHpfFreqSpec.map(val / 127);

        //     threshold.postln;
        //     self.gateGroup.set(\threshold, threshold);
        //     self.gateGroup.set(\hpfreq, freq);
        // };

        self.nano.knob3.onChange = {arg val;
            var density, freq, release, gain;

            val = val / 127;

            density = chopper.density.map(val);
            freq = chopper.hpf.map(val);
            release = chopper.rel.map(val);
            gain = chopper.gain.map(val);

            self.gateGroup.set(\density, density);
            self.gateGroup.set(\hpfreq, freq);
            self.gateGroup.set(\release, release);
            self.gateGroup.set(\gain, gain);
        };

        self.nano.knob4.onChange = {arg val;
            var fbGain;

            val = val / 127;

            fbGain = grains.fbGain.map(val);
            self.grainGroup.set(\fbGain, fbGain);
        };

        self.nano.fader4.onChange = {arg val;
            var amount = drywet.map(val / 127);
            self.grainGroup.set(\drywet, amount);
        };
    };

    q.loadSoundFile = {|self|
        var path = self.path +/+ "audio/waning-moon.wav";
        var bufferSize = 2 ** 19;

        self.buffer = Buffer.cueSoundFile(s, path, 0, 2, bufferSize.asInteger);
    };

    q.makeSynthDefs = {|self|
        SynthDef(\diskin, {arg buf, amp=1, analyzerOut;
            var sig = VDiskIn.ar(2, buf, BufRateScale.kr(buf));

            self.outputBuses.do {|bus, i|
                Out.ar(bus, sig.wrapAt(i));
            };

            Out.ar(self.analyzerInputBus, sig);
        }).add;

        SynthDef(\analyzer, {arg buf, amp=1, out;
            var sig = self.analyzerInputBus.ar().sum;
            var buses = [
                self.analyzerBuses.lpf,
                self.analyzerBuses.bpf,
                self.analyzerBuses.hpf,
            ];

            var hpf = 2*HPF.ar(sig, 2200);
            var bpf = BPF.ar(sig, 600, 1);
            var lpf = LPF.ar(sig, 300);

            sig = [
                Amplitude.kr(lpf, 0.01, 0.1),
                Amplitude.kr(bpf, 0.01, 0.1),
                Amplitude.kr(hpf, 0.01, 0.1),
            ];

            // sig.poll;

            [ sig, buses ].flopWith {|analysis, bus|
                Out.kr(bus, analysis);
            };
        }).add;

        SynthDef(\ampmod, {arg freq=3, bus, xfade=1, drywet=0;
            var input, ext, mod;

            input = In.ar(bus, 1);

            ext = 1.5 * self.analyzerBuses.lpf.kr;
            ext = ext.clip(0, 1);

            freq = freq * ext.linlin(0, 1, 0.5, 1.5);
            mod = SinOsc.ar(freq);

            input = input * mod.range(0, 1);
            // input = HPF.ar(input, freq.linlin(1/2, 16, 20, 1000).lag(0.1));

            XOut.ar(bus, xfade * drywet, input);
        }).add;

        SynthDef(\mute, {arg xfade=1, drywet=1, bus, gate=1;
            var sig = In.ar(bus, 1);
            var mod = Silent.ar(1);
            var env = Env.asr(0.01, 1, 0.01, \sine).kr(Done.freeSelf, gate);
            sig = sig * mod;
            XOut.ar(bus, env * xfade * drywet, sig);
        }).add;

        SynthDef(\gate, {arg threshold=0.1, hpfreq=20, xfade=1, drywet=1, bus;
            var sig = In.ar(bus, 1);
            sig = HPF.ar(sig, hpfreq);
            sig = Compander.ar(sig, sig, threshold, 20, 1, 0.001, 0.1);
            XOut.ar(bus, xfade * drywet, sig);
        }).add;

        SynthDef(\chopper, {arg density=8, hpfreq=200, release=0.1, gain=1, xfade=1, drywet=1, bus;
            var sig = In.ar(bus, 1);
            var ext = 1.5 * self.analyzerBuses.lpf.kr;

            ext = ext.clip(0, 1);
            density = density * ext.linlin(0, 1, 1, 3);

            sig = HPF.ar(sig, hpfreq);
            sig = gain * sig * Decay2.ar(Dust.ar(density), 0.001, release);
            sig = Limiter.ar(sig);

            XOut.ar(bus, xfade * drywet, sig);
        }).add;

        SynthDef(\grains, {
            arg drywet=1, fbGain=0, bus;

            var input = In.ar(bus, 1);

            var bufLength = 0.5;
            var localBuf = LocalBuf(bufLength * SampleRate.ir).clear;

            var warp = Warp1.ar(
                1,
                localBuf,
                LFSaw.ar(1/bufLength).range(0, 1),
                Drand([ 2, -2 ], inf),
                Dwhite(0.05, 0.08),
                -1,
                2,
                0.8,
                4
            );

            // record w/ feedback
            RecordBuf.ar(tanh(input + HPF.ar(tanh(warp * fbGain), 30)), localBuf);

            warp = HPF.ar(warp * 0.5, 350);
            warp = warp.tanh;
            warp = warp.sanitize;

            XOut.ar(bus, drywet, warp);
        }).add;

        SynthDef(\mainout, {arg amp=1, out;
            var sig = self.outputBuses.collect(In.ar(_,1));
            sig = sig.sanitize;
            Out.ar(out, amp * sig);
        }).add;
    };

    q.makeDiffusers = {|self|
        var mutePatterns, ampmods, grains, gates;

        mutePatterns = self.outputBuses.collect {|bus|
            Pbind(
                \instrument, \mute,
                \group, self.muterGroup,
                \bus, bus,
                \xfade, Prand([ 0, 1 ], inf),
                \dur, Pwhite(0.125, 0.5),
                \legato, 1.0,
            );
        };

        ampmods = self.outputBuses.collect {|bus|
            Synth.newPaused(\ampmod, [
                \freq, rrand(1/5, 14.0),
                \bus, bus,
            ], self.ampmodGroup);
        };

        grains = self.outputBuses.collect {|bus|
            Synth.newPaused(\grains, [
                \bus, bus,
            ], self.grainGroup);
        };

        self.mutePatterns = Ppar(mutePatterns);
        self.ampmodSynths = ampmods;
        self.grainSynths = grains;
    };

    q.start = {|self|
        s.makeBundle(nil, {
            self.ampmodSynths.do {|synth| synth.run };
            self.grainSynths.do {|synth| synth.run };

            s.sync;

            Synth.tail(self.masterGroup, \mainout, [\out, kOUTPUT_OFFSET]);
            Synth.tail(self.srcGroup, \analyzer);

            s.sync;

            Synth.head(self.srcGroup, \diskin, [\buf, self.buffer]);
        });
    };

    q.dealloc = {|self|
        self.analyzerBuses.do(_.free);
        self.outputBuses.do(_.free);
        self.analyzerBus.free;

        self.buffer.close;
        self.buffer.free;
    };

    s.waitForBoot {
        q.init;
        s.sync;
        CmdPeriod.doOnce { q.dealloc; };
    };
)
s.plotTree
