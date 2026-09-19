struct metadata_t {
    timestamp_t timestamp;
    timestamp_t fts;
    timestamp_t clock;
    bit<32> msg_id;
    bit<32> index;
    AppId_t app_id;
    bit<16> num_dests;
    bit<16> num_grps;
    bit<16> own_mcast_group;
    bit<16> mcast_group_leaders;
    bit<16> mcast_group_all_dests;
    bit<16> cur_num_grps;
    bit<16> quorum;
    bit<16> acks;
    SliceId_t slice_id; 
    SliceId_t leader_id;
    GroupId_t group_id;
    bit<8>  role;  // Primary, Follower, Candidate, Promised.
    bit<8>  cur_epoch;
    bit<8>  prom_epoch;
    bool checksum_upd_ipv4;
}

// 14 Bytes
header ethernet_h {
    mac_addr_t dst_addr;
    mac_addr_t src_addr;
    bit<16> ether_type;
}

// 20 Bytes
header ipv4_h {
    bit<4> version;
    bit<4> ihl;
    bit<8> diffserv;
    bit<16> total_len;
    bit<16> identification;
    bit<3> flags;
    bit<13> frag_offset;
    bit<8> ttl;
    bit<8> protocol;
    bit<16> hdr_checksum;
    ipv4_addr_t src_addr;
    ipv4_addr_t dst_addr;
}

// 8 Bytes
header udp_h {
    bit<16> src_port;
    bit<16> dst_port;
    bit<16> hdr_length;
    bit<16> checksum;
}

// 14 Bytes
header p4mcast_h {
    AppId_t app_id;
    GroupId_t group_id;
    SliceId_t slice_id; // process_id in primcast
    bit<8>  command;  // Start, Ack, Deliver, Bump, New epoch, Promise, New State, Accept
    bit<8>  epoch;
    bit<32> clock;
}

// 8 Bytes
header message_h {
    bit<32> msg_id;
    timestamp_t timestamp;
}

// 12 Bytes
// header latency_h {
//     mac_addr_t ig_tstamp;
//     mac_addr_t eg_tstamp;
// }

// <mirror_h>(ig_md.ing_mir_ses, {ig_md.pkt_type});
header mirror_h {
    pkt_type_t pkt_type;
    bit<8> role;
    bit<32> msg_id;
    timestamp_t timestamp;
    GroupId_t group_id;
    SliceId_t slice_id;
    timestamp_t fts;
}

header bridged_metadata_h {
    pkt_type_t pkt_type;
    bit<8> role;
    bit<32> msg_id;
    timestamp_t timestamp;
    GroupId_t group_id;
    SliceId_t slice_id;
    timestamp_t fts;
}

struct header_t {
    bridged_metadata_h bridged_md;
    ethernet_h ethernet;
    ipv4_h ipv4;
    udp_h udp;
    p4mcast_h amcast;
    message_h msg;
    // latency_h e2e_delay;
}
