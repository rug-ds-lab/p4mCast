from collections import namedtuple

class SwitchState:
    PRIMARY = 1 
    FOLLOWER = 2
    CANDIDATE = 3
    PROMISED = 4

class ProtocolCommand:
    START = 0x1 
    PROP = 0x2
    ACK   = 0x3
    BUMP  = 0x4
    NEW_EPOCH = 0x5
    PROMISE = 0x6
    NEW_STATE = 0x7
    ACCEPT = 0x8
    DELIVER = 0xff