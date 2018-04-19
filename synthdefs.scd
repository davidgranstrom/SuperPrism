{|self|
    var lagTime = 0.05;

    SynthDef(\diskin, {arg buf, amp=1;
        var sig = VDiskIn.ar(self.inputNumChannels, buf, BufRateScale.kr(buf));
        Out.ar(self.srcBus, sig);
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

        [ sig, buses ].flopWith {|analysis, bus|
            Out.kr(bus, analysis);
        };
    }).add;

    SynthDef(\ampmod, {arg freq=3, drywet=0, bus;
        var input, ext, mod;

        input = In.ar(bus, 1);

        ext = 1.5 * self.analyzerBuses.lpf.kr;
        ext = ext.clip(0, 1);

        freq = freq * ext.linlin(0, 1, 0.5, 1.5);
        mod = SinOsc.ar(freq);

        input = input * mod.range(0, 1);
        // input = HPF.ar(input, freq.linlin(1/2, 16, 20, 1000).lag(0.1));

        XOut.ar(bus, drywet, input);
    }, lagTime.dup(3)).add;

    SynthDef(\mute, {arg bus, gate=1;
        var sig = In.ar(bus, 1);
        var mod = Silent.ar(1);
        var env = Env.asr(0.01, 1, 0.01, \sine).kr(Done.freeSelf, gate);
        sig = sig * mod;
        XOut.ar(bus, env, sig);
    }).add;

    SynthDef(\gate, {arg threshold=0.1, hpfreq=20, drywet=0, bus;
        var sig = In.ar(bus, 1);
        sig = HPF.ar(sig, hpfreq);
        sig = Compander.ar(sig, sig, threshold, 20, 1, 0.001, 0.1);
        XOut.ar(bus, drywet, sig);
    }, lagTime.dup(3)).add;

    SynthDef(\chopper, {arg density=8, hpfreq=200, release=0.1, gain=1, drywet=0, bus;
        var sig = In.ar(bus, 1);
        var ext = 1.5 * self.analyzerBuses.lpf.kr;

        ext = ext.clip(0, 1);
        density = density * ext.linlin(0, 1, 1, 3);

        sig = HPF.ar(sig, hpfreq);
        sig = gain * sig * Decay2.ar(Dust.ar(density), 0.001, release);
        sig = Limiter.ar(sig);

        XOut.ar(bus, drywet, sig);
    }, lagTime.dup(5)).add;

    SynthDef(\grains, {
        arg drywet=0, fbGain=0, bus;

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
    }, lagTime.dup(2)).add;

    SynthDef(\reverb, {arg lpfreq=5000, drywet=0, bus;
        var sig = In.ar(bus, 1);
        sig = HPF.ar(sig, 30);
        // sig = DFM1.ar(sig, lpfreq);
        // TODO: Switch to DFM1
        sig = RLPF.ar(sig, lpfreq);
        sig = FreeVerb.ar(sig, 1, 0.95, 0.5);
        XOut.ar(bus, drywet, sig);
    }, lagTime.dup(3)).add;

    SynthDef(\router, {
        var src = self.srcBus.ar;
        var numGroups = self.outputs.groups.size;
        var gains = Array.fill(numGroups, {|i|
            var name = "group" ++ (i + 1) ++ "_gain";
            NamedControl.kr(name, 1, lagTime);
        });

        self.outputs.groups.do {|group, i|
            group.internal.do {|bus, j|
                Out.ar(bus, gains[i] * src.wrapAt(j));
            };
        };
    }).add;

    SynthDef(\mainout, {arg amp=1, out;
        var outputArray = self.outputs.groups.collect(_.external);
        var busArray = self.outputs.groups.collect(_.internal);

        [ outputArray, busArray ].flopWith {|outputs, buses|
            [ outputs, buses ].flopWith {|output, bus|
                var sig = bus.ar;
                Out.ar(output, sig.sanitize);
            };
        };
    }).add;
};
