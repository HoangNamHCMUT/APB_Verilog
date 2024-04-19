module apb_master #(parameter DATA_WIDTH = 32, parameter ADDR_WIDTH = 32, parameter ERR_WIDTH = 2) (
  // Global and control signals
  input PCLK, PRESETn,
  // TAP - APB interfaces
  input TRANSFER_mst_i, RW_mst_i, 
  input [ADDR_WIDTH - 1 : 0] ADDR_mst_i,
  input [DATA_WIDTH - 1 : 0] WDATA_mst_i,
  output reg [ERR_WIDTH - 1 : 0] FAIL_mst_o,
  output reg DONE_mst_o,
  output reg [DATA_WIDTH - 1 : 0] RDATA_mst_o,
  // APB master - APB slave interfaces
  output reg PWRITE_mst_o, PSEL_mst_o, PENABLE_mst_o,
  output reg [ADDR_WIDTH - 1 : 0] PADDR_mst_o,
  output reg [DATA_WIDTH - 1 : 0] PWDATA_mst_o,
  input [DATA_WIDTH - 1 : 0] PRDATA_mst_i,
  input PREADY_mst_i, PSLVERR_mst_i,
  // APB master - Timeout checker
  input TOUT_mst_i
);
  
  localparam IDLE = 0;
  localparam SETUP = 1;
  localparam ACCESS = 2;
  localparam DONE = 3;
  
  reg [1:0] state = IDLE; // a flip-flop for storing the current state of FSM
  reg [1:0] nstate = IDLE; // a wire containing next state of FSM ("reg" used in combinational logic will be synthesized to "wire")
  
  // Pipelined variables for the outputs 
  // These variables are synthesized to wires (used in combinational logic)
  reg [ERR_WIDTH - 1 : 0] FAIL_mst_o_p = 0;
  reg DONE_mst_o_p = 0;
  reg [DATA_WIDTH - 1 : 0] RDATA_mst_o_p = 0;
  reg PWRITE_mst_o_p = 0, PSEL_mst_o_p = 0, PENABLE_mst_o_p = 0;
  reg [ADDR_WIDTH - 1 : 0] PADDR_mst_o_p = 0;
  reg [DATA_WIDTH - 1 : 0] PWDATA_mst_o_p = 0;
  
  // Reset logic - Sequential logic
  always@(posedge PCLK)
    begin
      if(PRESETn == 0) // negative reset
        begin
          // All the outputs become 0
          PWRITE_mst_o <= 0;
          PSEL_mst_o <= 0;
          PENABLE_mst_o <= 0;
          PADDR_mst_o <= 0;
          PWDATA_mst_o <= 0;
          RDATA_mst_o <= 0;
          DONE_mst_o <= 0;
          FAIL_mst_o <= 2'b00;
          state <= IDLE;
        end
      else
        begin
          PWRITE_mst_o <= PWRITE_mst_o_p;
          PSEL_mst_o <= PSEL_mst_o_p;
          PENABLE_mst_o <= PENABLE_mst_o_p;
          PADDR_mst_o <= PADDR_mst_o_p;
          PWDATA_mst_o <= PWDATA_mst_o_p;
          RDATA_mst_o <= RDATA_mst_o_p;
          DONE_mst_o <= DONE_mst_o_p;
          FAIL_mst_o <= FAIL_mst_o_p;
          state <= nstate;
        end
    end
  
  // Next state logic - Combinational Logic
  always@(*)
    begin
      case(state)
        IDLE:
          begin
            if(TRANSFER_mst_i)
              begin
                nstate = SETUP;
              end
            else 
              begin
                nstate = IDLE;
              end
          end
        SETUP:
          begin
            if(TOUT_mst_i)
              nstate = DONE;
            else
              nstate = ACCESS;
          end
        ACCESS:
          begin
            if(PREADY_mst_i == 1 || TOUT_mst_i == 1)
              begin
                nstate = DONE;
              end
            else
              begin
                nstate = ACCESS;
              end
          end
        DONE:
          begin
            nstate = IDLE;
          end
        default: state = IDLE;
      endcase
    end
  
  // Output logic - Combinational Logic - Updating the pipelined variables
  always@(*)
    begin
      case(state)
        IDLE:
          begin
            PSEL_mst_o_p = 0;
            PENABLE_mst_o_p = 0;
            DONE_mst_o_p = 0;
            FAIL_mst_o_p = 2'b00;
          end
        SETUP:
          begin
            PSEL_mst_o_p = 1;
            if(RW_mst_i == 0) // read operation
              begin
                PADDR_mst_o_p = ADDR_mst_i;
                PWRITE_mst_o_p = 0;
              end
            else // write operation
              begin
                PADDR_mst_o_p = ADDR_mst_i;
                PWDATA_mst_o_p = WDATA_mst_i;
                PWRITE_mst_o_p = 1;
              end
          end
        ACCESS:
          begin
            PENABLE_mst_o_p = 1;
          end
        DONE:
          begin
            PSEL_mst_o_p = 0;
            PENABLE_mst_o_p = 0;
            DONE_mst_o_p = 1;
            RDATA_mst_o_p = PRDATA_mst_i;
            FAIL_mst_o_p = {TOUT_mst_i, PSLVERR_mst_i};
          end
        default:
          begin
            PSEL_mst_o_p = 0;
            PENABLE_mst_o_p = 0;
            DONE_mst_o_p = 0;
            FAIL_mst_o_p = 2'b00;
          end
      endcase
    end
  
endmodule