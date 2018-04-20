{|self|
    var mutePatterns, ampmods, grains, gates, reverbs;
    var groups = self.outputs.groups;

    mutePatterns = groups.collect {|group|
        group.internal.collect {|bus|
            var pattern = Pbind(
                \instrument, \mute,
                \type, Pwrand([ \note, \rest ], [ 0.3, 0.7 ], inf),
                \group, self.muterGroup,
                \addAction, \addToTail,
                \bus, bus,
                \dur, Pfunc {
                    if (self.muteDuration.notNil) {
                        self.muteDuration;
                    } {
                        1/8;
                    }
                },
                \legato, 1.5,
            );

            // return
            (
                pattern: pattern,
                hpf: Synth.newPaused(\mute_hpf, [\bus, bus], self.muterGroup),
            );
        };
    }.flat;

    ampmods = self.srcBuses.collect {|bus|
        Synth.newPaused(\ampmod, [
            \freq, rrand(1/5, 14.0),
            \bus, bus,
        ], self.ampmodGroup);
    };

    grains = self.srcBuses.collect {|bus|
        Synth.newPaused(\grains, [
            \bus, bus,
        ], self.grainGroup);
    };

    reverbs = self.srcBuses.collect {|bus|
        Synth.newPaused(\reverb, [
            \bus, bus,
        ], self.reverbGroup);
    };

    self.mutePatterns = (
        synths: mutePatterns.collect(_.hpf),
        pattern: Ppar(mutePatterns.collect(_.pattern)),
    );

    self.ampmodSynths = ampmods;
    self.grainSynths = grains;
    self.reverbSynths = reverbs;
};
