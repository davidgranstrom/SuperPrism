(
    var kNUM_CHANNELS = 24;

    q = q ? ();

    s.options.numOutputBusChannels = kNUM_CHANNELS;

    q.init = {|self|
        self.path = "~/code/supercollider/intonal".standardizePath;

        self.srcBus = Bus.audio(s, 2);
        // self.analyzerBus = Bus.control(s, 3);
        self.analyzerBuses = ();
        self.analyzerBuses.lpf = Bus.control(s, 1);
        self.analyzerBuses.bpf = Bus.control(s, 1);
        self.analyzerBuses.hpf = Bus.control(s, 1);

        self.srcGroup = Group.new;
        self.fxGroup = Group.after(self.srcGroup);
        self.diffusionGroup = Group.after(self.fxGroup);
        self.masterGroup = Group.after(self.diffusionGroup);

        self.loadSoundFile;
        self.makeSynthDefs;
        s.sync;

        self.start;
    };

    q.loadSoundFile = {|self|
        var path = self.path +/+ "audio/waning-moon.wav";
        var bufferSize = 2 ** 19;

        self.buffer = Buffer.cueSoundFile(s, path, 0, 2, bufferSize.asInteger);
    };

    q.makeSynthDefs = {|self|
        SynthDef(\diskin, {arg buf, amp=1, out;
            var sig = VDiskIn.ar(2, buf, BufRateScale.kr(buf));
            Out.ar(out, amp * sig);
        }).add;

        SynthDef(\analyzer, {arg buf, amp=1, out;
            var sig = self.srcBus.ar().sum;
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

        SynthDef(\diffuser, {arg amp=1, in, pos, out;
            var sig = In.ar(in, 1);
            // sig = PanAz.ar(kNUM_CHANNELS, sig, pos.lag(4));
            sig = PanAz.ar(kNUM_CHANNELS, sig, LFSaw.ar(1/5));
            Out.ar(out, amp * sig);
        }).add;

        SynthDef(\fader, {arg amp=1, in, out;
            var sig = In.ar(in, 1);
            Out.ar(out, amp * sig);
        }).add;

        SynthDef(\mainout, {arg amp=1, out;
            var sig = self.srcBus.ar();
            sig = sig.sanitize;
            // Out.ar(out, amp * sig);
        }).add;
    };

    q.makePatterns = {|self|

    };

    q.start = {|self|
        Synth.head(self.srcGroup, \diskin, [\buf, self.buffer, \out, self.srcBus]);
        Synth.tail(self.srcGroup, \analyzer, [\out, self.analyzerBus]);

        Synth.head(self.diffusionGroup, \diffuser, [\in, self.srcBus, \out, 0, \pos, self.analyzerBuses.lpf.asMap]);

        Synth.tail(self.masterGroup, \mainout, [\out, 0]);
    };

    q.dealloc = {|self|
        self.analyzerBuses.do(_.free);
        self.srcBus.free;

        self.buffer.close;
        self.buffer.free;
    };

    s.waitForBoot {
        q.init;
        s.sync;
        CmdPeriod.doOnce { q.dealloc; };
    };
)
s.meter
