`timescale 1ns / 1ps

module i2c_master #(
    parameter SYS_FREQ = 125_000_000,
    parameter I2C_FREQ = 100_000
) (
    input clk,
    rst,
    start,
    rw,
    input [6:0] dev_addr,
    inout i2c_sda,
    inout i2c_scl,
    input [7:0] rx_data,
    output [7:0] tx_data,
    output reg busy,
    ack_err,
    done
);

  reg scl_t = 0;
  reg sda_t = 0;


  localparam CLK_COUNT4 = (SYS_FREQ / I2C_FREQ);
  localparam CLK_COUNT1 = CLK_COUNT4 / 4;

  integer count1 = 0;
  reg i2c_clk = 0;

  ///////4x clock
  reg [1:0] pulse = 0;
  always @(posedge clk) begin
    if (rst) begin
      pulse <= 0;
    end else if (count1 == CLK_COUNT1 - 1) begin
      pulse  <= 1;
      count1 <= count1 + 1;
    end else if (count1 == CLK_COUNT1 * 2 - 1) begin
      pulse  <= 2;
      count1 <= count1 + 1;
    end else if (count1 == CLK_COUNT1 * 3 - 1) begin
      pulse  <= 3;
      count1 <= count1 + 1;
    end else if (count1 == CLK_COUNT1 * 4 - 1) begin
      pulse  <= 0;
      count1 <= 0;
    end else begin
      count1 <= count1 + 1;
    end
  end

  //////////////////
  reg [3:0] bitcount = 0;
  reg [7:0] data_addr = 0, data_tx = 0;
  reg r_ack = 0;
  reg r_scl = 0;
  reg [7:0] data_rx = 0;
  reg sda_en = 0;
  reg scl_en = 0;



  localparam [3:0] IDLE = 0, START = 1, WRITE_ADDR = 2, ACK_1 = 3, WRITE_DATA = 4, READ_DATA = 5, STOP = 6, ACK_2 =7, MASTER_ACK = 8, WAIT_STRETCH = 9;
  reg [3:0] state = IDLE;


  always @(posedge clk) begin
    if (rst) begin
      bitcount   <= 0;
      data_addr  <= 0;
      data_tx    <= 0;
      scl_t <= 1;
      sda_t <= 1;
      scl_en <= 1'b0;
      sda_en <= 1'b0;
      state <= IDLE;
      busy  <= 1'b0;
      ack_err <= 1'b0;
      done    <= 1'b0;
      r_scl <= 1'b1;
    end else begin
      case (state)

        //////////////IDLE state
        IDLE: begin
          done <= 1'b0;  // clear done flag
          if (start == 1'b1) begin
            data_addr  <= {dev_addr,rw};
            data_tx    <= rx_data;
            busy  <= 1'b1;
            state <= START;
            ack_err <= 1'b0;
            r_scl   <= 1'b1;
          end else begin
            data_addr  <= 0;
            data_tx    <= 0;
            busy  <= 1'b0;
            state <= IDLE;
            ack_err <= 1'b0;
          end
        end
        /////////////////////////////////////////////////////    
        START: begin
          sda_en <= 1'b1;  ///send START to slave
          scl_en <= 1'b1;
          case (pulse)
            0: begin
              scl_t <= 1'b1;
              sda_t <= 1'b1;
            end
            1: begin
              scl_t <= 1'b1;
              sda_t <= 1'b1;
            end
            2: begin
              scl_t <= 1'b1;
              sda_t <= 1'b0;
            end
            3: begin
              scl_t <= 1'b1;
              sda_t <= 1'b0;
            end
          endcase

          if (count1 == CLK_COUNT1 * 4 - 1) begin
            state <= WRITE_ADDR;
            scl_t <= 1'b0;
          end else state <= START;
        end
        ///////////////////////////////////////////     
        WRITE_ADDR: begin
          sda_en <= 1'b1;  ///send dev_addr to slave
          scl_en <= 1'b1;
          if (bitcount <= 7) begin
            case (pulse)
              0: begin
                scl_t <= 1'b0;
                sda_t <= 1'b0;
              end
              1: begin
                scl_t <= 1'b0;
                sda_t <= data_addr[7-bitcount];
              end
              2: begin
                scl_t <= 1'b1;
              end
              3: begin
                scl_t <= 1'b1;
              end
            endcase
            if (count1 == CLK_COUNT1 * 4 - 1) begin
              state <= WRITE_ADDR;
              scl_t <= 1'b0;
              bitcount <= bitcount + 1;
            end else begin
              state <= WRITE_ADDR;
            end

          end else begin
            state <= ACK_1;
            bitcount <= 0;
            sda_en <= 1'b0;
            scl_en <= 1'b0;
          end
        end


        //////////////////////////////////////

        ACK_1: begin
          sda_en <= 1'b0;  ///recv ack from slave
          case (pulse)
            0: begin
              scl_en <= 1'b0;
              if (count1 == 20) begin
                r_scl <= i2c_scl;
              end else r_scl <= r_scl;
            end

            1: begin
              scl_en <= 1'b1;
              scl_t  <= (r_scl == 1'b1) ? 1'b0 : 1'b0;
              sda_t  <= 1'b0;
              r_ack  <= i2c_sda;
            end  /// check i2c_scl status
            2: begin
              scl_en <= 1'b1;
              scl_t  <= (r_scl == 1'b1) ? 1'b1 : 1'b0;
            end  ///recv ack from slave
            3: begin
              scl_en <= 1'b1;
              scl_t  <= (r_scl == 1'b1) ? 1'b1 : 1'b0;
            end
          endcase

          if (count1 == CLK_COUNT1 * 4 - 1) begin
            if (r_scl == 1'b0) begin
              state <= ACK_1;
            end else if (r_ack == 1'b0 && data_addr[0] == 1'b0) begin
              state <= WRITE_DATA;
              sda_t <= 1'b0;
              sda_en <= 1'b0;  /////write data to slave
              bitcount <= 0;
            end else if (r_ack == 1'b0 && data_addr[0] == 1'b1) begin
              state <= READ_DATA;
              sda_t <= 1'b1;
              sda_en <= 1'b0;  ///read data from slave
              bitcount <= 0;
            end else begin
              state   <= STOP;
              sda_en  <= 1'b1;  ////send STOP to slave
              ack_err <= 1'b1;
            end
          end else begin
            state <= ACK_1;
          end

        end


        WRITE_DATA: begin
          ///write data to slave
          if (bitcount <= 7) begin
            case (pulse)
              0: begin
                scl_t <= 1'b0;
              end
              1: begin
                scl_t  <= 1'b0;
                sda_en <= 1'b1;
                sda_t  <= data_tx[7-bitcount];
              end
              2: begin
                scl_t <= 1'b1;
              end
              3: begin
                scl_t <= 1'b1;
              end
            endcase
            if (count1 == CLK_COUNT1 * 4 - 1) begin
              state <= WRITE_DATA;
              scl_t <= 1'b0;
              bitcount <= bitcount + 1;
            end else begin
              state <= WRITE_DATA;
            end

          end else begin
            state <= ACK_2;
            bitcount <= 0;
            sda_en <= 1'b0;  ///read from slave
          end


        end
        ///////////////////////////// READ_DATA

        READ_DATA: begin
          sda_en <= 1'b0;  ///read from slave // -> master thả SDA, để slave kéo
          if (bitcount <= 7) begin
            case (pulse)
              0: begin
                scl_t <= 1'b0;
                sda_t <= 1'b0;
              end
              1: begin
                scl_t <= 1'b0;
                sda_t <= 1'b0;
              end
              2: begin
                scl_t <= 1'b1;
                data_rx[7:0] <= (count1 == 200) ? {data_rx[6:0], i2c_sda} : data_rx;
              end
              3: begin
                scl_t <= 1'b1;
              end
            endcase
            if (count1 == CLK_COUNT1 * 4 - 1) begin
              state <= READ_DATA;
              scl_t <= 1'b0;
              bitcount <= bitcount + 1;
            end else begin
              state <= READ_DATA;
            end

          end else begin
            state <= MASTER_ACK;
            bitcount <= 0;
            sda_en <= 1'b1;  ///master will send ack to slave
          end



        end
        ////////////////////master ack -> send nack
        MASTER_ACK: begin
          sda_en <= 1'b1;

          case (pulse)
            0: begin
              scl_t <= 1'b0;
              sda_t <= 1'b1;
            end
            1: begin
              scl_t <= 1'b0;
              sda_t <= 1'b1;
            end
            2: begin
              scl_t <= 1'b1;
              sda_t <= 1'b1;
            end
            3: begin
              scl_t <= 1'b1;
              sda_t <= 1'b1;
            end
          endcase

          if (count1 == CLK_COUNT1 * 4 - 1) begin
            sda_t  <= 1'b0;
            state  <= STOP;
            sda_en <= 1'b1;  ///send STOP to slave

          end else begin
            state <= MASTER_ACK;
          end

        end



        /////////////////ack 2

        ACK_2: begin
          sda_en <= 1'b0;  ///recv ack from slave
          case (pulse)
            0: begin
              scl_t <= 1'b0;
              sda_t <= 1'b0;
            end
            1: begin
              scl_t <= 1'b0;
              sda_t <= 1'b0;
            end
            2: begin
              scl_t <= 1'b1;
              sda_t <= 1'b0;
              r_ack <= 1'b0;
            end  ///recv ack from slave
            3: begin
              scl_t <= 1'b1;
            end
          endcase

          if (count1 == CLK_COUNT1 * 4 - 1) begin
            sda_t  <= 1'b0;
            sda_en <= 1'b1;  ///send STOP to slave
            if (r_ack == 1'b0) begin
              state <= STOP;
            end else begin
              state <= STOP;
            end
          end else begin
            state <= ACK_2;
          end

        end

        /////////////////////////////////////////////STOP  
        STOP: begin
          sda_en <= 1'b1;  ///send STOP to slave
          case (pulse)
            0: begin
              scl_t <= 1'b1;
              sda_t <= 1'b0;
            end
            1: begin
              scl_t <= 1'b1;
              sda_t <= 1'b0;
            end
            2: begin
              scl_t <= 1'b1;
              sda_t <= 1'b1;
            end
            3: begin
              scl_t <= 1'b1;
              sda_t <= 1'b1;
            end
          endcase

          if (count1 == CLK_COUNT1 * 4 - 1) begin
            state  <= IDLE;
            scl_t  <= 1'b0;
            busy   <= 1'b0;  /// clear busy flag
            sda_en <= 1'b1;  ///send START to slave
            done   <= 1'b1;
          end else state <= STOP;
        end

        //////////////////////////////////////////////

        default: state <= IDLE;
      endcase
    end
  end

  assign i2c_sda = (sda_en == 1) ? (sda_t == 0) ? 1'b0 : 1'b1 : 1'bz; /// en = 1 -> write to slave else read
  ////// if sda_en == 1 then if sda_t == 0 pull line low else release so that pull up make line high
  /*
if(sda_en)
   if(!sda_t)
      i2c_sda = 0
   else
      i2c_sda = z
else
   i2c_sda = z
*/
  assign i2c_scl = (scl_en == 1'b1) ? (scl_t == 0) ? 1'b0 : 1'b1 : 1'bz;
  //   assign tx_data = data_rx;
  reg [7:0] dout_reg;
  assign tx_data = dout_reg;

  always @(posedge clk or posedge rst) begin
    if (rst) begin
      dout_reg <= 8'h00;
    end else begin
      // khi kết thúc đọc (sau MASTER_ACK / STOP), chốt dữ liệu lại
      if (state == MASTER_ACK && rw == 1'b1) begin
        dout_reg <= data_rx;
      end
    end
  end

endmodule
