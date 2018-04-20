{|self|
    var groups = self.outputs.groups;
    var diffuserGroups = List[];

    groups.do {|group|
        var diffusers = ();
        var buses = group.internal;

        var mutes = buses.collect {|bus, i|
            Synth.newPaused(\mute, [
                \bus, bus,
            ], self.muterGroup);
        };

        var ampmods = buses.collect {|bus|
            Synth.newPaused(\ampmod, [
                \freq, rrand(1/5, 14.0),
                \bus, bus,
            ], self.ampmodGroup);
        };

        var grains = buses.collect {|bus|
            Synth.newPaused(\grains, [
                \bus, bus,
            ], self.grainGroup);
        };

        var reverbs = buses.collect {|bus|
            Synth.newPaused(\reverb, [
                \bus, bus,
            ], self.reverbGroup);
        };

        diffusers.mute = mutes;
        diffusers.ampmod = ampmods;
        diffusers.grain = grains;
        diffusers.reverb = reverbs;

        diffuserGroups.add(diffusers);
    };

    diffuserGroups;
};
