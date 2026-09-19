typedef bit<48> mac_addr_t;
typedef bit<32> ipv4_addr_t;
typedef bit<32> timestamp_t;
typedef bit<16> ether_type_t;
typedef bit<16> AppId_t;
typedef bit<16> GroupId_t;
typedef bit<32> SliceId_t;
typedef bit<8>  ip_protocol_t;
typedef bit<8> pkt_type_t;
typedef bit<3> mirror_type_t;

const bit<16> P4MCAST_MSG_HDR_LEN = 22;
const ether_type_t ETHERTYPE_IPV4 = 16w0x0800;
const ip_protocol_t IP_PROTOCOLS_UDP = 17;
const bit<16> P4MCAST_CTL_UDP_DST_PORT = 0x3D3D;
const bit<16> P4MCAST_UDP_DST_PORT = 0x2E2E;
const bit<16> MSG_UDP_DST_PORT = 0x1F1F;
const mirror_type_t MIRROR_TYPE_I2E = 1;
const pkt_type_t PKT_TYPE_NORMAL = 1;
const pkt_type_t PKT_TYPE_MIRROR = 2;
const PortId_t CPU_PORT_ID = 33;

const PortId_t RECIRC_PORT = 68;

enum bit<8> command {
    START = 8w0x01,
    PROP = 8w0x02,
    ACK = 8w0x03,
    // BUMP = 8w0x04,
    // NEW_EPOCH = 8w0x05,
    // PROMISE = 8w0x6,
    // NEW_STATE = 8w0x07,
    // ACCEPT = 8w0x08,
    DELIVER = 8w0xff
}

enum bit<8> node_state {
    PRIMARY = 8w0x01, 
    FOLLOWER = 8w0x02,
    CANDIDATE = 8w0x03,
    PROMISED = 8w0x04
}
