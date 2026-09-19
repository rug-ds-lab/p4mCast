import sys

from ptf.testutils import *
import ptf.dataplane as dataplane

from scapy.all import *

try:
    import scapy.config
    import scapy.route
    import scapy.layers.l2
    import scapy.layers.inet
    import scapy.main
    from scapy.all import Packet
except ImportError:
    sys.exit("Need to install scapy for packet parsing")

P4MCAST_CTL_UDP_DST_PORT = 0x3D3D
P4MCAST_UDP_DST_PORT = 0x2E2E
MSG_UDP_DST_PORT = 0x1F1F

class P4mcast(Packet):
    name = "P4mcastHeader"
    fields_desc = [
        BitField("app_id", 0, 16),
        BitField("group_id", 0, 16),
        BitField("slice_id", 0, 32),
        BitField("command", 0, 8),
        BitField("epoch", 0, 8),
        BitField("clock", 0, 32)
    ]

class Msg(Packet):
    name = "MessageHeader"
    fields_desc = [
        BitField("msg_id", 0, 32),
        BitField("timestamp", 0, 32)
    ]

class E2eDelay(Packet):
    name = "LatencyHeader"
    fields_desc = [
        BitField("ig_tstamp", 0, 48),
        BitField("eg_tstamp", 0, 48)
    ]
