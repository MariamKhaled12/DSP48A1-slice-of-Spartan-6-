module DSP_tb();
    
    // === Parameters for DUT ===
    parameter A0REG         = 1;
    parameter A1REG         = 1;
    parameter B0REG         = 1;
    parameter B1REG         = 1;
    parameter CREG          = 1;
    parameter DREG          = 1;
    parameter MREG          = 1;
    parameter PREG          = 1;
    parameter CARRYINREG    = 1;
    parameter CARRYOUTREG   = 1;
    parameter OPMODEREG     = 1;
    parameter CARRYINSEL    = "OPMODE5";  // or "OPMODE"
    parameter B_INPUT       = "DIRECT";   // or "CASCADE"
    parameter RSTTYPE       = "SYNC";     // or "ASYNC"

    // Clock & Reset
    reg clk;
    reg RSTA, RSTB, RSTC, RSTD, RSTCARRYIN, RSTM, RSTP, RSTOPMODE;

    // Clock enables
    reg CEA, CEB, CEC, CED, CEM, CEP, CECARRYIN, CEOPMODE;

    // Data inputs
    reg [17:0] A, B, D, BCIN;
    reg [47:0] C;
    reg [7:0] opmode;
    reg carryin;
    reg [47:0] PCIN;

    // Outputs
    wire [35:0] M;
    wire [47:0] P;
    wire carryout, carryoutf;
    wire [17:0] BCOUT;
    wire [47:0] PCOUT;

    DSP #(
        .A0REG(A0REG),
        .A1REG(A1REG),
        .B0REG(B0REG),
        .B1REG(B1REG),
        .CREG(CREG),
        .DREG(DREG),
        .MREG(MREG),
        .PREG(PREG),
        .CARRYINREG(CARRYINREG),
        .CARRYOUTREG(CARRYOUTREG),
        .OPMODEREG(OPMODEREG),
        .CARRYINSEL(CARRYINSEL),
        .B_INPUT(B_INPUT),
        .RSTTYPE(RSTTYPE)
    ) uut (
        .clk(clk),
        .opmode(opmode),
        .CEA(CEA), 
        .CEB(CEB), 
        .CEC(CEC), 
        .CECARRYIN(CECARRYIN), 
        .CED(CED), 
        .CEM(CEM), 
        .CEP(CEP),
        .CEOPMODE(CEOPMODE),
        .RSTA(RSTA),
        .RSTB(RSTB),
        .RSTC(RSTC),
        .RSTCARRYIN(RSTCARRYIN),
        .RSTD(RSTD),
        .RSTM(RSTM),
        .RSTOPMODE(RSTOPMODE),
        .RSTP(RSTP),
        .A(A),
        .B(B),
        .D(D),
        .BCIN(BCIN),
        .C(C),
        .carryin(carryin),
        .PCIN(PCIN),
        .BCOUT(BCOUT),
        .PCOUT(PCOUT),
        .M(M),
        .P(P),
        .carryout(carryout),
        .carryoutf(carryoutf)
    );

    initial begin
        clk = 0;
        forever #5 clk=~clk;
    end

    initial begin
        RSTA = 1; RSTB = 1; RSTC = 1; RSTD = 1;
        RSTM = 1; RSTP = 1; RSTOPMODE = 1; RSTCARRYIN = 1;

        A = 18'h3A1; B = 18'h7E2; D = 18'h1F3; BCIN = 18'h0A0;
        C = 48'hABCDE123456;
        opmode = 8'b01010101;
        carryin = 1'b1; PCIN = 1'b0;

        CEA = 0; CEB = 0; CEC = 0; CED = 0;
        CEM = 0; CEP = 0; CEOPMODE = 0; CECARRYIN = 0;

        @(negedge clk);
        @(negedge clk);

        if (P !== 0 || M !== 0 || carryout !== 0 || carryoutf !== 0 || PCOUT !== 0 || BCOUT !== 0) begin
            $display("❌ Reset Test Failed at time %0t", $time);
            $stop;
        end else begin
            $display("✅ Reset Test Passed at time %0t", $time);
        end

        RSTA = 0; RSTB = 0; RSTC = 0; RSTD = 0;
        RSTM = 0; RSTP = 0; RSTOPMODE = 0; RSTCARRYIN = 0;

        CEA = 1; CEB = 1; CEC = 1; CED = 1;
        CEM = 1; CEP = 1; CEOPMODE = 1; CECARRYIN = 1;

        @(negedge clk);
        @(negedge clk);

        opmode = 8'b11011101;  

        A = 18'd20;
        B = 18'd10;
        C = 48'd350;
        D = 18'd25;

        BCIN = 18'hF;           
        PCIN = 48'hDEADBEEF;    
        carryin = 1'b1;         

        repeat (4) @(negedge clk);

        if (BCOUT !== 18'hf || 
            M !== 36'h12C || 
            P !== 48'h32 || 
            PCOUT !== 48'h32 || 
            carryout !== 1'b0 || 
            carryoutf !== 1'b0) 
        begin
            $display("❌ Functional Test Failed at time %0t", $time);
            $display("    Expected BCOUT: 18'hf   | Got: %h", BCOUT);
            $display("    Expected M:     36'h12C | Got: %h", M);
            $display("    Expected P:     48'h32  | Got: %h", P);
            $display("    Expected PCOUT: 48'h32  | Got: %h", PCOUT);
            $display("    Expected Carry: 0       | Got: %b", carryout);
            //$stop;
        end else begin
            $display("✅ Functional Test Passed at time %0t", $time);
        end
        
        
        opmode = 8'b00010000;  

        A = 18'd20;
        B = 18'd10;
        C = 48'd350;
        D = 18'd25;

        BCIN = 18'hF;           
        PCIN = 48'hDEADBEEF;    
        carryin = 1'b1;         

        repeat(4) @(negedge clk);

        if (BCOUT !== 18'h23 || 
            M !== 36'h2bC || 
            P !== 48'h0 || 
            PCOUT !== 48'h0 || 
            carryout !== 1'b0 || 
            carryoutf !== 1'b0) 
        begin
            $display("❌ Functional Test Failed at time %0t", $time);
            $display("    Expected BCOUT: 18'h23   | Got: %h", BCOUT);
            $display("    Expected M:     36'h2bC | Got: %h", M);
            $display("    Expected P:     48'h0  | Got: %h", P);
            $display("    Expected PCOUT: 48'h0  | Got: %h", PCOUT);
            $display("    Expected Carry: 0       | Got: %b", carryout);
            //$stop;
        end else begin
            $display("✅ Functional Test Passed at time %0t", $time);
        end

        opmode = 8'b00001010;  

        A = 18'd20;
        B = 18'd10;
        C = 48'd350;
        D = 18'd25;

        BCIN = 18'hF;           
        PCIN = 48'hDEADBEEF;    
        carryin = 1'b1;         

        repeat(4) @(negedge clk);

        if (BCOUT !== 18'ha || 
            M !== 36'hC8 || 
            P !== 48'h0 || 
            PCOUT !== 48'h0 || 
            carryout !== 1'b0 || 
            carryoutf !== 1'b0) 
        begin
            $display("❌ Functional Test Failed at time %0t", $time);
            $display("    Expected BCOUT: 18'ha   | Got: %h", BCOUT);
            $display("    Expected M:     36'hC8 | Got: %h", M);
            $display("    Expected P:     48'h0  | Got: %h", P);
            $display("    Expected PCOUT: 48'h0  | Got: %h", PCOUT);
            $display("    Expected Carry: 0       | Got: %b", carryout);
            //$stop;
        end else begin
            $display("✅ Functional Test Passed at time %0t", $time);
        end


        opmode = 8'b10100111;  

        A = 18'd5;
        B = 18'd6;
        C = 48'd350;
        D = 18'd25;
        PCIN = 48'd3000;    

        BCIN = 18'hF;           
        carryin = 1'b1;         

        repeat(4) @(negedge clk);

        if (BCOUT !== 18'h6 || 
            M !== 36'h1E || 
            P !== 48'hfe6fffec0bb1 || 
            PCOUT !== 48'hfe6fffec0bb1 || 
            carryout !== 1'b1 || 
            carryoutf !== 1'b1) 
        begin
            $display("❌ Functional Test Failed at time %0t", $time);
            $display("    Expected BCOUT: 18'h6   | Got: %h", BCOUT);
            $display("    Expected M:     36'h1E | Got: %h", M);
            $display("    Expected P:     48'hfe6fffec0bb1  | Got: %h", P);
            $display("    Expected PCOUT: 48'hfe6fffec0bb1  | Got: %h", PCOUT);
            $display("    Expected Carry: 1       | Got: %b", carryout);
            //$stop;
        end else begin
            $display("✅ Functional Test Passed at time %0t", $time);
        end

        $stop;
    end

endmodule

