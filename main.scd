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
        // diffusors
        self.ampmodGroup = Group.tail(self.diffusionGroup);
        self.muterGroup = Group.tail(self.diffusionGroup);
        // master
        self.masterGroup = Group.after(self.diffusionGroup);

        self.loadSoundFile;
        self.makeSynthDefs;
        s.sync;

        self.initController;
        self.makeDiffusors;
        self.start;
    };

    q.initController = {|self|
        var ampSpec = \amp.asSpec;
        var ampModSpec = ControlSpec(1/2, 14, \exp);

        if (self.nano.isNil) {
            self.nano = NanoKontrol2();
        };

        self.nano.fader1.onChange = {arg val;
            var amount = ampSpec.map(val / 127);
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
            var amount = ampSpec.map(val / 127);
            self.ampmodGroup.set(\drywet, amount);
        };

        self.nano.knob2.onChange = {arg val;
            var freq = ampModSpec.map(val / 127);
            self.ampmodGroup.set(\freq, freq);
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

        SynthDef(\muter, {arg xfade=1, drywet=1, bus, gate=1;
            var sig = In.ar(bus, 1);
            var mod = Silent.ar(1);
            var env = Env.asr(0.01, 1, 0.01, \sine).kr(Done.freeSelf, gate);
            sig = sig * mod;
            XOut.ar(bus, env * xfade * drywet, sig);
        }).add;

        SynthDef(\mainout, {arg amp=1, out;
            var sig = self.outputBuses.collect(In.ar(_,1));
            sig = sig.sanitize;
            Out.ar(out, amp * sig);
        }).add;
    };

    q.makeDiffusors = {|self|
        var muters = self.outputBuses.collect {|bus|
            Pbind(
                \instrument, \muter,
                \group, self.muterGroup,
                \bus, bus,
                \xfade, Prand([ 0, 1 ], inf),
                \dur, Pwhite(0.125, 0.5),
                \legato, 1.0,
            );
        };

        s.bind {
            self.outputBuses.do {|bus|
                Synth.head(self.ampmodGroup, \ampmod, [
                    \freq, rrand(1/5, 14.0),
                    \bus, bus,
                ]);
            };
        };

        self.mutePatterns = Ppar(muters);
    };

    q.start = {|self|
        Synth.head(self.srcGroup, \diskin, [\buf, self.buffer]);
        Synth.tail(self.srcGroup, \analyzer);
        Synth.tail(self.masterGroup, \mainout, [\out, kOUTPUT_OFFSET]);
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
