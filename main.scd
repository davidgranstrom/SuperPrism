// TODO:
//
// Main group volume controls
// FX output bus assignments
// Reverb FX
// Fix gate FX

(
    /*
    * Number of output groups.
    * Useful to apply different diffusers to a subset of speakers or
    * controlling amplitude of separate speaker groups.
    */
    var kNUM_OUTPUT_GROUPS = 1;
    /*
    * Hardware output offset.
    * Signal is routed incrementally starting from the offset value.
    */
    var kOUTPUT_OFFSET = 0;
    /*
    * The input sound file to diffuse.
    * Should be placed in "audio" in this directory.
    */
    var kINPUT_FILE = "waning-moon.wav";
    /*
    * Set the total number of speakers/interface outputs
    */
    var kNUM_OUTPUT_BUS_CHANNELS = 32;

    q = q ? ();

    // adjust to interface max output channels
    s.options.numOutputBusChannels = kNUM_OUTPUT_BUS_CHANNELS;

    // set clock for diffuser patterns
    TempoClock.default.tempo = 1;

    q.init = {|self|

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
        self.outputs.groups = { () }.dup(kNUM_OUTPUT_GROUPS);

        self.addOutputGroup(0, (0..31));
        self.outputs.groups = { () }.dup(numOutputGroups);

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
