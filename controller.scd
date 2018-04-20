{|self|
    var drywet = \amp.asSpec;
    var amplitude = \amp.asSpec;
    var muteDuration = ControlSpec(1/4, 1/20, \exp);
    var numGroups = self.outputs.groups.size;
    // var threshSpec = ControlSpec(0.07, 0.3, \exp);
    // var gateHpfFreqSpec = ControlSpec(250, 1000, \exp);

    var ampmod = ();
    var chopper = ();
    var grains = ();

    if (self.controller.isNil) {
        self.controller = NanoKontrol2(\external);
    };

    // control specs
    ampmod.freq = ControlSpec(1/2, 14, \exp);

    chopper.density = ControlSpec(8, 14, \exp);
    chopper.hpf = ControlSpec(20, 500, \exp);
    chopper.rel = ControlSpec(0.5, 0.1, \exp);
    chopper.gain = ControlSpec(0.5, 3, \exp);

    grains.fbGain = ControlSpec(0, 2, \sin);

    // controller assignments
    self.controller.faders[0..(numGroups - 1)].do {|fader, i|
        var controlName = "group_%_gain".format(i).asSymbol;

        fader.onChange = {arg val;
            var amp = amplitude.map(val / 127);
            self.router.set(controlName, amp);
        };
    };

    self.controller.fader7.onChange = {arg val;
        self.muteDuration = muteDuration.map(val / 127);
    };

    self.controller.knob7.onChange = {arg val;
        var amount = drywet.map(val / 127);
        self.controlBuses.mute.drywet.set(amount);
    };

    self.controller.sBtn7.onPress = {arg val, btn;
        var pattern = self.mutePatterns.pattern;
        var synths = self.mutePatterns.synths;

        s.makeBundle(nil, {
            if (pattern.isPlaying) {
                pattern.stop;
                synths.do(_.set(\gate, 0));
                btn.ledState = 0;
            } {
                synths.do(_.run(true));
                s.sync;
                synths.do(_.set(\gate, 1));
                self.mutePatterns.pattern = pattern.play;
                btn.ledState = 1;
            };
        });
    };

    /*
    self.controller.fader2.onChange = {arg val;
        var amount = drywet.map(val / 127);
        self.ampmodGroup.set(\drywet, amount);
    };

    self.controller.knob2.onChange = {arg val;
        var freq = ampmod.freq.map(val / 127);
        self.ampmodGroup.set(\freq, freq);
    };

    // self.controller.knob3.onChange = {arg val;
    //     var threshold = threshSpec.map(val / 127);
    //     var freq = gateHpfFreqSpec.map(val / 127);

    //     threshold.postln;
    //     self.gateGroup.set(\threshold, threshold);
    //     self.gateGroup.set(\hpfreq, freq);
    // };

    self.controller.knob3.onChange = {arg val;
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

    self.controller.knob4.onChange = {arg val;
        var fbGain;

        val = val / 127;

        fbGain = grains.fbGain.map(val);
        self.grainGroup.set(\fbGain, fbGain);
    };

    self.controller.fader4.onChange = {arg val;
        var amount = drywet.map(val / 127);
        self.grainGroup.set(\drywet, amount);
    };

    self.controller.fader5.onChange = {arg val;
        var amount = drywet.map(val / 127);
        self.reverbGroup.set(\drywet, amount);
    };
    */

    self.controller.fader8.onChange = {arg val;
        var amp = amplitude.map(val / 127);
        self.masterGroup.set(\amp, amp);
    };
};
