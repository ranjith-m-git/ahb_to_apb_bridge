# AHB to APB Bridge

## Overview

The AHB-to-APB Bridge provides protocol conversion between the high-performance AHB bus and the low-power APB bus in an AMBA-based SoC. The bridge acts as an **AHB Slave** on the AHB side and an **APB Master** on the APB side.

This allows high-speed masters such as CPUs and DMA controllers to access low-bandwidth peripherals including GPIO, UART, SPI, I2C, Timers, and Watchdog modules through the APB bus.

---

## Features

### AHB Interface

- AHB Slave Interface
- Single Read Transfers
- Single Write Transfers
- HREADY Support
- HRESP Generation
- Address and Control Capture
- Wait-State Handling

### APB Interface

- APB Master Interface
- Read Transactions
- Write Transactions
- PREADY Support
- PSLVERR Support
- APB Setup Phase Generation
- APB Access Phase Generation

---

## AMBA Bus Architecture

```text
                +----------------+
                |   AHB Master   |
                |  CPU / DMA     |
                +--------+-------+
                         |
                         |
                  AHB Bus
                         |
                         v
                +----------------+
                | AHB-APB Bridge |
                +--------+-------+
                         |
                         |
                  APB Bus
                         |
      +--------+--------+--------+--------+
      |        |        |        |        |
      v        v        v        v        v
    UART     GPIO      SPI      I2C    TIMER
```

---

## AHB Protocol Overview

The Advanced High-performance Bus (AHB) is designed for high-bandwidth and pipelined communication.

### Key Signals

| Signal | Description |
|----------|-------------|
| HADDR | Address Bus |
| HWRITE | Read/Write Control |
| HSIZE | Transfer Size |
| HBURST | Burst Information |
| HTRANS | Transfer Type |
| HWDATA | Write Data |
| HRDATA | Read Data |
| HREADY | Transfer Completion |
| HRESP | Transfer Response |

### Transfer Types

| HTRANS | Meaning |
|---------|---------|
| IDLE | No Transfer |
| BUSY | Busy Cycle |
| NONSEQ | First Transfer |
| SEQ | Burst Transfer |

---

## APB Protocol Overview

The Advanced Peripheral Bus (APB) is optimized for low-power peripheral accesses.

### Key Signals

| Signal | Description |
|---------|-------------|
| PADDR | Address |
| PWRITE | Read/Write Control |
| PWDATA | Write Data |
| PRDATA | Read Data |
| PSEL | Slave Select |
| PENABLE | Access Enable |
| PREADY | Transfer Complete |
| PSLVERR | Error Indication |

### APB Transfer Phases

Every APB transaction consists of two phases:

#### Setup Phase

```text
PSEL    = 1
PENABLE = 0
Address and control become valid
```

#### Access Phase

```text
PSEL    = 1
PENABLE = 1
Data transfer occurs
```

Transaction completes when:

```text
PREADY = 1
```

---

## Why AHB to APB Bridge?

AHB and APB are fundamentally different protocols.

| Feature | AHB | APB |
|----------|------|------|
| Pipeline | Yes | No |
| Burst Support | Yes | No |
| Performance | High | Low |
| Complexity | High | Low |
| Multiple Masters | Supported | Not Supported |
| Power Consumption | Higher | Lower |

The bridge converts AHB transactions into APB-compatible transactions.

---

## Bridge Operation

### Write Transaction

```text
AHB Master
    |
    | Address + Control
    V
AHB-APB Bridge
    |
    | Capture Address
    | Capture Write Data
    V
APB Setup Phase
    |
    V
APB Access Phase
    |
    | Wait for PREADY
    V
Transfer Complete
```

### Read Transaction

```text
AHB Master
    |
    | Address + Control
    V
AHB-APB Bridge
    |
    | Generate APB Read
    V
APB Setup Phase
    |
    V
APB Access Phase
    |
    | Receive PRDATA
    V
Return HRDATA to AHB
```

---

## Bridge State Machine

```text
              +------+
              | IDLE |
              +---+--+
                  |
                  v
            +-----+------+
            |   SETUP    |
            +-----+------+
                  |
                  v
            +-----+------+
            |   ACCESS   |
            +-----+------+
                  |
        PREADY=0  |
        +---------+
        |
        v
      WAIT
        |
        +-----> ACCESS

        PREADY=1
             |
             v
        +----+----+
        | COMPLETE|
        +----+----+
             |
             v
           IDLE
```

---

## RTL Architecture

```text
+--------------------------------------------------+
|                  AHB TO APB BRIDGE               |
+--------------------------------------------------+
|                                                  |
|  AHB Interface                                   |
|      |                                           |
|      v                                           |
|  Address & Control Registers                     |
|      |                                           |
|      v                                           |
|  Bridge Controller FSM                           |
|      |                                           |
|      v                                           |
|  APB Interface                                   |
|                                                  |
+--------------------------------------------------+
```

---

## Verification Plan

### Functional Verification

- Single Write Transfer
- Single Read Transfer
- Back-to-Back Transfers
- APB Wait State Handling
- Error Response Handling

### Protocol Verification

#### AHB Checks

- Valid HTRANS
- HREADY Behavior
- HRESP Generation
- Address Stability

#### APB Checks

- PSEL Assertion
- PENABLE Sequencing
- PREADY Handling
- PSLVERR Handling

---

## References

1. ARM AMBA 3 APB Protocol Specification (IHI0024E)
2. ARM AMBA AHB Protocol Specification (IHI0033B)
3. ARM AMBA Architecture Specification

