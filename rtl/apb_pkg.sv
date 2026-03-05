//============================================================
// Package : apb_pkg
// Desc    : AMBA APB protocol type definitions
//
// Notes:
//   - APB is simple, non-pipelined
//   - Single master, multiple slaves via decoder
//   - Used for low-speed peripherals
//============================================================

package apb_pkg;
  
  import ahb_to_apb_bridge_common_pkg::*;

  //--------------------------------------------------
  // GLOBAL CONFIGURATION
  //--------------------------------------------------
  localparam int USER_REQ_WIDTH  = 128;
  localparam int USER_RESP_WIDTH = 16;
  localparam int USER_DATA_WIDTH = DATA_WIDTH/2;

  //--------------------------------------------------
  // APB RESPONSE
  //--------------------------------------------------
  // APB supports only OKAY / ERROR
  typedef enum logic {
      APB_OKAY  = 1'b0,
      APB_ERROR = 1'b1
  } apb_resp_e;

  // ===============================
  // APB REQUEST (Master → Slave)
  // ===============================

  typedef struct packed {

      logic [ADDR_WIDTH-1:0] paddr;
      // Address of the transfer

      logic                  psel;
      // Slave select
      // Asserted during SETUP and ACCESS phases

      logic                  penable;
      // Indicates ACCESS phase
      // SETUP  : psel=1, penable=0
      // ACCESS : psel=1, penable=1

      logic                  pwrite;
      // 1 = write, 0 = read

      logic [DATA_WIDTH-1:0] pwdata;
      // Write data (valid during ACCESS phase)

      logic [2:0]            pprot;
      // Protection attributes:
      // [0] Privileged / User
      // [1] Secure / Non-secure
      // [2] Instruction / Data

      logic [(DATA_WIDTH/8)-1:0] pstrb;
      
      logic [USER_REQ_WIDTH-1:0]  pauser;
      logic [USER_DATA_WIDTH-1:0] pwuser;
      logic [USER_DATA_WIDTH-1:0] pruser;
      logic [USER_RESP_WIDTH-1:0] pbuser;

      logic                     pwakeup;

  } apb_req_t;

  // ===============================
  // APB RESPONSE (Slave → Master)
  // ===============================

  typedef struct packed {

      logic [DATA_WIDTH-1:0] prdata;
      // Read data from slave

      logic                  pready;
      // Slave ready
      // When LOW, ACCESS phase is extended

      apb_resp_e             pslverr;
      // Error response
      // Sampled when PREADY is HIGH

  } apb_rsp_t;

  //--------------------------------------------------
  // DEFAULT VALUES (VERY IMPORTANT)
  //--------------------------------------------------

  // Idle request
  localparam apb_req_t APB_REQ_DEFAULT = '{
      paddr   : '0,
      psel    : 1'b0,
      penable : 1'b0,
      pwrite  : 1'b0,
      pwdata  : '0,
      pprot   : '0,
      pstrb   : '0,
      pauser  : '0,   
      pwuser  : '0,
      pruser  : '0,
      pbuser  : '0,
      pwakeup : 1'b0
  };

  // Ready + OKAY response
  localparam apb_rsp_t APB_RSP_DEFAULT = '{
      prdata  : '0,
      pready  : 1'b0,     // Critical: prevents deadlock
      pslverr : APB_OKAY
  };

endpackage
