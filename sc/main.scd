// TODO:
//
// Use buses for diffuser controls
// Fix gate FX

(
    /*
    * Output group array.
    * Add arrays corresponding to hardware outputs to create output groups.
    * Each output group has a separate volume control and can be assigned different diffusers.
    */
    var kOUTPUT_GROUPS = [
        (1..4),     // 0 quad wide
        (5..8),     // 1 quad close
        (9..16),    // 2 octophonic ring
        (25..28),   // 3 roof
        (29..32),   // 4 choir
        [ 21, 22 ], // 5 outside room
        // (17..20),   // spaced quad
    ] - 1; // first hardware out is zero

    /*
    * Mono summed input source send.
    * Useful for sending to sub bass hardware outputs or similar.
    * Supply an empty array to disable.
    */
    var kMONO_SUM_SENDS = [ 23, 24 ] - 1;

    /*
    * Main out level adjustment in decibels
    */
    var kMAINOUT_LEVEL_SCALE = -6;

    /*
    * The input sound file to diffuse.
    * Should be placed in "audio" in this directory.
    */
    var kINPUT_FILE = "waning-moon.wav";

    /*
    * Set the total number of speakers/interface outputs
    */
    var kNUM_OUTPUT_BUS_CHANNELS = 32;

    /*
    * Hardware output offset.
    * Signal is routed incrementally starting from the offset value.
    */
    var kOUTPUT_OFFSET = 0;

    q = q ? ();

    // adjust to interface max output channels
    s.options.numOutputBusChannels = kNUM_OUTPUT_BUS_CHANNELS;

    // set clock for diffuser patterns
    TempoClock.default.tempo = 1;

    q.init = {|self|
        // paths
        self.path = "~/code/supercollider/intonal/sc".standardizePath;
        self.inputFilePath = PathName(self.path).parentPath +/+ "audio" +/+ kINPUT_FILE;

        // util
        self.mainOutLevelScale = kMAINOUT_LEVEL_SCALE.dbamp;

        // buses
        SoundFile.use(self.inputFilePath, {|sf|
            self.inputNumChannels = sf.numChannels;
        });

        self.srcBus = Bus.audio(s, self.inputNumChannels);
        self.analyzerInputBus = Bus.audio(s, self.inputNumChannels);

        self.analyzerBuses = ();
        self.analyzerBuses.lpf = Bus.control(s, 1);
        self.analyzerBuses.bpf = Bus.control(s, 1);
        self.analyzerBuses.hpf = Bus.control(s, 1);

        self.controlBuses = ();
        self.controlBuses.mute = ();
        self.controlBuses.gate = ();
        self.controlBuses.grain = ();
        self.controlBuses.drywet = List[];

        // custom initialization
        self.controlBuses.mute.rate = Bus.control(s, 1).set(8);
        self.controlBuses.gate.threshold = Bus.control(s, 1).set(0.4);
        self.controlBuses.gate.hpfreq = Bus.control(s, 1).set(180);
        self.controlBuses.grain.fbGain = Bus.control(s, 1).set(0);

        // create drywet control for each diffuser group
        kOUTPUT_GROUPS.size.do {
            var bus = Bus.control(s, 1).set(1);
            self.controlBuses.drywet.add(bus);
        };

        // output groups
        self.outputs = ();
        self.outputs.groups = { () }.dup(kOUTPUT_GROUPS.size);
        self.outputs.monoSends = ();

        // bus assignments
        kOUTPUT_GROUPS.do {|outputMap, index|
            self.addOutputGroup(index, outputMap);
        };

        self.outputs.monoSends.external = kMONO_SUM_SENDS;
        self.outputs.monoSends.internal = { Bus.audio(s, 1) }.dup(kMONO_SUM_SENDS.size);

        self.createGroups;
        self.loadSoundFile;

        // load synthdefs
        (self.path +/+ "synthdefs.scd").load.value(self);

        s.sync;

        // create diffusers
        self.diffusers = (self.path +/+ "diffusers.scd").load.value(self);

        // initialize controller
        (self.path +/+ "controller.scd").load.value(self);

        s.sync;

        self.start;
        self.playing = false;
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
        self.gateGroup = Group.tail(self.diffusionGroup);
        self.muterGroup = Group.tail(self.diffusionGroup);

        // master
        self.masterGroup = Group.after(self.diffusionGroup);
    };

    q.loadSoundFile = {|self|
        var path = self.inputFilePath;
        var bufferSize = 2 ** 19;

        self.buffer = Buffer.cueSoundFile(s, path, 0, 2, bufferSize.asInteger);
        // self.buffer = Buffer.cueSoundFile(s, path, 48000 * 30, 2, bufferSize.asInteger);
    };

    q.start = {|self|
        s.makeBundle(nil, {
            self.router = Synth.tail(self.srcGroup, \router);
            Synth.tail(self.srcGroup, \analyzer);
            Synth.tail(self.masterGroup, \mainout, [\out, kOUTPUT_OFFSET]);

            "% -- ready".format(kINPUT_FILE).postln;
        });
    };

    q.startPlayback = {|self|
        if (self.playing.not) {
            Synth.head(self.srcGroup, \diskin, [\buf, self.buffer]);
            self.playing = true;
        };
    };

    q.dealloc = {|self|
        self.analyzerBuses.do(_.free);
        self.analyzerInputBus.free;

        self.outputs.groups.do {|group|
            group.internal.do(_.free);
        };

        self.outputs.monoSends.internal.do(_.free);

        self.buffer.close;
        self.buffer.free;

        if (self.controller.notNil) {
            self.controller.ledsOff;
        };

        "hard stop - dealloc".postln;
    };

    s.waitForBoot {
        q.init;
        CmdPeriod.doOnce { q.dealloc; };
    };
)
