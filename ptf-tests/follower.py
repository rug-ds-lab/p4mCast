import logging

from ptf import config
import ptf.testutils as testutils
from ptf.mask import *
from bfruntime_client_base_tests import BfRuntimeTest
from p4testutils.misc_utils import *
import bfrt_grpc.bfruntime_pb2 as bfruntime_pb2
import bfrt_grpc.client as gc
import random
import time

from lib.Interface import *

# from scapy.all import sendp, send, get_if_list, get_if_hwaddr
from scapy.all import Packet
from scapy.all import Ether, IP, UDP, Raw

from lib.P4mcastPacket import *
from lib.types import *

logger = get_logger()
swports = get_sw_ports()

num_pipes = int(testutils.test_param_get('num_pipes'))
pipes = list(range(num_pipes))

# Hitless HA Support
client_id = 0
p4_name = "p4mcast"
profile_name = 'pipe'
base_pick_path = testutils.test_param_get("base_pick_path")
base_put_path = testutils.test_param_get("base_put_path")
arch = testutils.test_param_get("arch")
if not base_pick_path:
  base_pick_path = "install/share/" + arch + "pd/"
if not base_put_path:
  base_put_path = "/tmp"

hdrs = Ether(src='00:11:22:33:44:55', dst='00:22:33:44:55:66')/IP(src="16.0.0.1",dst="48.0.0.1")/UDP(dport=12,sport=1025)
exp_hdrs = Ether(src='00:11:22:33:44:55', dst='00:22:33:44:55:66')/IP(src="16.0.0.1",dst="48.0.0.1")/UDP(dport=P4MCAST_UDP_DST_PORT,sport=1025)

port1=1
port2=2
port3=3
port4=4
ownGroupID=1
AllDestsGroupID=3
numGroups=3
Quorum=2

# test scenario
# 3 groups of 3 members each ==> 1 leader + 2 followers
def follower_add_config(self):
    self.msg_index_table_add_with_msg_index_hit(slice_id=2, msg_id=1 , index=0)
    # self.ingress_ports_table_add_with_ingress_ports_new_msg_hit(ig_port_id=port1, index=0)
    self.slice_config_table_add_with_slice_config_hit(port_id=port1, app_id=0, slice_id=2, role=SwitchState.FOLLOWER, group_id=1, leader_id=1, epoch=1)
    self.groups_config_table_add_with_groups_config_hit(group_id=1, mcast_grp=ownGroupID, quorum=Quorum)
    # self.msg_config_table_add_with_msg_config_hit(msg_id=1, mcast_group_all_dests=AllDestsGroupID, num_grps=2)
    # self.forward_to_replicas_table_add_with_forward_to_replicas_hit(slice_id=1, mcast_grp=7)

    self.mc_mgrp_create(mcast_grp=ownGroupID)
    self.mc_node_create(node_id=1, rid=1, mbr_ports=[3], mbr_lags=[])
    self.mc_associate_node(mcast_grp=ownGroupID, node_id=1, xid=1)
    self.mc_node_create(node_id=2, rid=2, mbr_ports=[4], mbr_lags=[])
    self.mc_associate_node(mcast_grp=ownGroupID, node_id=2, xid=1)

    # self.mc_mgrp_create(mcast_grp=AllDestsGroupID)
    # self.mc_node_create(node_id=3, rid=3, mbr_ports=[5], mbr_lags=[])
    # self.mc_associate_node(mcast_grp=AllDestsGroupID, node_id=3, xid=1)
    # self.mc_node_create(node_id=4, rid=4, mbr_ports=[6], mbr_lags=[])
    # self.mc_associate_node(mcast_grp=AllDestsGroupID, node_id=4, xid=1)

def follower_del_config(self):
    # Clean up
    self.mc_dissociate_node(mgid=ownGroupID, node_id=1)
    self.mc_dissociate_node(mgid=ownGroupID, node_id=2)
    self.mc_mgrp_delete(mgid=ownGroupID)

    # self.mc_dissociate_node(mgid=AllDestsGroupID, node_id=3)
    # self.mc_dissociate_node(mgid=AllDestsGroupID, node_id=4)
    # self.mc_mgrp_delete(mgid=AllDestsGroupID)


class PropFromOwnLeaderToAck(Interface):
    def setUp(self):
        Interface.setUp(self)

    def runTest(self):
        follower_add_config(self)
        pkt = exp_hdrs/P4mcast(command=ProtocolCommand.PROP,app_id=0,group_id=1,slice_id=1,epoch=1)/Msg(msg_id=1,timestamp=12)/(20*'x')
        print("Sending %d PROP packet on port %d" % (1, port1))
        send_packet(self, port_id=port1, pkt=pkt, count=1)

        ack_pkt = exp_hdrs/P4mcast(command=ProtocolCommand.ACK,app_id=0,group_id=1,slice_id=2,epoch=1)/Msg(msg_id=1,timestamp=12)/(20*'x') 
        masked_ack_pkt = Mask(ack_pkt)
        masked_ack_pkt.set_do_not_care_scapy(UDP, 'chksum')
        # masked_ack_pkt.set_do_not_care_scapy(E2eDelay, 'ig_tstamp')
        # masked_ack_pkt.set_do_not_care_scapy(E2eDelay, 'eg_tstamp')
        print("Expecting %d packet on ports %d and %d " % (2, 3, 4))
        verify_packets(self, masked_ack_pkt, ports=[3, 4])

    def tearDown(self):
        follower_del_config(self)
        Interface.tearDown(self)

class PropFromOtherLeaderBumpClockThenDrop(Interface):
    def setUp(self):
        Interface.setUp(self)

    def runTest(self):
        follower_add_config(self)
        pkt = exp_hdrs/P4mcast(command=ProtocolCommand.PROP,app_id=0,group_id=2,slice_id=1,epoch=1)/Msg(msg_id=1,timestamp=14)/(20*'x')
        print("Sending %d PROP packet on port %d" % (1, port1))
        send_packet(self, port_id=port1, pkt=pkt, count=1)

        print("Expecting no packets")
        verify_no_other_packets(self)

    def tearDown(self):
        follower_del_config(self)
        Interface.tearDown(self)

class RegularAckDrop(Interface):
    def setUp(self):
        Interface.setUp(self)

    def runTest(self):
        follower_add_config(self)

        pkt = exp_hdrs/P4mcast(command=ProtocolCommand.ACK,app_id=0,group_id=1,slice_id=5,epoch=1)/Msg(msg_id=1,timestamp=2)/(20*'x')
        print("Sending %d ACK packet on port %d" % (1, port1))
        send_packet(self, port_id=port1, pkt=pkt, count=1)

        print("Expecting no packets")
        verify_no_other_packets(self)

    def tearDown(self):
        follower_del_config(self)
        Interface.tearDown(self)

class AnotherPropAckToDeliver(Interface):
    def setUp(self):
        Interface.setUp(self)

    def runTest(self):
        follower_add_config(self)

        pkt = exp_hdrs/P4mcast(command=ProtocolCommand.ACK,app_id=0,group_id=1,slice_id=4,epoch=1)/Msg(msg_id=1,timestamp=12)/(20*'x')
        print("Sending  %d ACK packet on port %d" % (1, port1))
        send_packet(self, port_id=port1, pkt=pkt, count=1)

        print("Expecting no packets")
        verify_no_other_packets(self)

        pkt = exp_hdrs/P4mcast(command=ProtocolCommand.PROP,app_id=0,group_id=3,slice_id=1,epoch=1)/Msg(msg_id=1,timestamp=10)/(20*'x')
        print("Sending %d PROP packet on port %d" % (1, port1))
        send_packet(self, port_id=port1, pkt=pkt, count=1)
    
        exp_port = 3
        exp_pkt = exp_hdrs/P4mcast(command=ProtocolCommand.DELIVER,app_id=0,group_id=1,slice_id=2,epoch=1)/Msg(msg_id=1,timestamp=14)/(20*'x') 
        masked_exp_pkt = Mask(exp_pkt)
        masked_exp_pkt.set_do_not_care_scapy(UDP, 'chksum') # mask out srcPort
        # masked_exp_pkt.set_do_not_care_scapy(E2eDelay, 'ig_tstamp')
        # masked_exp_pkt.set_do_not_care_scapy(E2eDelay, 'eg_tstamp')
        # print("Expecting %d packet on port %d" % (1, exp_port))
        # verify_packets(self, masked_exp_pkt, ports=[exp_port])
        verify_no_other_packets(self)

    def tearDown(self):
        follower_del_config(self)
        Interface.tearDown(self)
