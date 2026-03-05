//============================================================
// AHB-Lite to APB Bridge
//============================================================
//
// Purpose
// --------
// Converts AHB-Lite transactions into APB transactions.
//
// AHB characteristics
// - Pipelined bus
// - Address phase + data phase
//
// APB characteristics
// - Non-pipelined
// - Two phase protocol
//     1. SETUP  (PSEL=1 PENABLE=0)
//     2. ACCESS (PSEL=1 PENABLE=1)
//
// Therefore the bridge:
// 1. Captures AHB address/control
// 2. Generates APB setup phase
// 3. Waits for APB completion
// 4. Returns response to AHB
//
//============================================================

module ahb_to_apb_bridge_top
  import ahb_to_apb_bridge_common_pkg::*;
  import apb_pkg::*;
  import ahb_pkg::*;
(
    input  logic           clk_i,
    input  logic           rst_ni,

    //========================
    // AHB Slave Interface
    //========================
    input  ahb_slave_req_t ahb_i,
    output ahb_slave_rsp_t ahb_o,

    //========================
    // APB Master Interface
    //========================
    input  apb_rsp_t       apb_i,
    output apb_req_t       apb_o,

    // FSM debug indicator
    output logic           fsm_err_o
);

//////////////////////////////////////////////////////////////
// Internal Registers
//////////////////////////////////////////////////////////////

// Latched AHB address
logic [ADDR_WIDTH-1:0] addr_d, addr_q;

// Latched write data
logic [DATA_WIDTH-1:0] wdata_d, wdata_q;

// Latched read data from APB
logic [DATA_WIDTH-1:0] rdata_d, rdata_q;

// Protection attributes
logic [2:0] prot_d, prot_q;

// Write strobe derived from HSIZE + HADDR
logic [(DATA_WIDTH/8)-1:0] strb_d, strb_q;

// Error tracking
logic hresp_err_d;
logic hresp_readyhigh_err;

//////////////////////////////////////////////////////////////
// Address lane calculation
//////////////////////////////////////////////////////////////

// Example: DATA_WIDTH = 32
// BYTES = 4
localparam int BYTES    = DATA_WIDTH/8;

// Number of address bits used for byte lane selection
localparam int LSB_BITS = $clog2(BYTES);

// Select byte lane inside the data bus
logic [LSB_BITS-1:0] lane;

assign lane = ahb_i.haddr[LSB_BITS-1:0];

//////////////////////////////////////////////////////////////
// FSM State Definitions
//////////////////////////////////////////////////////////////

// FSM states controlling AHB→APB translation
typedef enum logic [2:0] {

    ResetSt,        // Reset state
    IdleSt,         // Wait for AHB transfer

    WriteSetupSt,   // APB SETUP phase for write
    WriteWaitSt,    // Wait for AHB write data phase
    WriteAccessSt,  // APB ACCESS phase

    ReadSetupSt,    // APB SETUP phase for read
    ReadAccessSt,   // APB ACCESS phase

    HrespErrSt      // AHB error response state

} state_e;

state_e state_d, state_q;

//////////////////////////////////////////////////////////////
// FSM State Register
//////////////////////////////////////////////////////////////

always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni)
        state_q <= ResetSt;
    else
        state_q <= state_d;
end

//////////////////////////////////////////////////////////////
// Next-State + Output Logic
//////////////////////////////////////////////////////////////

always_comb begin

    //----------------------------------------
    // Default assignments
    //----------------------------------------

    state_d     = state_q;

    ahb_o       = AHB_SLAVE_RSP_DEFAULT;
    apb_o       = APB_REQ_DEFAULT;

    fsm_err_o   = 1'b0;
    hresp_err_d = 1'b0;

    // Default: hold previous register values
    addr_d  = addr_q;
    wdata_d = wdata_q;
    rdata_d = rdata_q;
    strb_d  = strb_q;
    prot_d  = prot_q;

    //--------------------------------------------------------
    // FSM
    //--------------------------------------------------------

    case (state_q)

    //////////////////////////////////////////////////////////
    // RESET STATE
    //////////////////////////////////////////////////////////
    ResetSt :
    begin
        state_d = IdleSt;
    end


    //////////////////////////////////////////////////////////
    // IDLE STATE
    // Wait for a valid AHB transfer
    //////////////////////////////////////////////////////////
    IdleSt :
    begin

        // Detect valid transfer
        if (ahb_i.hsel &&
            ahb_i.hready &&
           ((ahb_i.htrans == HTRANS_SEQ) ||
            (ahb_i.htrans == HTRANS_NONSEQ))) begin

            //------------------------------------------------
            // WRITE transfer
            //------------------------------------------------
            if (ahb_i.hwrite) begin
                state_d = WriteWaitSt;
                addr_d  = ahb_i.haddr;
            end

            //------------------------------------------------
            // READ transfer
            //------------------------------------------------
            else begin
                state_d = ReadSetupSt;
                addr_d  = ahb_i.haddr;
            end

            // Capture protection attributes
            prot_d = ahb_i.hprot;

            //------------------------------------------------
            // Generate write strobe from HSIZE
            //------------------------------------------------
            unique case (ahb_i.hsize)

                // BYTE access
                3'b000 :
                    strb_d = {{(BYTES-1){1'b0}},1'b1} << lane;

                // HALFWORD access
                3'b001 :
                    strb_d = ({BYTES{1'b1}} >> (BYTES-2))
                             << (lane & ~1);

                // WORD access
                3'b010 :
                    if (BYTES >= 4)
                        strb_d = ({BYTES{1'b1}} >> (BYTES-4))
                                 << (lane & ~2);

                default :
                    strb_d = '0;

            endcase
        end

        // AHB response
        ahb_o.hrdata    = rdata_q;
        ahb_o.hresp     = HRESP_OKAY;
        ahb_o.hreadyout = 1'b1;
    end


    //////////////////////////////////////////////////////////
    // WRITE WAIT
    // Wait for AHB write data phase
    //////////////////////////////////////////////////////////
    WriteWaitSt :
    begin
        state_d = WriteSetupSt;

        // Capture write data
        wdata_d = ahb_i.hwdata;
    end


    //////////////////////////////////////////////////////////
    // WRITE SETUP (APB SETUP phase)
    //////////////////////////////////////////////////////////
    WriteSetupSt :
    begin
        state_d = WriteAccessSt;

        apb_o.paddr   = addr_q;
        apb_o.psel    = 1'b1;
        apb_o.penable = 1'b0;

        apb_o.pwrite  = 1'b1;
        apb_o.pwdata  = wdata_q;
        apb_o.pstrb   = strb_q;

        apb_o.pwakeup = 1'b1;

        // Map protection signals
        apb_o.pprot[0] = prot_q[1];
        apb_o.pprot[2] = prot_q[0];
    end


    //////////////////////////////////////////////////////////
    // WRITE ACCESS
    //////////////////////////////////////////////////////////
    WriteAccessSt :
    begin

        // Wait for APB slave ready
        if (apb_i.pready) begin

            if (apb_i.pslverr == APB_OKAY)
                state_d = IdleSt;
            else
                state_d = HrespErrSt;
        end

        apb_o.paddr   = addr_q;
        apb_o.psel    = 1'b1;
        apb_o.penable = 1'b1;

        apb_o.pwrite  = 1'b1;
        apb_o.pwdata  = wdata_q;
        apb_o.pstrb   = strb_q;

        apb_o.pwakeup = 1'b1;

        apb_o.pprot[0] = prot_q[1];
        apb_o.pprot[2] = prot_q[0];
    end


    //////////////////////////////////////////////////////////
    // READ SETUP
    //////////////////////////////////////////////////////////
    ReadSetupSt :
    begin
        state_d = ReadAccessSt;

        apb_o.paddr   = addr_q;
        apb_o.psel    = 1'b1;
        apb_o.penable = 1'b0;

        apb_o.pwrite  = 1'b0;
        apb_o.pstrb   = strb_q;
        apb_o.pwakeup = 1'b1;

        apb_o.pprot[0] = prot_q[1];
        apb_o.pprot[2] = prot_q[0];
    end


    //////////////////////////////////////////////////////////
    // READ ACCESS
    //////////////////////////////////////////////////////////
    ReadAccessSt :
    begin

        if (apb_i.pready) begin

            if (apb_i.pslverr == APB_OKAY) begin
                state_d = IdleSt;
                rdata_d = apb_i.prdata;
            end
            else begin
                state_d = HrespErrSt;
            end
        end

        apb_o.paddr   = addr_q;
        apb_o.psel    = 1'b1;
        apb_o.penable = 1'b1;

        apb_o.pwrite  = 1'b0;
        apb_o.pstrb   = strb_q;
        apb_o.pwakeup = 1'b1;

        apb_o.pprot[0] = prot_q[1];
        apb_o.pprot[2] = prot_q[0];
    end


    //////////////////////////////////////////////////////////
    // ERROR RESPONSE STATE
    //////////////////////////////////////////////////////////
    HrespErrSt :
    begin

        // AHB error requires two-cycle response
        if (hresp_readyhigh_err) begin
            ahb_o.hreadyout = 1'b1;
            state_d         = IdleSt;
        end
        else begin
            ahb_o.hreadyout = 1'b0;
        end

        ahb_o.hresp  = HRESP_ERROR;
        ahb_o.hrdata = rdata_q;

        hresp_err_d  = 1'b1;
    end


    //////////////////////////////////////////////////////////
    // DEFAULT (should never occur)
    //////////////////////////////////////////////////////////
    default :
    begin
        fsm_err_o = 1'b1;
    end

    endcase

end


//////////////////////////////////////////////////////////////
// Register Stage
//////////////////////////////////////////////////////////////

always_ff @(posedge clk_i or negedge rst_ni) begin

    if (!rst_ni) begin
        addr_q              <= '0;
        wdata_q             <= '0;
        rdata_q             <= '0;
        strb_q              <= '0;
        prot_q              <= '0;
        hresp_readyhigh_err <= 1'b0;
    end
    else begin
        addr_q              <= addr_d;
        wdata_q             <= wdata_d;
        rdata_q             <= rdata_d;
        strb_q              <= strb_d;
        prot_q              <= prot_d;
        hresp_readyhigh_err <= hresp_err_d;
    end

end

endmodule : ahb_to_apb_bridge_top