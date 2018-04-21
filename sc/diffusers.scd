{|self|
    var diffuserGroups = List[];
    var groups = self.outputs.groups;

    var newDiffuser = {|defName, args, buses, group, groupIndex|
        var envir = ();
        var synths = nil;

        envir.start = {
            synths ?? {
                synths = buses.collect {|bus|
                    var drywet = self.controlBuses.drywet[groupIndex];
                    Synth.head(group, defName, [\bus, bus, \drywet, drywet.asMap] ++ args);
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

    groups.do {|group, groupIdx|
        var diffusers = ();
        var buses = group.internal;

        diffusers.mute = newDiffuser.(
            'mute',
            [\rate, self.controlBuses.mute.rate.asMap],
            buses,
            self.muterGroup,
            groupIdx
        );

        diffusers.gate = newDiffuser.(
            'chopper',
            [
                \hpfreq, self.controlBuses.gate.hpfreq.asMap
            ],
            buses,
            self.gateGroup,
            groupIdx
        );

        diffusers.grain = newDiffuser.(
            'grain',
            [\fbGain, self.controlBuses.grain.fbGain.asMap],
            buses,
            self.grainGroup,
            groupIdx
        );

        diffuserGroups.add(diffusers);
    };

    diffuserGroups;
};
