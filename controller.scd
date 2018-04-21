{|self|
    var drywet = \amp.asSpec;
    var amplitude = \amp.asSpec;
    var muteDuration = ControlSpec(1/4, 1/20, \exp);

    var numGroups = self.outputs.groups.size;
    var sBtns, mBtns, rBtns;
    // var muteFunction;
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

    if (numGroups < 8) { // NanoKontrol2 has maximum 8 faders
        // assign volume group control
        self.controller.faders[0..(numGroups - 1)].do {|fader, i|
            var controlName = "group_%_gain".format(i).asSymbol;

            fader.onChange = {arg val;
                var amp = amplitude.map(val / 127);
                self.router.set(controlName, amp);
            };
        };

        // assign drywet group control
        self.controller.knobs[0..(numGroups - 1)].do {|knob, i|
            knob.onChange = {arg val;
                var amount = drywet.map(val / 127);
                self.controlBuses.drywet[i].set(amount);
            };
        };
    } {
        "Can't assign volume. Too many groups.".throw;
    };

    sBtns = self.controller.sBtns[0..5];
    mBtns = self.controller.mBtns[0..5];
    rBtns = self.controller.rBtns[0..5];

    [ sBtns, mBtns, rBtns, self.diffusers ].flopWith {|sBtn, mBtn, rBtn, diffuser|
        // mute
        sBtn.onPress = {|val, btn|
            if (diffuser.mute.isActive.not) {
                diffuser.mute.start;
                btn.ledState = 1;
            } {
                diffuser.mute.cancel;
                btn.ledState = 0;
            };
        };

        // ampmod
        mBtn.onPress = {|val, btn|
            if (diffuser.gate.isActive.not) {
                diffuser.gate.start;
                btn.ledState = 1;
            } {
                diffuser.gate.cancel;
                btn.ledState = 0;
            };
        };

        rBtn.onPress = {|val, btn|
            if (diffuser.grain.isActive.not) {
                diffuser.grain.start;
                btn.ledState = 1;
            } {
                diffuser.grain.cancel;
                btn.ledState = 0;
            };
        };
    };

    // self.controller.fader7.onChange = {arg val;
    //     self.muteDuration = muteDuration.map(val / 127);
    // };

    self.controller.knob7.onChange = {arg val;
        var amount = drywet.map(val / 127);
        self.controlBuses.mute.drywet.set(amount);
    };

    self.controller.knob8.onChange = {arg val;
        var fbGain;

        val = val / 127;

        fbGain = grains.fbGain.map(val);
        self.grainGroup.set(\fbGain, fbGain);
    };

    // self.controller.fader4.onChange = {arg val;
    //     var amount = drywet.map(val / 127);
    //     self.grainGroup.set(\drywet, amount);
    // };

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
