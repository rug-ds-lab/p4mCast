# P4mCast (2025 IEEE 45th International Conference on Distributed Computing Systems Workshops) 

This repository contains the source code and experimental scripts for P4mCast a specialized protocol for In-network Atomic Multicast Acceleration using programmable packet processors.

---

## Hardware & Software Requirements

* **Target:** Intel Tofino 1 ASIC (or Tofino Model simulator)
* **SDK:** Intel Barefoot SDE v9.13.4
* **Traffic Generation:** TRex / P4 Packet Generator
* **Testing Framework:** Python 3.8+, PTF, Scapy

---

## Reproduction Workflow

# 1. Build P4 Pipeline
```
./scripts/build.sh
```

# 2. Environment Setup
```
./scripts/setup.sh
```

# 3. Run Test Suite
```
./scripts/run_tofino_model.sh   # Terminal 1
./scripts/run_app.sh            # Terminal 2
./scripts/run_ptf_tests.sh      # Terminal 3
```

---

## Citation

If you use `P4mCast` in your research, please cite **Chapter 5** of the doctoral dissertation:

```bibtex
@phdthesis{boughzala2026accelerating,
  author  = {Bochra Boughzala},
  title   = {Accelerating Real-Time Data-Analytics with In-Network Computing: Programmable Packet Processors for Enhancing the Efficiency of Distributed Stream Processing},
  school  = {University of Groningen},
  year    = {2026},
  note    = {Chapter 5: P4mCast}
}
```

You can also cite the accompanying conference workshop paper:

```bibtex
@inproceedings{boughzala2025p4mcast,
  author    = {Boughzala, B. and Koldehofe, B. and Lazovik, A.},
  title     = {P4mCast: Accelerating and Scaling Fault-Tolerant Atomic Multicast in Multi-Cloud Environment},
  booktitle = {2025 IEEE 45th International Conference on Distributed Computing Systems Workshops (ICDCSW)},
  pages     = {159--164},
  year      = {2025},
  doi       = {10.1109/ICDCSW63273.2025.00033}
}
```