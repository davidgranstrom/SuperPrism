{|self|
    var numGroups = self.outputs.groups.size;
    var sBtns, mBtns, rBtns;

    var drywet = \amp.asSpec;
    var amplitude = \amp.asSpec;

    var mute = ();
    var gate = ();
    var grain = ();

    if (self.controller.isNil) {
        self.controller = NanoKontrol2(\external);
    };

    // control specs
    mute.rate = ControlSpec(2, 24, \sin);
    gate.threshold = ControlSpec(0.1, 1, \sin);
    gate.hpfreq = ControlSpec(80, 5000, \exp);
    grain.fbGain = ControlSpec(0, 2, \sin);

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

    self.controller.knob7.onChange = {arg val;
        var rate = mute.rate.map(val / 127);

        self.controlBuses.mute.rate.set(rate);
    };

    self.controller.fader7.onChange = {arg val;
        var threshold = gate.threshold.map(val / 127);
        var hpfreq = gate.hpfreq.map(val / 127);

        self.controlBuses.gate.threshold.set(threshold);
        self.controlBuses.gate.hpfreq.set(hpfreq);
    };

    self.controller.knob8.onChange = {arg val;
        var gain = grain.fbGain.map(val / 127);

        self.controlBuses.grain.fbGain.set(gain);
    };

    // master volume
    self.controller.fader8.onChange = {arg val;
        var amp = amplitude.map(val / 127);
        self.masterGroup.set(\amp, amp);
    };
};
