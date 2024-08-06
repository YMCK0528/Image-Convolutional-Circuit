`timescale 1ns/10ps

module  CONV(clk,reset,busy,ready,iaddr,idata,cwr,caddr_wr,cdata_wr,crd,caddr_rd,cdata_rd,csel);
input clk;
input reset;
input ready;
output busy;
output [11:0] iaddr;
input signed [19:0] idata;
output crd;
input signed [19:0] cdata_rd;
output [11:0] caddr_rd;
output cwr;
output signed [19:0] cdata_wr;
output [11:0] caddr_wr;
output [2:0] csel;

reg busy;
reg [11:0] iaddr;
reg crd;
reg [11:0] caddr_rd;
reg cwr;
reg signed [19:0] cdata_wr;
reg [11:0]  caddr_wr;
reg [2:0] csel;

reg[3:0] current_State;
reg[3:0] next_State;

reg [5:0]index_X,index_Y;
wire [5:0] index_X_After,index_X_Before,index_Y_After,index_Y_Before;

reg [3:0] counter_add;
reg signed [19:0] kernel ;

parameter IDLE = 4'd0;
parameter READ_CONV = 4'd1 ;
parameter WRITE_L0 = 4'd2 ;
parameter READ_L0 = 4'd3 ;
parameter MAX_POOLING = 4'd4 ;
parameter WRITE_L1 = 4'd5 ;
parameter FINISH = 4'd6 ;



//busy
always @(posedge clk or posedge reset)
begin
    if (reset)
    begin
        busy<=1'd0;
    end
    else if (ready)
    begin
        busy<=1'd1;
    end
    else if (current_State==FINISH)
    begin
        busy<=1'd0;
    end
    else
    begin
        busy<=busy;
    end
end

//FSM
always @(posedge clk or posedge reset)
begin
    if (reset)
    begin
        current_State <= IDLE;
    end
    else
    begin
        current_State<=next_State;
    end
end

//next state
always @(*)
begin
    case (current_State)
        IDLE:
        begin
            if (ready==1'd1)
            begin
                next_State<=READ_CONV;
            end
            else
            begin
                next_State<=IDLE;
            end
        end
        READ_CONV:
        begin
            if (counter_add==4'd11)
            begin
                next_State<=WRITE_L0;
            end
            else
            begin
                next_State<=READ_CONV;
            end
        end
        WRITE_L0:
        begin
            if(index_X == 6'd63 && index_Y == 6'd63)
                next_State = READ_L0;
            else
                next_State = READ_CONV;
        end
        READ_L0:
            if (counter_add==4'd4)
            begin
                next_State<=MAX_POOLING;
            end
            else
            begin
                next_State<=READ_L0;
            end
        MAX_POOLING:
        begin
            next_State<= WRITE_L1;
        end
        WRITE_L1:
        begin
            if(index_X == 6'd62 && index_Y == 6'd62)
                next_State = FINISH;
            else
                next_State = READ_L0;
        end
        FINISH:
        begin
            next_State<=FINISH;
        end
        default:
        begin
            next_State = IDLE;
        end
    endcase
end


//define x y
assign index_X_Before = index_X - 6'd1;
assign index_X_After = index_X + 6'd1;
assign index_Y_Before = index_Y - 6'd1;
assign index_Y_After = index_Y + 6'd1;


//X
always @(posedge clk or posedge reset)
begin
    if (reset)
    begin
        index_X<=6'd0;
    end
    else if (current_State == WRITE_L0)
    begin
        if (index_X==6'd63)
        begin
            index_X<=6'd0;
        end
        else
        begin
            index_X<=index_X+1'd1;
        end
    end
    else if (current_State == WRITE_L1)
    begin
        if (index_X==6'd62)
        begin
            index_X<=6'd0;
        end
        else
        begin
            index_X<=index_X+2'd2;
        end
    end
    else
    begin
        index_X<=index_X;
    end
end

//Y
always @(posedge clk or posedge reset)
begin
    if (reset)
    begin
        index_Y<=6'd0;
    end
    else if (current_State == WRITE_L0)
    begin
        if (index_X==6'd63)
        begin
            index_Y<=index_Y+1'd1;
        end
        else
        begin
            index_Y<=index_Y;
        end
    end
    else if (current_State == WRITE_L1)
    begin
        if (index_X==6'd62)
        begin
            index_Y<=index_Y+2'd2;
        end
        else
        begin
            index_Y<=index_Y;
        end
    end
    else
    begin
        index_Y<=index_Y;
    end
end

//kernel
parameter K0 = 20'h0A89E ;
parameter K1 = 20'h092D5 ;
parameter K2 = 20'h06D43 ;
parameter K3 = 20'h01004 ;
parameter K4 = 20'hF8F71 ;
parameter K5 = 20'hF6E54 ;
parameter K6 = 20'hFA6D7 ;
parameter K7 = 20'hFC834 ;
parameter K8 = 20'hFAC19 ;
parameter Bias = {8'd0,20'h01310,16'd0} ;

always@(*)
begin
    case(counter_add)
        4'd2:
            kernel = K0;
        4'd3:
            kernel = K1;
        4'd4:
            kernel = K2;
        4'd5:
            kernel = K3;
        4'd6:
            kernel = K4;
        4'd7:
            kernel = K5;
        4'd8:
            kernel = K6;
        4'd9:
            kernel = K7;
        4'd10:
            kernel = K8;
        default:
            kernel = 20'd0;
    endcase
end

//counter_add
always @(posedge clk or posedge reset)
begin
    if (reset)
    begin
        counter_add<=4'd0;
    end
    else if (counter_add==4'd11)
    begin
        counter_add<=4'd0;
    end
    else if (counter_add == 4'd4 && current_State == READ_L0)
    begin
        counter_add<= 4'd0;
    end
    else if (current_State==READ_CONV || current_State == READ_L0)
    begin
        counter_add<= counter_add+1'd1;
    end
end


//addr
always @(posedge clk or posedge reset)
begin
    if (reset)
    begin
        iaddr<=12'd0;
    end
    else if (current_State<=READ_CONV)
    begin
        case (counter_add)
            4'd0:
                iaddr <= {index_Y_Before,index_X_Before};
            4'd1:
                iaddr <= {index_Y_Before,index_X};
            4'd2:
                iaddr <= {index_Y_Before,index_X_After};
            4'd3:
                iaddr <= {index_Y,index_X_Before};
            4'd4:
                iaddr <= {index_Y,index_X};
            4'd5:
                iaddr <= {index_Y,index_X_After};
            4'd6:
                iaddr <= {index_Y_After,index_X_Before};
            4'd7:
                iaddr <= {index_Y_After,index_X};
            4'd8:
                iaddr <= {index_Y_After,index_X_After};
            default:
                iaddr<=12'd0;
        endcase
    end
end

//caddr_rd
always @(posedge clk or posedge reset)
begin
    if (reset)
    begin
        caddr_rd <= 12'd0;
    end
    else if (current_State == READ_L0)
    begin
        case (counter_add)
            4'd0:
            begin
                caddr_rd<={index_Y,index_X};
            end
            4'd1:
            begin
                caddr_rd<={index_Y,index_X_After};
            end
            4'd2:
            begin
                caddr_rd<={index_Y_After,index_X};
            end
            4'd3:
            begin
                caddr_rd<={index_Y_After,index_X_After};
            end
            default:
                caddr_rd<=12'd0;
        endcase
    end
end

reg signed [19:0] idata_reg;
wire signed [43:0] mul_reg;// 2^20 * 2^20 * 2^4 = 2^44  By the way 2^4 = 9 pixel
assign mul_reg = kernel * idata_reg ;
reg signed [43:0] conv_reg ;
//conv & bias
always @(posedge clk or posedge reset)
begin
    if (reset)
    begin
        idata_reg <= 20'd0;
    end
    else
        idata_reg <= idata;
end


always @(posedge clk or posedge reset)
begin
    if (reset)
    begin
        conv_reg <= 44'd0;
    end
    else if (current_State==READ_CONV)
    begin
        case (counter_add)
            4'd0://reset conv_reg
                conv_reg<=44'd0;
            4'd2://0
                if (index_X !=6'd0 && index_Y != 6'd0)
                begin
                    conv_reg<=mul_reg;
                end
                else
                    conv_reg<=conv_reg;
            4'd3://1
                if (index_Y != 6'd0)
                begin
                    conv_reg<=conv_reg + mul_reg;
                end
                else
                    conv_reg<=conv_reg;
            4'd4://2
                if (index_Y != 6'd0 && index_X != 6'd63)
                begin
                    conv_reg<=conv_reg + mul_reg;
                end
                else
                    conv_reg<=conv_reg;
            4'd5://3
                if (index_X != 6'd0)
                begin
                    conv_reg<=conv_reg + mul_reg;
                end
                else
                    conv_reg<=conv_reg;
            4'd6://4
                conv_reg<=conv_reg + mul_reg;
            4'd7://5
                if (index_X != 6'd63)
                begin
                    conv_reg<=conv_reg + mul_reg;
                end
                else
                    conv_reg<=conv_reg;
            4'd8://6
                if (index_X != 6'd0 && index_Y != 6'd63)
                begin
                    conv_reg<=conv_reg + mul_reg;
                end
                else
                    conv_reg<=conv_reg;
            4'd9://7
                if (index_Y !=6'd63)
                begin
                    conv_reg<=conv_reg + mul_reg;
                end
                else
                    conv_reg<=conv_reg;
            4'd10://8
                if (index_Y != 6'd63 && index_X != 6'd63)
                begin
                    conv_reg<=conv_reg + mul_reg;
                end
                else
                    conv_reg<=conv_reg;
            4'd11://BAIS
                conv_reg<=conv_reg + Bias;
            default:
                conv_reg<=44'd0;
        endcase
    end
end

wire signed [20:0] relu_reg ;
assign relu_reg = conv_reg [35:15] + 21'd1;//choose 4bit + 17bit add 1


//cwr
always @(posedge clk or posedge reset)
begin
    if (reset)
    begin
        cwr <= 1'd0;
    end
    else if (current_State == WRITE_L0 || current_State == WRITE_L1)
    begin
        cwr <= 1'd1;
    end
    else
        cwr <= 1'd0;
end

//cdata_wr
always @(posedge clk or posedge reset)
begin
    if (reset)
    begin
        cdata_wr<=20'd0;
    end
    else if (current_State == WRITE_L0)
    begin
        begin
            if(conv_reg[43])
                cdata_wr <= 20'd0;
            else
                cdata_wr <= relu_reg[20:1];
        end
    end
    else if (current_State == READ_L0)
    begin
        if (counter_add==4'd1)
        begin
            cdata_wr<= cdata_rd;
        end
        else
        begin
            if (cdata_wr<cdata_rd)
            begin
                cdata_wr<= cdata_rd;
            end
            else
                cdata_wr<=cdata_wr;
        end
    end
    else
        cdata_wr<=cdata_wr;
end

//caddr_wr
always @(posedge clk or posedge reset)
begin
    if (reset)
    begin
        caddr_wr<=11'd0;
    end
    else if (current_State == WRITE_L0)
    begin
        caddr_wr<={index_Y,index_X};
    end
    else if (current_State == WRITE_L1)
    begin
        caddr_wr<={index_Y[5:1],index_X[5:1]};
    end
    else
        caddr_wr<=caddr_wr;
end

//crd
always @(posedge clk or posedge reset)
begin
    if (reset)
    begin
        crd <= 1'd0;
    end
    else if (current_State == READ_L0)
    begin
        crd <= 1'd1;
    end
    else
        crd <= 1'd0;
end


//csel
always@(posedge clk or posedge reset)
begin
    if(reset)
        csel <=3'd0;
    else if(next_State == WRITE_L1)
        csel <= 3'd3;
    else if(current_State == WRITE_L0)
        csel <= 3'd1;
    else if(current_State == READ_L0)
        csel <= 3'd1;
    else
        csel <= csel;
end


endmodule
