{|self|
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
