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

    SynthDef(\ampmod, {arg freq=3, drywet=1, gate=1, bus;
        var input, ext, mod;
        var env = Env.asr(0.01, 1, 0.01, \sine).ar(Done.freeSelf, gate);

        input = In.ar(bus, 1);

        ext = 1.5 * self.analyzerBuses.lpf.kr;
        ext = ext.clip(0, 1);

        freq = freq * ext.linlin(0, 1, 0.5, 1.5);
        mod = SinOsc.ar(freq);

        input = input * mod.range(0, 1);

        XOut.ar(bus, env * drywet, input);
    }, lagTime.dup(2)).add;

    SynthDef(\mute, {arg drywet=1, rate=8, bus, gate=1;
        var sig = In.ar(bus, 1);
        var env = Env.asr(0.01, 1, 0.01, \sine).ar(Done.freeSelf, gate);
        var ext = 1.5 * self.analyzerBuses.lpf.kr.lag(0.2);
        var mod = Demand.ar(Impulse.ar(rate), 0, Dwrand([ 0, 1 ], [ 0.3, 0.7 ], inf));

        sig = HPF.ar(sig, ext.linlin(0, 1, 120, 1000));
        sig = sig * mod.lag(0.05);

        XOut.ar(bus, env * drywet, sig);
    }, lagTime.dup(2)).add;

    SynthDef(\gate, {arg threshold=0.4, hpfreq=20, drywet=1, bus, gate=1;
        var sig = In.ar(bus, 1);
        var env = Env.asr(0.01, 1, 0.01, \sine).ar(Done.freeSelf, gate);
        sig = Compander.ar(sig, sig, threshold, 20, 1, 0.01, 0.5);
        sig = HPF.ar(sig, hpfreq);
        sig = FreeVerb.ar(sig, 1, 0.95, 0.5);
        XOut.ar(bus, env * drywet, sig);
    }, lagTime.dup(3)).add;

    SynthDef(\chopper, {arg density=8, hpfreq=200, release=0.1, gain=1, drywet=1, bus, gate=1;
        var sig = In.ar(bus, 1);
        var env = Env.asr(0.01, 1, 0.01, \sine).ar(Done.freeSelf, gate);
        var ext = 1.5 * self.analyzerBuses.lpf.kr;

        ext = ext.clip(0, 1);
        density = density * ext.linlin(0, 1, 1, 3);

        sig = HPF.ar(sig, hpfreq);
        sig = gain * sig * Decay2.ar(Dust.ar(density), 0.001, release);
        sig = Limiter.ar(sig);

        XOut.ar(bus, env * drywet, sig);
    }, lagTime.dup(5)).add;

    SynthDef(\grain, {|drywet=1, fbGain=0, bus, gate=1|
        var input = In.ar(bus, 1);
        var env = Env.asr(0.01, 1, 0.01, \sine).ar(Done.freeSelf, gate);

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

        XOut.ar(bus, env * drywet, warp);
    }, lagTime.dup(2)).add;

    SynthDef(\reverb, {arg lpfreq=5000, drywet=1, bus, gate=1;
        var sig = In.ar(bus, 1);
        var env = Env.asr(0.01, 1, 0.01, \sine).ar(Done.freeSelf, gate);
        sig = HPF.ar(sig, 30);
        // sig = DFM1.ar(sig, lpfreq);
        // TODO: Switch to DFM1
        sig = RLPF.ar(sig, lpfreq);
        sig = FreeVerb.ar(sig, 1, 0.95, 0.5);
        XOut.ar(bus, env * drywet, sig);
    }, lagTime.dup(3)).add;

    SynthDef(\router, {
        var src = self.srcBus.ar;
        var sends = self.outputs.monoSends;
        var numGroups = self.outputs.groups.size;

        var gains = Array.fill(numGroups, {|i|
            var name = "group_%_gain".format(i).asSymbol;
            NamedControl.kr(name, 1, lagTime);
        });

        self.outputs.groups.do {|group, i|
            group.internal.do {|bus, j|
                Out.ar(bus, gains[i] * src.wrapAt(j));
            };
        };

        // mono sends
        if (sends.internal.isEmpty.not) {
            var sum = src.mean * gains.mean;
            sends.internal.do {|bus|
                Out.ar(bus, sum);
            };
        };
    }).add;

    SynthDef(\mainout, {arg amp=0, out;
        var outputArray = self.outputs.groups.collect(_.external);
        var busArray = self.outputs.groups.collect(_.internal);
        var sends = self.outputs.monoSends;

        var gain = amp * self.mainOutLevelScale;

        // group outputs
        [ outputArray, busArray ].flopWith {|outputs, buses|
            [ outputs, buses ].flopWith {|output, bus|
                var sig = bus.ar;
                sig = sig * gain;
                Out.ar(output, sig.sanitize);
            };
        };

        // mono sends
        if (sends.external.isEmpty.not) {
            [ sends.external, sends.internal ].flopWith {|output, bus|
                var sig = bus.ar;
                sig = sig * gain;
                Out.ar(output, sig.sanitize);
            };
        };
    }, [ lagTime ]).add;
};