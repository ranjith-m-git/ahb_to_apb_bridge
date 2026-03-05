package ahb_pkg;
   
   import ahb_to_apb_bridge_common_pkg::*;

  //==================================================
  // GLOBAL CONFIG
  //==================================================
  localparam int MASTER_WIDTH    = 1; // up to 16 masters

  //==================================================
  // COMMON ENUMS
  //==================================================

  typedef enum logic [1:0] {
      HTRANS_IDLE   = 2'b00,
      HTRANS_BUSY   = 2'b01,
      HTRANS_NONSEQ = 2'b10,
      HTRANS_SEQ    = 2'b11
  } htrans_e;

  typedef enum logic [2:0] {
      HBURST_SINGLE = 3'b000,
      HBURST_INCR   = 3'b001,
      HBURST_WRAP4  = 3'b010,
      HBURST_INCR4  = 3'b011,
      HBURST_WRAP8  = 3'b100,
      HBURST_INCR8  = 3'b101,
      HBURST_WRAP16 = 3'b110,
      HBURST_INCR16 = 3'b111
  } hburst_e;
 
  typedef enum logic {
      HRESP_OKAY  = 1'b0,
      HRESP_ERROR = 1'b1
  } ahb_hresp_e;

  //==================================================
  // FULL AHB : FABRIC → SLAVE
  //==================================================

  typedef struct packed {

      logic                     hsel;
      logic                     hready;

      logic [ADDR_WIDTH-1:0]    haddr;
      htrans_e                  htrans;
      hburst_e                  hburst;

      logic [2:0]               hsize;
      logic                     hwrite;
      logic [3:0]               hprot;

      logic                     hmastlock;
      logic [MASTER_WIDTH-1:0]  hmaster;

      logic [DATA_WIDTH-1:0]    hwdata;

      //---------------- AMBA5 OPTIONAL ----------------
      //logic                 hnonsec;
      //logic                 hexcl;

  } ahb_slave_req_t;


  typedef struct packed {

      logic [DATA_WIDTH-1:0] hrdata;
      ahb_hresp_e       hresp;

      logic             hreadyout;

      //---------------- AMBA5 OPTIONAL ----------------
      //logic           hexokay;

  } ahb_slave_rsp_t;

  localparam ahb_slave_req_t AHB_SLAVE_REQ_DEFAULT = '{
    hsel      : 1'b0,
    hready    : 1'b0,

    haddr     : '0,
    htrans    : HTRANS_IDLE,
    hburst    : HBURST_SINGLE,

    hsize     : 3'b000,          // default 32-bit word
    hwrite    : 1'b0,
    hprot     : 4'b0000,         // typical default: data, privileged, non-bufferable, non-cacheable

    hmastlock : 1'b0,
    hmaster   : '0,

    hwdata    : '0
  };

  localparam ahb_slave_rsp_t AHB_SLAVE_RSP_DEFAULT = '{
    hrdata    : '0,
    hresp     : HRESP_OKAY,
    hreadyout : 1'b0
  };

endpackage : ahb_pkg
