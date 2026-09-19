#include <core.p4>
#include <tna.p4>

// ---------------------------------------------------------------------------
// Ingress parser
// ---------------------------------------------------------------------------
parser TofinoIngressParser(
        packet_in pkt,
        out ingress_intrinsic_metadata_t ig_intr_md) {
    state start {
        pkt.extract(ig_intr_md);
        transition select(ig_intr_md.resubmit_flag) {
            1 : parse_resubmit;
            0 : parse_port_metadata;
        }
    }

    state parse_resubmit {
        // Parse resubmitted packet here.
        transition reject;
    }

    state parse_port_metadata {
        pkt.advance(PORT_METADATA_SIZE);
        transition accept;
    }
}

parser SwitchIngressParser(
        packet_in pkt,
        out header_t hdr,
        out metadata_t ig_md,
        out ingress_intrinsic_metadata_t ig_intr_md) {

    TofinoIngressParser() tofino_parser;
    Checksum() ipv4_checksum;
    Checksum() udp_checksum;

    state start {
        /* Initialize Metadata to Zero */
        ig_md = {
            timestamp = 0,
            fts = 0,
            clock = 0,
            msg_id = 0,
            index = 0,
            app_id= 0,
            num_dests= 0,
            num_grps= 0,
            own_mcast_group= 0,
            mcast_group_leaders= 0,
            mcast_group_all_dests= 0,
            cur_num_grps= 0,
            quorum= 0,
            acks= 0,
            slice_id= 0, 
            leader_id= 0,
            group_id= 0,
            role= 0,  
            cur_epoch= 0,
            prom_epoch= 0,
            checksum_upd_ipv4 = false
        };
        tofino_parser.apply(pkt, ig_intr_md);
        transition parse_ethernet;
    }

    state parse_ethernet {
        pkt.extract(hdr.ethernet);
        transition select(hdr.ethernet.ether_type) {
            ETHERTYPE_IPV4 : parse_ipv4;
            default : reject;
        }
    }

    state parse_ipv4 {
        pkt.extract(hdr.ipv4);
        transition select(hdr.ipv4.protocol) {
            IP_PROTOCOLS_UDP : parse_udp;
            default : accept;
        }
    }

    state parse_udp {
        pkt.extract(hdr.udp);
        transition select(hdr.udp.dst_port) {
            P4MCAST_CTL_UDP_DST_PORT : parse_ctl_amcast;
            P4MCAST_UDP_DST_PORT : parse_amcast;
            MSG_UDP_DST_PORT : parse_msg;
            default          : accept;
        }
    }

    state parse_ctl_amcast {
        pkt.extract(hdr.amcast);
        transition accept;
    }

    state parse_amcast {
        pkt.extract(hdr.amcast);
        pkt.extract(hdr.msg);
        // pkt.extract(hdr.e2e_delay);
        transition accept;
    }

    state parse_msg {
        pkt.extract(hdr.msg);
        // pkt.extract(hdr.e2e_delay);
        transition accept;
    }
}

// ---------------------------------------------------------------------------
// Ingress Deparser
// ---------------------------------------------------------------------------
control SwitchIngressDeparser(packet_out pkt,
                              inout header_t hdr,
                              in metadata_t ig_md,
                              in ingress_intrinsic_metadata_for_deparser_t ig_dprsr_md) {

    Checksum() ipv4_checksum;

    apply {
        // Updating and checking of the checksum is done in the deparser.
        // Checksumming units are only available in the parser sections of 
        // the program.
        if (ig_md.checksum_upd_ipv4) {
            hdr.ipv4.hdr_checksum = ipv4_checksum.update(
                {hdr.ipv4.version,
                 hdr.ipv4.ihl,
                 hdr.ipv4.diffserv,
                 hdr.ipv4.total_len,
                 hdr.ipv4.identification,
                 hdr.ipv4.flags,
                 hdr.ipv4.frag_offset,
                 hdr.ipv4.ttl,
                 hdr.ipv4.protocol,
                 hdr.ipv4.src_addr,
                 hdr.ipv4.dst_addr});
        }

        pkt.emit(hdr.bridged_md);
        pkt.emit(hdr.ethernet);
        pkt.emit(hdr.ipv4);
        pkt.emit(hdr.udp);
        pkt.emit(hdr.amcast);
        pkt.emit(hdr.msg);
        // pkt.emit(hdr.e2e_delay);
    }
}

parser TofinoEgressParser(packet_in pkt,
                        out egress_intrinsic_metadata_t eg_intr_md) {
    state start {
        pkt.extract(eg_intr_md);
        transition accept;
    }
}

parser SwitchEgressParser(
        packet_in pkt,
        out header_t hdr,
        out metadata_t eg_md,
        out egress_intrinsic_metadata_t eg_intr_md) {
    
    TofinoEgressParser() tofino_parser;

    state start {
        tofino_parser.apply(pkt, eg_intr_md);
        transition parse_ethernet;
    }

    state parse_ethernet {
        pkt.extract(hdr.ethernet);
        transition select(hdr.ethernet.ether_type) {
            ETHERTYPE_IPV4 : parse_ipv4;
            default : reject;
        }
    }

    state parse_ipv4 {
        pkt.extract(hdr.ipv4);
        transition select(hdr.ipv4.protocol) {
            IP_PROTOCOLS_UDP : parse_udp;
            default : accept;
        }
    }

    state parse_udp {
        pkt.extract(hdr.udp);
        transition select(hdr.udp.dst_port) {
            P4MCAST_CTL_UDP_DST_PORT : parse_ctl_amcast;
            P4MCAST_UDP_DST_PORT : parse_amcast;
            MSG_UDP_DST_PORT : parse_msg;
            default          : accept;
        }
    }

    state parse_ctl_amcast {
        pkt.extract(hdr.amcast);
        transition accept;
    }

    state parse_amcast {
        pkt.extract(hdr.amcast);
        pkt.extract(hdr.msg);
        // pkt.extract(hdr.e2e_delay);
        transition accept;
    }

    state parse_msg {
        pkt.extract(hdr.msg);
        // pkt.extract(hdr.e2e_delay);
        transition accept;
    }
}

control SwitchEgressDeparser(
        packet_out pkt,
        inout header_t hdr,
        in metadata_t eg_md,
        in egress_intrinsic_metadata_for_deparser_t ig_intr_dprs_md) {
    apply {
        pkt.emit(hdr.ethernet);
        pkt.emit(hdr.ipv4);
        pkt.emit(hdr.udp);
        pkt.emit(hdr.amcast);
        pkt.emit(hdr.msg);
        // pkt.emit(hdr.e2e_delay);
    }
}
