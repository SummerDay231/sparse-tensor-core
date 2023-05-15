module matrix_save_unit #(
  parameter M_TILE = 4, N_TILE = 4,
  parameter M_EXPAND = 4,
  parameter N_SECTION = 4,
  parameter DW_DATA = 32, DW_MEM_WRITE = M_TILE*N_TILE*M_EXPAND*N_SECTION*DW_DATA) 
(
  input                             clk,
  input                             rst,
  input                             en,
  /* ------- controller ------- */
  input                             sel_acc_buf,
  input [3:0]                       col_buf,
  input [1:0]                        row_buf,
  // valid number per M_EXPAND
  input [2:0]                       block_type,
  /* ------- data ------- */
  input signed [M_TILE*M_EXPAND*N_TILE*DW_DATA-1:0] in,
  output signed [DW_MEM_WRITE-1:0]    out,
  output reg                              out_valid,
  // 
  output reg                              out_state
);

  localparam LOCAL_BUFFER_SIZE = M_EXPAND*M_TILE*N_TILE;

  reg [LOCAL_BUFFER_SIZE*DW_DATA-1:0] reg_write;
  //reg [DW_DATA-1:0] reg_write_show [M_TILE-1:0][M_EXPAND*N_TILE-1:0];
  reg [N_SECTION*LOCAL_BUFFER_SIZE*DW_DATA-1:0] reg_out_buffer [1:0];
  //reg [DW_DATA-1:0] reg_outbuffer_show0 [N_SECTION-1:0][M_TILE-1:0][M_EXPAND*N_TILE-1:0];
  //reg [DW_DATA-1:0] reg_outbuffer_show1 [N_SECTION-1:0][M_TILE-1:0][M_EXPAND*N_TILE-1:0];
  reg [DW_MEM_WRITE-1:0]    reg_out;

  reg state, next_state; // 0 for state0, 1 for state1
  reg signed [31:0] input_cnt, output_cnt;

  integer i, j, k, l, col;

  // FSM
  always @(posedge clk) begin
    if (rst) begin
      next_state <= 0;
      reg_out_buffer[0] <= 0;
      reg_out_buffer[1] <= 0;
      reg_write <= 0;
      input_cnt <= 40;
      output_cnt <= 40;
    end
    else if (state!= sel_acc_buf) begin
      next_state <= sel_acc_buf;
      reg_write <= 0;
      input_cnt <= 40;
      output_cnt <= 40;
      if (sel_acc_buf == 1) begin
        reg_out_buffer[0] <= 0;
      end
      else begin
        reg_out_buffer[1] <= 0;
      end
    end
    else begin
      output_cnt <= output_cnt - 4;
//      input_cnt <= input_cnt - 4;    // why?
       if (block_type == 1) begin
         input_cnt <= input_cnt - 4;
         reg_write <= in;
       end
       else if (block_type == 2) begin
         input_cnt <= input_cnt - 2;
         for (i=0; i<M_TILE; i=i+1) begin
           for (j=0; j<N_TILE; j=j+1) begin
               reg_write[(((row_buf*M_TILE+i)*N_TILE+j)*2)*DW_DATA +:2*DW_DATA] <= in[((i*N_TILE+j)*M_EXPAND)*DW_DATA +:2*DW_DATA];
           end
         end
       end
       else if (block_type == 4) begin
         input_cnt <= input_cnt - 1;
         for (i=0; i<M_TILE; i=i+1) begin
           for (j=0; j<N_TILE; j=j+1) begin
               reg_write[((row_buf*M_TILE+i)*N_TILE+j)*DW_DATA +:DW_DATA] <= in[((i*N_TILE+j)*M_EXPAND)*DW_DATA +:DW_DATA];
           end
         end
       end
       else begin
         input_cnt <= input_cnt - 4;
         reg_write <= in;
       end
      // case (block_type)
      //   0: begin
      //     input_cnt <= input_cnt - 4;
      //     reg_write <= in;
      //   end
      //   1: begin
      //     input_cnt <= input_cnt - 2;
      //     for (i=0; i<M_TILE; i=i+1) begin
      //       for (j=0; j<N_TILE; j=j+1) begin
      //           reg_write[(((row_buf*M_TILE+i)*N_TILE+j)*2)*DW_DATA +:2*DW_DATA] <= in[((i*N_TILE+j)*M_EXPAND)*DW_DATA +:2*DW_DATA];
      //       end
      //     end
      //   end
      //   2:begin
      //     input_cnt <= input_cnt - 1;
      //     for (i=0; i<M_TILE; i=i+1) begin
      //       for (j=0; j<N_TILE; j=j+1) begin
      //           reg_write[((row_buf*M_TILE+i)*N_TILE+j)*DW_DATA +:DW_DATA] <= in[((i*N_TILE+j)*M_EXPAND)*DW_DATA +:DW_DATA];
      //       end
      //     end
      //   end
      //   default: begin
      //     reg_write <= in;
      //   end
      // endcase

      // write buffer to outbuffer
      // reg_out_buffer[1-sel_acc_buf][(col_buf*M_EXPAND*M_TILE*N_TILE)*DW_DATA +: M_EXPAND*M_TILE*N_TILE*DW_DATA] <= reg_out_buffer[1-sel_acc_buf][(col_buf*M_EXPAND*M_TILE*N_TILE)*DW_DATA +: M_EXPAND*M_TILE*N_TILE*DW_DATA] + reg_write;
      if (sel_acc_buf == 0) begin
        reg_out_buffer[1][(col_buf*LOCAL_BUFFER_SIZE)*DW_DATA +: LOCAL_BUFFER_SIZE*DW_DATA] <= reg_out_buffer[1][(col_buf*LOCAL_BUFFER_SIZE)*DW_DATA +: LOCAL_BUFFER_SIZE*DW_DATA] + reg_write;
      end
      else begin
        reg_out_buffer[0][(col_buf*LOCAL_BUFFER_SIZE)*DW_DATA +: LOCAL_BUFFER_SIZE*DW_DATA] <= reg_out_buffer[0][(col_buf*LOCAL_BUFFER_SIZE)*DW_DATA +: LOCAL_BUFFER_SIZE*DW_DATA] + reg_write;
      end
    end
  end

  /*
  always @(posedge clk) begin
    if (en) begin
      // reduce to write buffer
      //reg_write = 0;
    end
  end
  */

  // signals
  always @(posedge clk) begin
    state <= next_state;
    if (input_cnt <= 0) out_state = 0;
    else out_state <= 1;
    if (output_cnt <= 0) out_valid = 0;
    else out_valid <= 1;
  end

  // output
  
  always @(posedge clk) begin
    if (rst) begin
        reg_out <= 0;
          col <= 0;
    end
    col <= 10 - output_cnt / 4;
    reg_out <= reg_out_buffer[sel_acc_buf][(col*LOCAL_BUFFER_SIZE)*DW_DATA +: LOCAL_BUFFER_SIZE*DW_DATA];
  end

  assign out = reg_out;
  /*
  always @(posedge clk) begin
    for (i=0; i<M_TILE; i=i+1) begin
      for (j=0; j<N_TILE; j=j+1) begin
        for (k=0; k<M_EXPAND; k=k+1) begin
          reg_write_show[i][j*M_EXPAND+k] <= reg_write[(((i*N_TILE)+j)*M_EXPAND+k)*DW_DATA +:DW_DATA];
        end
      end
    end
    for (l=0; l<N_SECTION; l=l+1) begin
      for (i=0; i<M_TILE; i=i+1) begin
        for (j=0; j<N_TILE; j=j+1) begin
          for (k=0; k<M_EXPAND; k=k+1) begin
            reg_outbuffer_show0[l][i][j*M_EXPAND+k] <= reg_out_buffer[0][((((l*M_TILE+i)*N_TILE)+j)*M_EXPAND+k)*DW_DATA +:DW_DATA];
            reg_outbuffer_show1[l][i][j*M_EXPAND+k] <= reg_out_buffer[1][((((l*M_TILE+i)*N_TILE)+j)*M_EXPAND+k)*DW_DATA +:DW_DATA];
          end
        end
      end
    end
  end
  */

endmodule