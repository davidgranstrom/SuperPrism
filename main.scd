// TODO:
//
// Main group volume controls
// FX output bus assignments
// Reverb FX
// Fix gate FX

(
    var kNUM_CHANNELS = 2;
    var kOUTPUT_OFFSET = 0;
    var kINPUT_FILE = "waning-moon.wav";

    q = q ? ();

    // adjust to interface max output channels
    s.options.numOutputBusChannels = 24;

    // set clock for diffuser patterns
    TempoClock.default.tempo = 1;

    q.init = {|self|
        var numOutputGroups = 2;

        self.path = "~/code/supercollider/intonal".standardizePath;

        SoundFile.use(self.path +/+ "audio" +/+ kINPUT_FILE, {|sf|
            self.inputNumChannels = sf.numChannels;
        });

        self.srcBus = Bus.audio(s, self.inputNumChannels);
        self.analyzerInputBus = Bus.audio(s, self.inputNumChannels);

        self.analyzerBuses = ();
        self.analyzerBuses.lpf = Bus.control(s, 1);
        self.analyzerBuses.bpf = Bus.control(s, 1);
        self.analyzerBuses.hpf = Bus.control(s, 1);

        // output bus assignments
        self.outputs = ();
        self.outputs.groups = { () }.dup(numOutputGroups);

        self.addOutputGroup(0, [ 0, 1, 2, 3, 4, 5, 6, 7 ]);
        self.addOutputGroup(1, 8 + [ 0, 1, 2, 3, 4, 5, 6, 7 ]);
        // self.addOutputGroup(2, [ 0, 1, 2, 3, 4, 5, 6, 7 ]);
        // self.addOutputGroup(3, [ 0, 1, 2, 3, 4, 5, 6, 7 ]);
        // self.addOutputGroup(4, [ 0, 1, 2, 3, 4, 5, 6, 7 ]);

        // DEBUG
        self.srcBuses = { Bus.audio(s, 1) }.dup(2);

        self.createGroups;
        self.loadSoundFile;
        // load synthdefs
        (self.path +/+ "synthdefs.scd").load.value(self);

        s.sync;

        // initialize controller
        (self.path +/+ "controller.scd").load.value(self);
        // create diffusers
        (self.path +/+ "diffusers.scd").load.value(self);

        s.sync;

        self.start;
    };

    q.addOutputGroup = {|self, index, outputMap|
        var size = outputMap.size;

        self.outputs.groups[index].external = outputMap;
        self.outputs.groups[index].internal = { Bus.audio(s, 1) }.dup(size);
    };

    q.createGroups = {|self|
        self.srcGroup = Group.new;
        self.diffusionGroup = Group.after(self.srcGroup);

        // diffusers
        self.grainGroup = Group.tail(self.diffusionGroup);
        self.ampmodGroup = Group.tail(self.diffusionGroup);
        self.gateGroup = Group.tail(self.diffusionGroup);
        self.muterGroup = Group.tail(self.diffusionGroup);
        self.reverbGroup = Group.tail(self.diffusionGroup);

        // master
        self.masterGroup = Group.after(self.diffusionGroup);
    };

    q.loadSoundFile = {|self|
        var path = self.path +/+ "audio" +/+ kINPUT_FILE;
        var bufferSize = 2 ** 19;

        self.buffer = Buffer.cueSoundFile(s, path, 0, 2, bufferSize.asInteger);
    };

    q.start = {|self|
        s.makeBundle(nil, {
            self.grainSynths.do(_.run);
            self.ampmodSynths.do(_.run);
            self.reverbSynths.do(_.run);

            s.sync;

            self.router = Synth.tail(self.srcGroup, \router);
            Synth.tail(self.srcGroup, \analyzer);
            Synth.tail(self.masterGroup, \mainout, [\out, kOUTPUT_OFFSET]);

            s.sync;

            Synth.head(self.srcGroup, \diskin, [\buf, self.buffer]);
        });
    };

    q.dealloc = {|self|
        self.analyzerBuses.do(_.free);
        self.analyzerInputBus.free;
        self.outputs.groups.do {|group|
            group.internal.do(_.free);
        };

        self.buffer.close;
        self.buffer.free;

        "Dealloc called".postln;
    };

    s.waitForBoot {
        q.init;
        CmdPeriod.doOnce { q.dealloc; };
    };
)
