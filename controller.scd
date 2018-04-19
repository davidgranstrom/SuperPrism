{|self|
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

    self.nano.fader5.onChange = {arg val;
        var amount = drywet.map(val / 127);
        self.reverbGroup.set(\drywet, amount);
    };
};
