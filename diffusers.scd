{|self|
    var diffuserGroups = List[];
    var groups = self.outputs.groups;

    var newDiffuser = {|buses, defName, group|
        var envir = ();
        var synths = nil;

        envir.start = {
            synths ?? {
                synths = buses.collect {|bus|
                    Synth.head(group, defName, [\bus, bus]);
                };
            };
        };

        envir.cancel = {
            synths !? {
                synths.do(_.release);
                synths = nil;
            };
        };

        envir.isActive = {
            synths.notNil;
        };

        envir;
    };

    groups.do {|group|
        var diffusers = ();
        var buses = group.internal;

        diffusers.mute = newDiffuser.(buses, 'mute', self.muterGroup);
        diffusers.ampmod = newDiffuser.(buses, 'ampmod', self.ampmodGroup);
        diffusers.grain = newDiffuser.(buses, 'grains', self.grainGroup);
        diffusers.reverb = newDiffuser.(buses, 'reverb', self.reverbGroup);

        diffuserGroups.add(diffusers);
    };

    diffuserGroups;
};
