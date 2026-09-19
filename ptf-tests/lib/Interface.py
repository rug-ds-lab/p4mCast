import logging

from ptf import config
import ptf.testutils as testutils
from bfruntime_client_base_tests import BfRuntimeTest
import bfrt_grpc.bfruntime_pb2 as bfruntime_pb2
import bfrt_grpc.client as gc
import random
import time

num_pipes = int(testutils.test_param_get('num_pipes'))
pipes = list(range(num_pipes))

# Hitless HA Support
client_id = 0
p4_name = "p4mcast"
profile_name = 'pipe'
base_pick_path = testutils.test_param_get("base_pick_path")
base_put_path = testutils.test_param_get("base_put_path")
arch = testutils.test_param_get("arch")
testutils.test_param_get("arch") == "tofino"
if not base_pick_path:
  base_pick_path = "install/share/" + arch + "pd/"
if not base_put_path:
  base_put_path = "/tmp"

class Interface(BfRuntimeTest):
    def setUp(self):
        client_id = 0
        p4_name = "p4mcast"
        BfRuntimeTest.setUp(self, client_id, p4_name)
        self.bfrt_info = self.interface.bfrt_info_get(p4_name)
        self.target = gc.Target(device_id=0, pipe_id=0xffff)


    def ingress_ports_table_add_with_ingress_ports_new_msg_egress_hit(self, ig_port_id, eg_port_id, index):
        print("Adding Ingress Port ID %d ==> Message ID in Reg Index %d to Egress Port ID %d" % (ig_port_id, index, eg_port_id))
        ingress_ports_table = self.bfrt_info.table_get("SwitchIngress.ingress_ports")
        key = ingress_ports_table.make_key([gc.KeyTuple('ig_intr_md.ingress_port', ig_port_id)])
        data = ingress_ports_table.make_data([gc.DataTuple('port', eg_port_id),
                                              gc.DataTuple('index', index)],
                                             'SwitchIngress.ingress_ports_new_msg_egress_hit')
        ingress_ports_table.entry_add(self.target, [key], [data])

    def ingress_ports_table_add_with_ingress_ports_new_msg_hit(self, ig_port_id, index):
        print("Adding Ingress Port ID %d" % (ig_port_id))
        ingress_ports_table = self.bfrt_info.table_get("SwitchIngress.ingress_ports")
        key = ingress_ports_table.make_key([gc.KeyTuple('ig_intr_md.ingress_port', ig_port_id)])
        data = ingress_ports_table.make_data([gc.DataTuple('index', index)],'SwitchIngress.ingress_ports_new_msg_hit')
        ingress_ports_table.entry_add(self.target, [key], [data])

    def slice_config_table_add_with_slice_config_hit(self, port_id, app_id, slice_id, role, group_id, leader_id, epoch):
        print("Slice Configuration: PortID %d, AppID %d ==> SliceID %d, Role %d, GroupID %d, LeaderID %d, Epoch %d" % (port_id, app_id, slice_id, role, group_id, leader_id, epoch))
        slice_config_table = self.bfrt_info.table_get("SwitchIngress.slice_config")
        key = slice_config_table.make_key([gc.KeyTuple('ig_intr_md.ingress_port', port_id),
                                          gc.KeyTuple('hdr.amcast.app_id', app_id)])
        data = slice_config_table.make_data([gc.DataTuple('slice_id', slice_id),
                                        gc.DataTuple('role', role),
                                        gc.DataTuple('group_id', group_id),
                                        gc.DataTuple('leader_id', leader_id),
                                        gc.DataTuple('epoch', epoch)],
                                        'SwitchIngress.slice_config_hit')
        slice_config_table.entry_add(self.target, [key], [data])

    def msg_index_table_add_with_msg_index_hit(self, slice_id, msg_id, index):
        print("Message ID per Slice Configuration: SliceID %d, MsgID %d ==> Index %d" % (slice_id, msg_id, index))
        msg_index_table = self.bfrt_info.table_get("SwitchIngress.msg_index")
        key = msg_index_table.make_key([gc.KeyTuple('ig_md.slice_id', slice_id),
                                          gc.KeyTuple('hdr.msg.msg_id', msg_id)])
        data = msg_index_table.make_data([gc.DataTuple('index', index)],
                                        'SwitchIngress.msg_index_hit')
        msg_index_table.entry_add(self.target, [key], [data])

    def reflect_table_add_with_reflect_hit(self, port_id, group_id, mcast_grp):
        print("Slice Configuration: PortID %d, GroupID %d ==> Mcast Group ID %d" % (port_id, group_id, mcast_grp))
        reflect_table = self.bfrt_info.table_get("SwitchIngress.reflect")
        key = reflect_table.make_key([gc.KeyTuple('ig_intr_md.ingress_port', port_id),
                                          gc.KeyTuple('hdr.amcast.group_id', group_id)])
        data = reflect_table.make_data([gc.DataTuple('mcast_grp', mcast_grp)],
                                        'SwitchIngress.reflect_hit')
        reflect_table.entry_add(self.target, [key], [data])


    def msg_config_table_add_with_msg_config_hit(self, msg_id, mcast_group_all_dests, num_grps):
    # def msg_config_table_add_with_msg_config_hit(self, port_id, mcast_grp, num_grps):
        print("Adding msgID: %d ==> All Dests MCast Group ID: %d, Number Groups: %d" % (msg_id, mcast_group_all_dests, num_grps))
        # print(" Msg arriving at Ingress Port: %d ==> MCast Group ID: %d, Number Dests: %d" % (port_id, mcast_grp, num_grps))
        msg_config_table = self.bfrt_info.table_get("SwitchIngress.msg_config")
        key = msg_config_table.make_key([gc.KeyTuple('hdr.msg.msg_id', msg_id)])
        # key = msg_config_table.make_key([gc.KeyTuple('ig_intr_md.ingress_port', port_id)])
        data = msg_config_table.make_data([gc.DataTuple('mcast_group_all_dests', mcast_group_all_dests),
                                        gc.DataTuple('num_grps', num_grps)],
                                        'SwitchIngress.msg_config_hit')
        msg_config_table.entry_add(self.target, [key], [data])

    def groups_config_table_add_with_groups_config_hit(self, group_id, mcast_grp, quorum):
        print("Adding groupID: %d ==> MCast Group ID: %d, Quorum: %d" % (group_id, mcast_grp, quorum))
        groups_config_table = self.bfrt_info.table_get("SwitchIngress.groups_config")
        key = groups_config_table.make_key([gc.KeyTuple('ig_md.group_id', group_id)])
        data = groups_config_table.make_data([gc.DataTuple('mcast_grp', mcast_grp),
                                        gc.DataTuple('quorum', quorum)],
                                        'SwitchIngress.groups_config_hit')
        groups_config_table.entry_add(self.target, [key], [data])

    def forward_to_replicas_table_add_with_forward_to_replicas_hit(self, slice_id, mcast_grp):
        print(" SliceID: %d  ==> Replica mcastGroupID: %d" % (slice_id, mcast_grp))
        forward_to_replicas_table = self.bfrt_info.table_get("SwitchIngress.leader.forward_to_replicas")
        key = forward_to_replicas_table.make_key([gc.KeyTuple('hdr.amcast.slice_id', slice_id)])
        data = forward_to_replicas_table.make_data([gc.DataTuple('mcast_grp', mcast_grp)],
                                        'SwitchIngress.leader.forward_to_replicas_hit')
        forward_to_replicas_table.entry_add(self.target, [key], [data])

    def mirror_cfg_table_add_session_port(self, sid, port):
        print("Mirror Config - using session: %d for Egress Port: %d" % (sid, port))
        mirror_cfg_table = self.bfrt_info.table_get("$mirror.cfg")
        mirror_cfg_table.entry_add(self.target,
                    [mirror_cfg_table.make_key([gc.KeyTuple('$sid', sid)])],
                    [mirror_cfg_table.make_data([gc.DataTuple('$direction', str_val="INGRESS"),
                            gc.DataTuple('$ucast_egress_port', port),
                            gc.DataTuple('$ucast_egress_port_valid', bool_val=True),
                            gc.DataTuple('$session_enable', bool_val=True)],
                        '$normal')])

    def mirror_cfg_table_delete_session(self, sid):
        print("Mirror Config - deleting session %d " % sid) 
        mirror_cfg_table = self.bfrt_info.table_get("$mirror.cfg")
        mirror_cfg_table.entry_del(self.target,
                    [mirror_cfg_table.make_key([gc.KeyTuple('$sid', sid)])])

    def mc_mgrp_create(self, mcast_grp):
        print("Creating Mcast Group ID: %d " %  mcast_grp)
        self.mgid_table = self.bfrt_info.table_get("$pre.mgid")

        self.mgid_table.entry_add(
            self.target,
            [self.mgid_table.make_key([gc.KeyTuple('$MGID', mcast_grp)])])

    def mc_node_create(self, node_id, rid, mbr_ports, mbr_lags):
        print("Creating Mcast Node ID: %d " %  node_id)
        self.node_table = self.bfrt_info.table_get("$pre.node")

        self.node_table.entry_add(
            self.target,
            [self.node_table.make_key([gc.KeyTuple('$MULTICAST_NODE_ID', node_id)])],
            [self.node_table.make_data([gc.DataTuple('$MULTICAST_RID', rid),
                                                  gc.DataTuple('$MULTICAST_LAG_ID', int_arr_val=mbr_lags),
                                                  gc.DataTuple('$DEV_PORT', int_arr_val=mbr_ports)])])

    def mc_associate_node(self, mcast_grp, node_id, xid):
        if xid is None:
            xid = 0
            use_xid = 0
        else:
            use_xid = 1

        self.mgid_table.entry_mod_inc(
            self.target,
            [self.mgid_table.make_key([gc.KeyTuple('$MGID', mcast_grp)])],
            [self.mgid_table.make_data([
                gc.DataTuple('$MULTICAST_NODE_ID', int_arr_val=[node_id]),
                gc.DataTuple('$MULTICAST_NODE_L1_XID_VALID', bool_arr_val=[use_xid]),
                gc.DataTuple('$MULTICAST_NODE_L1_XID', int_arr_val=[xid])])],
            bfruntime_pb2.TableModIncFlag.MOD_INC_ADD)

    def mc_dissociate_node(self, mgid, node_id):
        self.mgid_table.entry_mod_inc(
                self.target,
                [self.mgid_table.make_key([gc.KeyTuple('$MGID', mgid)])],
                [self.mgid_table.make_data([gc.DataTuple('$MULTICAST_NODE_ID', int_arr_val=[node_id]),
                                                      gc.DataTuple('$MULTICAST_NODE_L1_XID_VALID',
                                                                       bool_arr_val=[0]),
                                                      gc.DataTuple('$MULTICAST_NODE_L1_XID', int_arr_val=[0])])],
                bfruntime_pb2.TableModIncFlag.MOD_INC_DELETE)

        self.node_table.entry_del(
            self.target,
            [self.node_table.make_key([gc.KeyTuple('$MULTICAST_NODE_ID', node_id)])])

    def mc_mgrp_delete(self, mgid):
        self.mgid_table.entry_del(
                self.target,
                [self.mgid_table.make_key([gc.KeyTuple('$MGID', mgid)])])
        
    def tearDown(self):
        # time.sleep(1)
        msg_index_table = self.bfrt_info.table_get("SwitchIngress.msg_index")
        # reflect_table = self.bfrt_info.table_get("SwitchIngress.reflect")
        ingress_ports_table = self.bfrt_info.table_get("SwitchIngress.ingress_ports")
        slice_config_table = self.bfrt_info.table_get("SwitchIngress.slice_config")
        msg_config_table = self.bfrt_info.table_get("SwitchIngress.msg_config")
        groups_config_table = self.bfrt_info.table_get("SwitchIngress.groups_config")
        forward_to_replicas_table = self.bfrt_info.table_get("SwitchIngress.leader.forward_to_replicas")
        
        # Clean up
        msg_index_table.entry_del(self.target, [])
        # reflect_table.entry_del(self.target, [])
        ingress_ports_table.entry_del(self.target, [])
        slice_config_table.entry_del(self.target, [])
        groups_config_table.entry_del(self.target, [])
        msg_config_table.entry_del(self.target, [])
        forward_to_replicas_table.entry_del(self.target, [])

        BfRuntimeTest.tearDown(self)
        