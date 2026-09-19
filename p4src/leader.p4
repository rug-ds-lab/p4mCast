control Leader(inout header_t hdr,
            inout metadata_t ig_md,
            in ingress_intrinsic_metadata_t ig_intr_md,
            in ingress_intrinsic_metadata_from_parser_t ig_prsr_md,
            inout ingress_intrinsic_metadata_for_deparser_t ig_dprsr_md,
            inout ingress_intrinsic_metadata_for_tm_t ig_tm_md) {

    Register <timestamp_t, bit<32>>(size=TOTAL_NUM_SLICES, initial_value=0) clock_reg;
    Register <timestamp_t, bit<32>>(size=NUM_MESSAGES, initial_value=0) fts_reg; 
    Register <timestamp_t, bit<32>>(size=NUM_MESSAGES, initial_value=0) lts_reg; 
    Register <bit<16>, bit<32>>(size=NUM_MESSAGES, initial_value=0) num_ack_reg;
    Register <bit<16>, bit<32>>(size=NUM_MESSAGES, initial_value=0) num_grps_reg;

    RegisterAction<timestamp_t, bit<32>, timestamp_t>(clock_reg) advance_clock_reg = {
        void apply(inout timestamp_t value, out timestamp_t rv) {   
            value = value + 1;
            rv = value;
        }
    };

    RegisterAction<timestamp_t, bit<32>, bit<1>>(clock_reg) bump_clock_reg = {
        void apply(inout timestamp_t value, out bit<1> flag) { 
            if (value < hdr.msg.timestamp) {
                value = hdr.msg.timestamp;
                flag = 1;
            }
        }
    };

    RegisterAction<bit<16>, bit<32>, bit<16>>(num_ack_reg) increment_ack_reg = {
        void apply(inout bit<16> value, out bit<16> rv) {   
            value = value + 1;
            rv = value;
        }
    };

    RegisterAction<bit<16>, bit<32>, bit<16>>(num_grps_reg) count_num_grps_reg = {
        void apply(inout bit<16> value, out bit<16> rv) {   
            value = value + 1;
            rv = value;
        }
    };

    RegisterAction<timestamp_t, bit<32>, timestamp_t>(fts_reg) update_fts_reg = {
        void apply(inout timestamp_t value, out timestamp_t rv) { 
            if (value < hdr.msg.timestamp) {
                value = hdr.msg.timestamp;
                rv = value;
            } else {
                rv = value;
            }
        }
    };

    action drop_packet() { 
        ig_dprsr_md.drop_ctl = 0x1;
        exit;
    }

    // propose message timestamp
    action propose_local_ts() {
        hdr.amcast.command = command.PROP;
        hdr.amcast.app_id = ig_md.app_id;
        hdr.amcast.slice_id = ig_md.slice_id;
        hdr.amcast.group_id = ig_md.group_id;
        hdr.amcast.epoch = ig_md.cur_epoch;
        hdr.amcast.clock = ig_md.clock;
        hdr.msg.timestamp = ig_md.clock;
        ig_tm_md.mcast_grp_a = ig_md.mcast_group_all_dests;
    }

    action deliver_msg() {
        hdr.amcast.command = command.DELIVER;
        hdr.amcast.app_id = ig_md.app_id;
        hdr.amcast.slice_id = ig_md.slice_id;
        hdr.amcast.group_id = ig_md.group_id;
        hdr.amcast.epoch = ig_md.cur_epoch;
        hdr.amcast.clock = ig_md.clock;
        hdr.msg.timestamp = ig_md.fts;
        ig_tm_md.mcast_grp_a = 0;
    }

    action forward_to_replicas_hit(bit<16> mcast_grp) { 
        ig_tm_md.mcast_grp_a = mcast_grp;
    }

    action forward_to_replicas_miss() {
        drop_packet();
    }

    // Slide ID to Egress port ID mapping : for each slice corresponds a destination host/replica process. 
    table forward_to_replicas {
        key = {
            hdr.amcast.slice_id : exact;
        }
        actions = {
            forward_to_replicas_hit;
            forward_to_replicas_miss;
        }
        size = TOTAL_NUM_SLICES;
        const default_action = forward_to_replicas_miss();
    }

    // action add_ingress_tstamp() {
    //     hdr.e2e_delay.setValid();
    //     hdr.ipv4.total_len = hdr.ipv4.total_len + 12;
    //     hdr.udp.hdr_length = hdr.udp.hdr_length + 12;
    //     hdr.e2e_delay.ig_tstamp = ig_intr_md.ingress_mac_tstamp;
    //     hdr.e2e_delay.eg_tstamp = 0;
    // }

    apply {

        if (hdr.amcast.command == command.START) {
            ig_md.clock = advance_clock_reg.execute(ig_md.slice_id);
            // update the procotol header and propose local timestamp.
            propose_local_ts();
            lts_reg.write(ig_md.clock, ig_md.slice_id);
            ig_md.fts = update_fts_reg.execute(ig_md.slice_id);
            // add_ingress_tstamp();
        } 
        else if (hdr.amcast.command == command.ACK && 
            hdr.amcast.group_id == ig_md.group_id) {
            // Track ACKs from own group
            ig_md.acks = increment_ack_reg.execute(ig_md.slice_id);
            ig_md.cur_num_grps = num_grps_reg.read(ig_md.slice_id);
            ig_md.clock = lts_reg.read(ig_md.slice_id);
            ig_md.fts = fts_reg.read(ig_md.slice_id);
        } 
        else if (hdr.amcast.command == command.PROP &&
                hdr.amcast.group_id != ig_md.group_id) {  // doest not include own proposal / own group
            ig_md.cur_num_grps = count_num_grps_reg.execute(ig_md.slice_id);
            ig_md.fts = update_fts_reg.execute(ig_md.slice_id);
            bump_clock_reg.execute(ig_md.slice_id);
            ig_md.acks = num_ack_reg.read(ig_md.slice_id);
            ig_md.clock = lts_reg.read(ig_md.slice_id);
        } 
        if (ig_md.cur_num_grps == ig_md.num_grps && ig_md.acks == ig_md.quorum) {
            // deliver m with final timestamp           
            deliver_msg();
            // Only the leaf switch is concerned with the message delivery to the hosts 
            // Unicast forwarding towards the destination hosts 
            forward_to_replicas.apply();
        }
    }
}