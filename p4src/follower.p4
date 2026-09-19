control Follower(inout header_t hdr,
            inout metadata_t ig_md,
            in ingress_intrinsic_metadata_t ig_intr_md,
            in ingress_intrinsic_metadata_from_parser_t ig_prsr_md,
            inout ingress_intrinsic_metadata_for_deparser_t ig_dprsr_md,
            inout ingress_intrinsic_metadata_for_tm_t ig_tm_md) {
 
    Register <timestamp_t, bit<32>>(size=TOTAL_NUM_SLICES, initial_value=0) clock_reg;
    Register <timestamp_t, bit<32>>(size=NUM_MESSAGES, initial_value=0) fts_reg; 
    Register <bit<16>, bit<32>>(size=NUM_MESSAGES, initial_value=0) num_ack_reg;
    Register <bit<16>, bit<32>>(size=NUM_MESSAGES, initial_value=0) num_ldrs_reg;

    RegisterAction<timestamp_t, bit<32>, bit<32>>(clock_reg) update_own_clock_reg = {
        void apply(inout bit<32> value, out bit<32> rv) { 
            if (value < hdr.msg.timestamp) {
                value = hdr.msg.timestamp;
            }
            rv = value;
        }
    };

    RegisterAction<timestamp_t, bit<32>, bit<1>>(clock_reg) bump_clock_reg = {
        void apply(inout bit<32> value, out bit<1> flag) { 
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

    RegisterAction<bit<16>, bit<32>, bit<16>>(num_ldrs_reg) count_num_ldrs_reg = {
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

    // Update header with ACK command and own switch ID.
    action send_acknowledgement() {
        hdr.amcast.command = command.ACK;
        hdr.amcast.slice_id = ig_md.slice_id;
        ig_tm_md.mcast_grp_a = ig_md.own_mcast_group;
    }

    action deliver_msg(PortId_t port) {
        hdr.amcast.command = command.DELIVER;
        hdr.amcast.slice_id = ig_md.slice_id;
        hdr.amcast.group_id = ig_md.group_id;
        hdr.amcast.epoch = ig_md.cur_epoch;
        hdr.msg.timestamp = ig_md.fts;
        ig_tm_md.ucast_egress_port = port; 
        ig_tm_md.mcast_grp_a = 0;
    }

    action drop_packet() { 
        ig_dprsr_md.drop_ctl = 0x1;
        exit;
    }

    apply {
        if (hdr.amcast.command == command.ACK &&  
                hdr.amcast.group_id == ig_md.group_id &&
                hdr.amcast.epoch == ig_md.cur_epoch) {
            ig_md.acks = increment_ack_reg.execute(ig_md.index);
        }
        // Receiving a proposal from the leader of own group
        else if (hdr.amcast.command == command.PROP && 
                    hdr.amcast.group_id == ig_md.group_id &&
                    hdr.amcast.epoch == ig_md.cur_epoch) {
            if (hdr.amcast.slice_id == ig_md.leader_id) {
                ig_md.clock = update_own_clock_reg.execute(ig_md.slice_id);
                send_acknowledgement();  // Send own ACK to members of own group.
            }
        }
        // Receiving a proposal from leaders of other groups
        else if (hdr.amcast.command == command.PROP && 
                    hdr.amcast.group_id != ig_md.group_id &&
                    hdr.amcast.epoch == ig_md.cur_epoch) {
            ig_md.cur_num_grps = count_num_ldrs_reg.execute(ig_md.index);
            ig_md.fts = update_fts_reg.execute(ig_md.slice_id);
            bump_clock_reg.execute(ig_md.slice_id);
            ig_md.acks = num_ack_reg.read(ig_md.index);
            drop_packet();
        } 
        else {
            drop_packet();
        }
    }
}
