// TODO:
//
// Control interpolation in SynthDef
// Main group volume controls
// FX output bus assignments
// Reverb FX
// Fix gate FX

(
    var kNUM_CHANNELS = 2;
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
        // load synthdefs
        (self.path +/+ "synthdefs.scd").load.value(self);

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
        self.analyzerInputBus.free;

        self.buffer.close;
        self.buffer.free;
    };

    s.waitForBoot {
        q.init;
        s.sync;
        CmdPeriod.doOnce { q.dealloc; };
    };
)
