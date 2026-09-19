#include <core.p4>
#include <tna.p4>

#include "types.p4"
#include "headers.p4"
#include "parde.p4"
#include "profile.p4"
#include "leader.p4"
#include "follower.p4"

// ---------------------------------------------------------------------------
// Ingress
// ---------------------------------------------------------------------------
control SwitchIngress(
        inout header_t hdr,
        inout metadata_t ig_md,
        in ingress_intrinsic_metadata_t ig_intr_md,
        in ingress_intrinsic_metadata_from_parser_t ig_prsr_md,
        inout ingress_intrinsic_metadata_for_deparser_t ig_dprsr_md,
        inout ingress_intrinsic_metadata_for_tm_t ig_tm_md) {
    
    Leader() leader;
    Follower() follower;
    // PrimaryChange() leaderElection;

    Register <bit<32>, bit<32>>(size=3, initial_value=0) id_reg; 

    RegisterAction<bit<32>, bit<32>, bit<32>>(id_reg) generate_id_reg_act = {
        void apply(inout bit<32> value, out bit<32> rv) {   
            value = value + 1;
            rv = value;
        }
    };

    action drop_packet() { 
        ig_dprsr_md.drop_ctl = 0x1;
        exit;
    }

    action slice_config_hit(SliceId_t slice_id, bit<8> role, GroupId_t group_id, SliceId_t leader_id, bit<8> epoch) {
        ig_md.slice_id = slice_id;
        ig_md.group_id = group_id;
        ig_md.role = role;
        ig_md.leader_id = leader_id;
        ig_md.cur_epoch = epoch;  

    }

    action slice_config_miss() {
        drop_packet();
    }

    table slice_config {
        key = {
            ig_intr_md.ingress_port : exact;
            hdr.amcast.app_id : exact;
        }
        actions = {
            slice_config_hit;
            slice_config_miss;
        }
        size = TOTAL_NUM_APPS;
        const default_action = slice_config_miss;
    }

    action msg_config_hit(bit<16> mcast_group_all_dests, bit<16> num_grps) {
        ig_md.mcast_group_all_dests = mcast_group_all_dests;
        ig_md.num_grps = num_grps;
        // ig_md.index = (ig_md.slice_id << 2);
    }

    action msg_config_miss() {
        drop_packet();
    }

    table msg_config {
        key = {
            // ig_intr_md.ingress_port : exact;
            hdr.msg.msg_id : exact;
        }
        actions = {
            msg_config_hit;
            msg_config_miss;
        }
        size = NUM_MESSAGES;
        // idle_timeout = true;
    }

    action msg_index_hit(bit<32> index) {
        // error: add: action spanning multiple stages. Operations on operand 2 ($tmp21[0..31]) in action msg_index_hit require multiple stages for a single action. We currently support only single stage actions. Please consider rewriting the action to be a single stage action.
        // ig_md.index = (ig_md.slice_id << 2) + hdr.msg.msg_id;
        // bit<32> index = ig_md.slice_id * NUM_MESSAGES + hdr.msg.msg_id;
        ig_md.index = index;
    }

    action msg_index_miss() {
        drop_packet();
    }

    table msg_index {
        key = {
            ig_md.slice_id : exact;
            hdr.msg.msg_id : exact;
        }
        actions = {
            msg_index_hit;
            msg_index_miss;
        }
        size = NUM_MESSAGES;
        const default_action = msg_index_miss;
    }

    action groups_config_hit(bit<16> mcast_grp, bit<16> quorum) {
        ig_md.own_mcast_group = mcast_grp;
        ig_md.quorum = quorum;
    }

    action groups_config_miss() {
        drop_packet();
    }

    table groups_config {
        key = {
            ig_md.group_id : exact;
        }
        actions = {
            groups_config_hit;
            groups_config_miss;
        }
        const default_action = groups_config_miss;
        size = TOTAL_NUM_GRPS;
    }

    action set_msg_hdr(bit<32> index) {
        hdr.udp.dst_port = MSG_UDP_DST_PORT;
        ig_md.checksum_upd_ipv4 = true; 
        hdr.msg.setValid();
        hdr.msg.msg_id = generate_id_reg_act.execute(index);
        hdr.msg.timestamp = 0x0; 
    }
    
    action set_p4mcast_hdr() {
        hdr.udp.dst_port = P4MCAST_UDP_DST_PORT;
        hdr.amcast.setValid();
        hdr.ipv4.total_len = hdr.ipv4.total_len + P4MCAST_MSG_HDR_LEN;
        hdr.udp.hdr_length = hdr.udp.hdr_length + P4MCAST_MSG_HDR_LEN;
        ig_md.checksum_upd_ipv4 = true; 
        hdr.amcast.command = command.START;
        hdr.amcast.app_id = 0x0;
        hdr.amcast.group_id = 0x0;
        hdr.amcast.slice_id = 0x0;
        hdr.amcast.epoch = 0x0;
        hdr.amcast.clock = 0x0;
    }

    action ingress_ports_new_msg_hit(bit<32> index) {
        set_msg_hdr(index);
        set_p4mcast_hdr();
    }

    action ingress_ports_new_msg_egress_hit(PortId_t port, bit<32> index) {
        set_msg_hdr(index);
        set_p4mcast_hdr();
        ig_tm_md.ucast_egress_port = port;
        ig_tm_md.bypass_egress = 1w1;
        exit;
    }

    action ingress_ports_l2_fwd_hit(PortId_t port) {
        ig_tm_md.ucast_egress_port = port;
    }
    
    table ingress_ports {
        key = {
            ig_intr_md.ingress_port : exact;
        }
        actions = {
            ingress_ports_new_msg_egress_hit;
            ingress_ports_new_msg_hit;
            ingress_ports_l2_fwd_hit;
            NoAction;
        }
        size = 512;
        const default_action = NoAction();
    }

    action reflect_hit(bit<16> mcast_grp) { 
        ig_tm_md.mcast_grp_a = mcast_grp;
        ig_tm_md.bypass_egress = 1w1;
        exit;
    }

    table reflect {
        key = {
            ig_intr_md.ingress_port : exact;
            hdr.amcast.group_id : exact;
        }
        actions = {
            reflect_hit;
        }
        size = 10;
    }

    // action add_bridged_md() {
    //     hdr.bridged_md.setValid();
    //     hdr.bridged_md.pkt_type = PKT_TYPE_NORMAL;
    //     hdr.bridged_md.role = ig_md.role;
    //     hdr.bridged_md.msg_id = ig_md.msg_id; 
    //     hdr.bridged_md.timestamp = ig_md.timestamp;
    //     hdr.bridged_md.group_id = ig_md.group_id;
    //     hdr.bridged_md.slice_id = ig_md.slice_id;
    //     hdr.bridged_md.fts = ig_md.fts;
    // }
    
    apply {
        // Setting up new messages headers
        if (hdr.udp.isValid()) {
            if (!hdr.msg.isValid()) {
                ingress_ports.apply();
            }  
            
            // if (hdr.amcast.command == command.PROP) {
            //     reflect.apply();
            // }
            
            slice_config.apply();
            groups_config.apply();
            msg_config.apply();
            msg_index.apply();

            if (ig_md.role == node_state.PRIMARY) {
                leader.apply(hdr, ig_md, ig_intr_md, ig_prsr_md, ig_dprsr_md, ig_tm_md);
            } else if (ig_md.role == node_state.FOLLOWER) {
                follower.apply(hdr, ig_md, ig_intr_md, ig_prsr_md, ig_dprsr_md, ig_tm_md);
            }
        }

        // add_bridged_md();
    }
}

control SwitchEgress(
        inout header_t hdr,
        inout metadata_t eg_md,
        in egress_intrinsic_metadata_t eg_intr_md,
        in egress_intrinsic_metadata_from_parser_t eg_intr_md_from_prsr,
        inout egress_intrinsic_metadata_for_deparser_t ig_intr_dprs_md,
        inout egress_intrinsic_metadata_for_output_port_t eg_intr_oport_md) {

    // action add_egress_tstamp() {
    //     hdr.e2e_delay.eg_tstamp = eg_intr_md_from_prsr.global_tstamp;
    // }

    apply {
        // if (hdr.amcast.command == command.DELIVER) {
        //     add_egress_tstamp();
        // }
    }
}

Pipeline(SwitchIngressParser(),
       SwitchIngress(),
       SwitchIngressDeparser(),
       SwitchEgressParser(),
       SwitchEgress(),
       SwitchEgressDeparser()) pipe;

Switch(pipe) main;
