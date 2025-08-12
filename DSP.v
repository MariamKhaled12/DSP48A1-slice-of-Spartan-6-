module MUX2#(parameter WIDTH=18)(in1, in2, sel, out);
    input [WIDTH-1:0] in1, in2;
    input sel;
    output[WIDTH-1:0] out;

    assign out = (sel==1)? in2: in1;

endmodule

module AddSub #(
    parameter WIDTH = 18
    //parameter OPERATION = "ADD"
    )(
        input mode,
        input [WIDTH-1:0] in1, in2,
        input carryin,
        output reg [WIDTH-1:0] out,
        output reg cout
    );

    always @(*) begin
        if(!mode)
            {cout, out}= in1+in2+carryin;
        else 
            {cout, out}= in1-(carryin+in2); 
    end
endmodule


module multiplier #(
    parameter WIDTH =18
)(
    input [WIDTH-1:0] m1, m2,
    output [WIDTH*2-1:0] out
);
    assign out= m1*m2;
endmodule


module MUX4_1 #(
    parameter WIDTH_IN1 = 48,
    parameter WIDTH_IN2 = 18,
    parameter WIDTH_IN3 = 36,
    parameter WIDTH_OUT  = 48
)(
    input [1:0] sel,
    input [WIDTH_IN1-1:0] in1,
    input [WIDTH_IN2-1:0] in2,
    input [WIDTH_IN3-1:0] in3,
    output reg [WIDTH_OUT-1:0] out
);

    always @(*) begin
        case (sel)
            2'b00: out = {WIDTH_OUT{1'b0}}; // All-zero value
            2'b01: out = {{(WIDTH_OUT - WIDTH_IN3){in3[WIDTH_IN3-1]}}, in3}; // Sign-extend in3
            2'b10: out = in1; // No extension
            2'b11: out = {{(WIDTH_OUT - WIDTH_IN2){in2[WIDTH_IN2-1]}}, in2}; // Sign-extend in2
            default: out = {WIDTH_OUT{1'bx}};
        endcase
    end

endmodule


module DSP #(
    parameter A0REG = 0, // 0 no reg 1 reg
    parameter A1REG = 1,
    parameter B0REG = 0, 
    parameter B1REG = 1,
    parameter CREG = 1, 
    parameter DREG = 1, 
    parameter MREG = 1,
    parameter PREG = 1, 
    parameter CARRYINREG = 1,
    parameter CARRYOUTREG = 1,
    parameter OPMODEREG = 1,
    parameter CARRYINSEL = "OPMODE5", //or opcode
    parameter B_INPUT = "CASCADE", //direct for B input and Cascade for BCIN
    parameter RSTTYPE = "SYNC"
    )(
    input clk,
    input [7:0] opmode, 
    input CEA, 
    input CEB, 
    input CEC, 
    input CECARRYIN, 
    input CED, 
    input CEM, 
    input CEP,
    input CEOPMODE,
    input RSTA, //Reset for the A registers: (A0REG & A1REG).
    input RSTB, //Reset for the B registers: (B0REG & B1REG).
    input RSTC, //Reset for the C registers (CREG).
    input RSTCARRYIN, //Reset for the carry-in register (CYI) and the carry-out register (CYO).
    input RSTD, //Reset for the D register (DREG).
    input RSTM, //Reset for the multiplier register (MREG).
    input RSTOPMODE, //Reset for the opmode register (OPMODEREG).
    input RSTP,
    input [17:0] A, B, D, BCIN,
    input [47:0] C,
    input carryin,
    input [47:0] PCIN, //Cascade input for Port P.
    output reg [17:0] BCOUT, //Cascade output for Port B.
    output reg [47:0] PCOUT, //Cascade output for Port P.
    output reg [35:0] M,
    output reg [47:0] P,
    output reg carryout, 
    output reg carryoutf
    );

    localparam IS_SYNCRESET = (RSTTYPE == "SYNC") ; //this is for more synthesis friendly approach for vivado??
    localparam IS_BDIRECT = (B_INPUT == "DIRECT");
    localparam IS_CARRYINSEL_OPMODE = (CARRYINSEL == "OPMODE5");
    localparam IS_CARRYINSEL_CARRYIN = (CARRYINSEL == "CARRYIN");
    localparam ZERO = 0;

    reg [17:0] A_ff, B_ff, D_ff;
    reg [47:0] C_ff;
    reg [7:0] opmode_ff;
    reg CYI;
    reg CYO;
    reg [35:0] M_ff;
    reg [47:0] P_ff;

    //registers for addsub modules & MUXES
    wire [17:0] pre_addsub_out;
    wire pre_addsub_cout;
    
    wire [17:0] MUX1_out;
    wire [35:0] mult_out;

    reg [47:0] D_A_B_concatenated;
    wire [47:0] MUX_X_out;

    wire [47:0] MUX_Z_out;
    
    //second pipelines
    reg [17:0] A1_ff;
    reg [17:0] B1_ff;

    wire [47:0] post_addsub_out;
    wire post_addsub_cout;

    //first declaration of reset = 8 types
    //for A
    generate
    if (A0REG) begin : gen_pipeline_A
        if (IS_SYNCRESET) begin
            always @(posedge clk) begin
                if (RSTA)
                    A_ff <= 18'b0;
                else if (CEA)
                    A_ff <= A;
            end
        end else begin
            always @(posedge clk or posedge RSTA) begin
                if (RSTA)
                    A_ff <= 18'b0;
                else if (CEA)
                    A_ff <= A;
            end
        end
    end else begin : gen_comb_A
        always @* begin
            A_ff = A;
        end
    end
    endgenerate

    //for B
    generate
    if (B0REG) begin : gen_pipeline_B0
        if (IS_SYNCRESET) begin
            always @(posedge clk) begin
                if (RSTB)
                    B_ff <= 18'b0;
                else if (CEB) begin
                    if (IS_BDIRECT)
                        B_ff <= B;
                    else
                        B_ff <= BCIN;
                end
            end
        end else begin
            always @(posedge clk or posedge RSTB) begin
                if (RSTB)
                    B_ff <= 18'b0;
                else if (CEB) begin
                    if (IS_BDIRECT)
                        B_ff <= B;
                    else
                        B_ff <= BCIN;
                end
            end
        end
    end else begin : gen_comb_B0
        always @* begin
            if (IS_BDIRECT)
                B_ff = B;
            else
                B_ff = BCIN;
        end
    end
    endgenerate


    //for C
    generate
    if (CREG) begin : gen_pipeline_C
        if (IS_SYNCRESET) begin
            always @(posedge clk) begin
                if (RSTC)
                    C_ff <= 48'b0;
                else if (CEC)
                    C_ff <= C;
            end
        end else begin
            always @(posedge clk or posedge RSTC) begin
                if (RSTC)
                    C_ff <= 48'b0;
                else if (CEC)
                    C_ff <= C;
            end
        end
    end else begin : gen_comb_C
        always @* begin
            C_ff = C;
        end
    end
    endgenerate


    //for D
    generate
    if (DREG) begin : gen_pipeline_D
        if (IS_SYNCRESET) begin
            always @(posedge clk) begin
                if (RSTD)
                    D_ff <= 18'b0;
                else if (CED)
                    D_ff <= D;
            end
        end else begin
            always @(posedge clk or posedge RSTD) begin
                if (RSTD)
                    D_ff <= 18'b0;
                else if (CED)
                    D_ff <= D;
            end
        end
    end else begin : gen_comb_D
        always @* begin
            D_ff = D;
        end
    end
    endgenerate

    //for opmode
    generate
    if (OPMODEREG) begin : gen_pipeline_opmode
        if (IS_SYNCRESET) begin
            always @(posedge clk) begin
                if (RSTOPMODE)
                    opmode_ff <= 8'b0;
                else if (CEOPMODE)
                    opmode_ff <= opmode;
            end
        end else begin
            always @(posedge clk or posedge RSTOPMODE) begin
                if (RSTOPMODE)
                    opmode_ff <= 8'b0;
                else if (CEOPMODE)
                    opmode_ff <= opmode;
            end
        end
    end else begin : gen_comb_opmode
        always @* begin
            opmode_ff = opmode;
        end
    end
    endgenerate


    //for carry in and carryout
    generate
    if (CARRYINREG) begin : gen_pipeline_CYI
        if (IS_SYNCRESET) begin
            always @(posedge clk) begin
                if (RSTCARRYIN)
                    CYI <= 0;
                else if (CECARRYIN) begin
                    if (CARRYINSEL == "OPMODE5")
                        CYI <= opmode_ff[5];
                    else if (CARRYINSEL == "CARRYIN")
                        CYI <= carryin;
                    else
                        CYI <= 1'b0;
                end
            end
        end else begin
            always @(posedge clk or posedge RSTCARRYIN) begin
                if (RSTCARRYIN)
                    CYI <= 0;
                else if (CECARRYIN) begin
                    if (CARRYINSEL == "OPMODE5")
                        CYI <= opmode_ff[5];
                    else if (CARRYINSEL == "CARRYIN")
                        CYI <= carryin;
                    else
                        CYI <= 1'b0;
                end
            end
        end
    end else begin : gen_comb_CYI
        always @* begin
            if (CARRYINSEL == "OPMODE5")
                CYI = opmode_ff[5];
            else if (CARRYINSEL == "CARRYIN")
                CYI = carryin;
            else
                CYI = 1'b0;
        end
    end
    endgenerate


    AddSub #(
        .WIDTH(18)
    ) pre_addsub (
        .mode(opmode_ff[6]), 
        .in1(D_ff), 
        .in2(B_ff), 
        .carryin(ZERO), 
        .out(pre_addsub_out),
        .cout(pre_addsub_cout)
    );
    
    MUX2 #(
        .WIDTH(18)
    )pre_addsub_mux (
        .in1(B_ff), 
        .in2(pre_addsub_out), 
        .sel(opmode_ff[4]), 
        .out(MUX1_out));

    generate
    if (B1REG) begin : gen_pipeline_B1
        if (IS_SYNCRESET) begin
            always @(posedge clk) begin
                if (RSTB)
                    B1_ff <= 18'b0;
                else if (CEB)
                    B1_ff <= MUX1_out;
            end
        end else begin
            always @(posedge clk or posedge RSTB) begin
                if (RSTB)
                    B1_ff <= 18'b0;
                else if (CEB)
                    B1_ff <= MUX1_out;
            end
        end
    end else begin : gen_comb_B1
        always @* begin
            B1_ff = MUX1_out;
        end
    end
    endgenerate
    
    always @(*) begin
        BCOUT = B1_ff;
        D_A_B_concatenated= {D_ff[11:0], A_ff[17:0], B_ff[17:0]};
    end   

    generate
    if (A1REG) begin : gen_pipeline_A1
        if (IS_SYNCRESET) begin
            always @(posedge clk) begin
                if (RSTA)
                    A1_ff <= 18'b0;
                else if (CEA)
                    A1_ff <= A_ff;
            end
        end else begin
            always @(posedge clk or posedge RSTA) begin
                if (RSTA)
                    A1_ff <= 18'b0;
                else if (CEA)
                    A1_ff <= A_ff;
            end
        end
    end else begin : gen_comb_A1
        always @* begin
            A1_ff = A_ff;
        end
    end
    endgenerate

    multiplier m1(
        .m1(B1_ff), 
        .m2(A1_ff), 
        .out(mult_out));

    //M
    generate
    if (MREG) begin : gen_pipeline_M
        if (IS_SYNCRESET) begin
            always @(posedge clk) begin
                if (RSTM)
                    M_ff <= 36'b0;
                else if (CEM)
                    M_ff <= mult_out;
            end
        end else begin
            always @(posedge clk or posedge RSTM) begin
                if (RSTM)
                    M_ff <= 36'b0;
                else if (CEM)
                    M_ff <= mult_out;
            end
        end
    end else begin : gen_comb_M
        always @* begin
            M_ff = mult_out;
        end
    end
    endgenerate


    always @(M_ff) begin
        M= M_ff;
    end

    // X MUX
    MUX4_1 #(
        .WIDTH_IN1(48),
        .WIDTH_IN2(48),
        .WIDTH_IN3(36),
        .WIDTH_OUT(48)
    ) u_mux4_1 (
        .sel(opmode_ff[1:0]),
        .in1(PCOUT),
        .in2(D_A_B_concatenated),
        .in3(mult_out),
        //.in4(ZERO),
        .out(MUX_X_out)
    );

    //Z MUX
    MUX4_1 #(
        .WIDTH_IN1(48),
        .WIDTH_IN2(48),
        .WIDTH_IN3(48),
        .WIDTH_OUT(48)
    ) u_mux4_2 (
        .sel(opmode_ff[3:2]),
        .in1(P_ff),
        .in2(C_ff),
        .in3(PCIN),
        //.in4(ZERO),
        .out(MUX_Z_out)
    );


    AddSub #(
        .WIDTH(48)
    ) post_addsub(
        .mode(opmode_ff[7]),
        .in1(MUX_Z_out),
        .in2(MUX_X_out),
        .carryin(CYI),
        .out(post_addsub_out),
        .cout(post_addsub_cout)
    );
    
    //for P
    generate
    if (PREG) begin : gen_pipeline_P
        if (IS_SYNCRESET) begin
            always @(posedge clk) begin
                if (RSTP)
                    P_ff <= 48'b0;
                else if (CEP)
                    P_ff <= post_addsub_out;
            end
        end else begin
            always @(posedge clk or posedge RSTP) begin
                if (RSTP)
                    P_ff <= 48'b0;
                else if (CEP)
                    P_ff <= post_addsub_out;
            end
        end
    end else begin : gen_comb_P
        always @* begin
            P_ff = post_addsub_out;
        end
    end
    endgenerate

    always@(P_ff) begin
        P= P_ff;
        PCOUT= P_ff;
    end

    //CYO
    generate
    if (CARRYOUTREG) begin : gen_pipeline_carryout
        if (IS_SYNCRESET) begin
            always @(posedge clk) begin
                if (RSTCARRYIN)
                    CYO <= 0;
                else if (CECARRYIN)
                    CYO <= post_addsub_cout;
            end
        end else begin
            always @(posedge clk or posedge RSTCARRYIN) begin
                if (RSTP)
                    CYO <= 0;
                else if (CEP)
                    CYO <= post_addsub_cout;
            end
        end
    end else begin : gen_comb_carryout
        always @* begin
            CYO = post_addsub_cout;
        end
    end
    endgenerate

    always @(CYO) begin
        carryout = CYO;
        carryoutf= CYO;
    end

endmodule