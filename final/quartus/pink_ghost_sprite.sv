module pink_ghost_sprite   (input          		Clk,                // 50 MHz clock
                                                Reset,              // Active-high reset signal
                                                frame_clk,          // The clock indicating a new frame (~60Hz)
                                                reload, hold,
                            input  		  [9:0] DrawX, DrawY, PacX, PacY,  // Current pixel coordinates
                            input         [2:0] direction_out,             //Pacman's current direction
                            input               is_pink_killer,      
                            output logic  [9:0] PinkGhostX, PinkGhostY,	   // How deep into the sprite the current pixel is
                            output logic   		is_pink_ghost,              // Whether current pixel belongs to Pac or background
                            output logic  [2:0] pink_ghost_direction_out,
                            output logic  [6:0] pink_ghost_animation_count,
                            output logic  [9:0] PinkGhostX_Monitor, PinkGhostY_Monitor);

    parameter [9:0] PinkGhost_X_Start = 10'd214 + PinkGhost_X_Min; //(X,Y) starting position of Pink Ghost upon reset
    parameter [9:0] PinkGhost_Y_Start = 10'd157 + PinkGhost_Y_Min; 
    parameter [9:0] PinkGhost_X_Min = 10'd64;      // Leftmost point on the X axis
    parameter [9:0] PinkGhost_X_Max = 10'd576;     // Rightmost point on the X axis
    parameter [9:0] PinkGhost_Y_Min = 10'd48;      // Topmost point on the Y axis
    parameter [9:0] PinkGhost_Y_Max = 10'd432;     // Bottommost point on the Y axis
    parameter [9:0] PinkGhost_X_Step = 10'd1;      // Step size on the X axis
    parameter [9:0] PinkGhost_Y_Step = 10'd1;      // Step size on the Y axis
    
    logic [9:0] PinkGhost_X_Pos, PinkGhost_X_Motion, PinkGhost_Y_Pos, PinkGhost_Y_Motion;
    logic [9:0] PinkGhost_X_Pos_in, PinkGhost_X_Motion_in, PinkGhost_Y_Pos_in, PinkGhost_Y_Motion_in;
    logic [2:0] direction, next_direction, prev_direction, next_prev_direction, alignment_direction, next_alignment_direction;
    logic [6:0] animation, next_animation; //registers used for animation sprites
    logic [9:0]     PinkGhost_lu_x, PinkGhost_lu_y, //Regular Wall Check
                    PinkGhost_l4_x, PinkGhost_l4_y,
                    PinkGhost_lc_x, PinkGhost_lc_y,
                    PinkGhost_l11_x, PinkGhost_l11_y,
                    PinkGhost_ld_x, PinkGhost_ld_y, 
                    PinkGhost_dl_x, PinkGhost_dl_y,
                    PinkGhost_d4_x, PinkGhost_d4_y,
                    PinkGhost_dc_x, PinkGhost_dc_y,
                    PinkGhost_d11_x, PinkGhost_d11_y,
                    PinkGhost_dr_x, PinkGhost_dr_y, 
                    PinkGhost_rd_x, PinkGhost_rd_y,
                    PinkGhost_r11_x, PinkGhost_r11_y, 
                    PinkGhost_rc_x, PinkGhost_rc_y, 
                    PinkGhost_r4_x, PinkGhost_r4_y, 
                    PinkGhost_ru_x, PinkGhost_ru_y, 
                    PinkGhost_ur_x, PinkGhost_ur_y,
                    PinkGhost_u11_x, PinkGhost_u11_y,
                    PinkGhost_uc_x, PinkGhost_uc_y,
                    PinkGhost_u4_x, PinkGhost_u4_y,
                    PinkGhost_ul_x, PinkGhost_ul_y;

    logic       lu_isWall, l4_isWall, lc_isWall, l11_isWall, ld_isWall, //Regular Wall Check 
                dl_isWall, d4_isWall, dc_isWall, d11_isWall, dr_isWall, 
                rd_isWall, r4_isWall, rc_isWall, r11_isWall, ru_isWall, 
                ur_isWall, u4_isWall, uc_isWall, u11_isWall, ul_isWall;

	 //////// Do not modify the always_ff blocks. ////////
    // Detect rising edge of frame_clk
    logic frame_clk_delayed, frame_clk_rising_edge;
    always_ff @ (posedge Clk) begin
        frame_clk_delayed <= frame_clk;
        frame_clk_rising_edge <= (frame_clk == 1'b1) && (frame_clk_delayed == 1'b0);
    end
	 // Update registers
    always_ff @ (posedge Clk)
    begin
        if (Reset || reload)
        begin
            PinkGhost_X_Pos <= PinkGhost_X_Start;
            PinkGhost_Y_Pos <= PinkGhost_Y_Start;
            PinkGhost_X_Motion <= 10'd0;
            PinkGhost_Y_Motion <= 10'd0;
			direction <= 3'b111;
        end
        else if(hold) begin
			PinkGhost_X_Pos <= PinkGhost_X_Pos;
            PinkGhost_Y_Pos <= PinkGhost_Y_Pos;
            PinkGhost_X_Motion <= 10'd0;
            PinkGhost_Y_Motion <= 10'd0;
			direction <= 3'b111;
		end
        else begin
            PinkGhost_X_Pos <= PinkGhost_X_Pos_in;
            PinkGhost_Y_Pos <= PinkGhost_Y_Pos_in;
            PinkGhost_X_Motion <= PinkGhost_X_Motion_in;
            PinkGhost_Y_Motion <= PinkGhost_Y_Motion_in;
				direction <= next_direction;
        end
    end
	
    always_ff @ (posedge Clk) begin
		if (Reset || reload)
			alignment_direction <= 3'b111;
		else
			alignment_direction <= next_alignment_direction;
	end
	
	 //Animation Registers
	always_ff @ (posedge Clk) begin
		if(Reset || reload)
			animation <= 7'd0;
		else
			animation <= next_animation;
	end
	
	logic flag, next_flag;
	always_ff @ (posedge Clk) begin
		if(Reset || reload)
			flag <= 1'b0;
		else 
			flag <= next_flag;
    end
	
	//Prev Direction Register
	always_ff @ (posedge Clk) begin
		if(Reset || reload)
			prev_direction <= 3'b000;
		else
			prev_direction <= next_prev_direction;
	end
	always_comb begin
		next_prev_direction = pink_ghost_direction_out;
		if(pink_ghost_direction_out == 3'b111)
			next_prev_direction = prev_direction;
	end
	
    //killer countdown
    logic [2:0] countdown, next_countdown;
	//delay a change in alignment
	always_ff @ (posedge Clk) begin
		if(Reset || reload)
			countdown <= 3'b011;
		else
			countdown <= next_countdown;
	end

    //random movement countdown
	logic [2:0] dumb_countdown, next_dumb_countdown;
	//delay a change in alignment
	always_ff @ (posedge Clk) begin
		if(Reset || reload)
			dumb_countdown <= 3'b111;
		else
			dumb_countdown <= next_dumb_countdown;
	end
    
    logic deciding, next_deciding; 
    always_ff @ (posedge Clk) begin
        if(Reset || reload)
            deciding <= 1'b1;
        else 
            deciding <= next_deciding;
    end

    logic [2:0] timer, next_timer;
    always_ff @ (posedge Clk) begin
        if(Reset || reload)
            timer <= 3'b000;
        else 
            timer <= next_timer;
    end
    wallChecker LU (.x(PinkGhost_lu_x), .y(PinkGhost_lu_y), .is_wall(lu_isWall));
    wallChecker L4 (.x(PinkGhost_l4_x), .y(PinkGhost_l4_y), .is_wall(l4_isWall));
    wallChecker LC (.x(PinkGhost_lc_x), .y(PinkGhost_lc_y), .is_wall(lc_isWall));
    wallChecker L11 (.x(PinkGhost_l11_x), .y(PinkGhost_l11_y), .is_wall(l11_isWall));
    wallChecker LD (.x(PinkGhost_ld_x), .y(PinkGhost_ld_y), .is_wall(ld_isWall));

    wallChecker DL (.x(PinkGhost_dl_x), .y(PinkGhost_dl_y), .is_wall(dl_isWall));
    wallChecker D4 (.x(PinkGhost_d4_x), .y(PinkGhost_d4_y), .is_wall(d4_isWall));
    wallChecker DC (.x(PinkGhost_dc_x), .y(PinkGhost_dc_y), .is_wall(dc_isWall));
    wallChecker D11 (.x(PinkGhost_d11_x), .y(PinkGhost_d11_y), .is_wall(d11_isWall));    
    wallChecker DR (.x(PinkGhost_dr_x), .y(PinkGhost_dr_y), .is_wall(dr_isWall));

    wallChecker RD (.x(PinkGhost_rd_x), .y(PinkGhost_rd_y), .is_wall(rd_isWall));
    wallChecker R11 (.x(PinkGhost_r11_x), .y(PinkGhost_r11_y), .is_wall(r11_isWall));
    wallChecker RC (.x(PinkGhost_rc_x), .y(PinkGhost_rc_y), .is_wall(rc_isWall));
    wallChecker R4 (.x(PinkGhost_r4_x), .y(PinkGhost_r4_y), .is_wall(r4_isWall));
    wallChecker RU (.x(PinkGhost_ru_x), .y(PinkGhost_ru_y), .is_wall(ru_isWall));

    wallChecker UR (.x(PinkGhost_ur_x), .y(PinkGhost_ur_y), .is_wall(ur_isWall));
    wallChecker U11 (.x(PinkGhost_u11_x), .y(PinkGhost_u11_y), .is_wall(u11_isWall));
    wallChecker UC (.x(PinkGhost_uc_x), .y(PinkGhost_uc_y), .is_wall(uc_isWall));
    wallChecker U4 (.x(PinkGhost_u4_x), .y(PinkGhost_u4_y), .is_wall(u4_isWall));
    wallChecker UL (.x(PinkGhost_ul_x), .y(PinkGhost_ul_y), .is_wall(ul_isWall));

	assign PinkGhostX_Monitor = PinkGhost_X_Pos;
	assign PinkGhostY_Monitor = PinkGhost_Y_Pos;
	 //animation register combinational logic
	assign pink_ghost_direction_out = direction;
	assign pink_ghost_animation_count = animation;
	
    logic [9:0] U_X, U_Y, L_X, L_Y, R_X, R_Y, D_X, D_Y, C_X, C_Y; //blocks in relation to a ghost sprite used in minimizing path distance
	int U_DistX, U_DistY, L_DistX, L_DistY, D_DistX, D_DistY, R_DistX, R_DistY, C_DistX, C_DistY, U_Dist, L_Dist, D_Dist, R_Dist, C_Dist; 
	int PacCenterX, PacCenterY, PinkGhostCenterX, PinkGhostCenterY;
	
    //Killer Always Comb
	always_comb begin
	 //position re-assignment from logic to int
		PacCenterX = PacX;
		PacCenterY = PacY;
		PinkGhostCenterX = PinkGhost_X_Pos;
		PinkGhostCenterY = PinkGhost_Y_Pos;
		
		U_X = PinkGhost_X_Pos;
		U_Y = PinkGhost_Y_Pos - 10'd1;
		
		L_X = PinkGhost_X_Pos - 10'd1;
		L_Y = PinkGhost_Y_Pos; 
		
		D_X = PinkGhost_X_Pos; 
		D_Y = PinkGhost_Y_Pos + 10'd1;
		
		R_X = PinkGhost_X_Pos + 10'd1;
		R_Y = PinkGhost_Y_Pos;
		
		C_X = PinkGhost_X_Pos;
		C_Y = PinkGhost_Y_Pos;
		
		U_DistX = PacX - U_X;
		U_DistY = PacY - U_Y;

		L_DistX = PacX - L_X;
		L_DistY = PacY - L_Y;
		
		D_DistX = PacX - D_X;
		D_DistY = PacY - D_Y;

		R_DistX = PacX - R_X;
		R_DistY = PacY - R_Y;
		
		C_DistX = PacX - C_X;
		C_DistY = PacY - C_Y;
		
		U_Dist = (U_DistX*U_DistX) + (U_DistY*U_DistY);
		L_Dist = (L_DistX*L_DistX) + (L_DistY*L_DistY);
		D_Dist = (D_DistX*D_DistX) + (D_DistY*D_DistY);
		R_Dist = (R_DistX*R_DistX) + (R_DistY*R_DistY);
		C_Dist = (C_DistX*C_DistX) + (C_DistY*C_DistY);		 
	end

    logic can_go_up, can_go_left, can_go_down, can_go_right;
    always_comb begin
        can_go_up    = ul_isWall == 1'b0 && u4_isWall == 1'b0 && uc_isWall == 1'b0 && u11_isWall == 1'b0 && ur_isWall == 1'b0;
        can_go_left  = lu_isWall == 1'b0 && l4_isWall == 1'b0 && lc_isWall == 1'b0 && l11_isWall == 1'b0 && ld_isWall == 1'b0;
        can_go_down  = dl_isWall == 1'b0 && d4_isWall == 1'b0 && dc_isWall == 1'b0 && d11_isWall == 1'b0 && dr_isWall == 1'b0;
        can_go_right = ru_isWall == 1'b0 && r4_isWall == 1'b0 && rc_isWall == 1'b0 && r11_isWall == 1'b0 && rd_isWall == 1'b0;
    end

	always_comb begin
        //by default, position/motion of PinkGhostman remains unchanged, but PinkGhostman is always being animated (except for when he colides or is still
        PinkGhost_X_Pos_in = PinkGhost_X_Pos;
        PinkGhost_Y_Pos_in = PinkGhost_Y_Pos;
        PinkGhost_X_Motion_in = PinkGhost_X_Motion;
        PinkGhost_Y_Motion_in = PinkGhost_Y_Motion;
        next_direction = direction;
        next_animation = animation;
		next_alignment_direction = alignment_direction;
		next_flag = flag;
		next_dumb_countdown = dumb_countdown;
        next_timer = timer;
		next_deciding = deciding;
		next_countdown = countdown;
        if(is_pink_killer == 1'b0) begin
            //update boundary checking pixel coordinates of the PinkGhostman sprite 
            PinkGhost_ul_x = PinkGhost_X_Pos  + 10'd0 - 10'd8 - 10'd64;
            PinkGhost_ul_y = PinkGhost_Y_Pos  + 10'd0 - 10'd9 - 10'd48 - 10'd1;
            PinkGhost_u4_x = PinkGhost_X_Pos  + 10'd0 - 10'd4 - 10'd64;
            PinkGhost_u4_y = PinkGhost_Y_Pos  + 10'd0 - 10'd9 - 10'd48 - 10'd1;
            PinkGhost_uc_x = PinkGhost_X_Pos  + 10'd0 - 10'd64;
            PinkGhost_uc_y = PinkGhost_Y_Pos  + 10'd0 - 10'd9 - 10'd48 - 10'd1;
            PinkGhost_u11_x = PinkGhost_X_Pos - 10'd0 + 10'd3 - 10'd64;
            PinkGhost_u11_y = PinkGhost_Y_Pos + 10'd0 - 10'd9 - 10'd48 - 10'd1;
            PinkGhost_ur_x = PinkGhost_X_Pos  - 10'd0 + 10'd7 - 10'd64;
            PinkGhost_ur_y = PinkGhost_Y_Pos  + 10'd0 - 10'd9 - 10'd48 - 10'd1;

            PinkGhost_ru_x = PinkGhost_X_Pos  - 10'd0 + 10'd8 - 10'd64 + 10'd1;
            PinkGhost_ru_y = PinkGhost_Y_Pos  + 10'd0 - 10'd8 - 10'd48;
            PinkGhost_r4_x = PinkGhost_X_Pos  - 10'd0 + 10'd8 - 10'd64 + 10'd1;
            PinkGhost_r4_y = PinkGhost_Y_Pos  + 10'd0 - 10'd4 - 10'd48;
            PinkGhost_rc_x = PinkGhost_X_Pos  - 10'd0 + 10'd8 - 10'd64 + 10'd1;
            PinkGhost_rc_y = PinkGhost_Y_Pos  + 10'd0 - 10'd48;
            PinkGhost_r11_x = PinkGhost_X_Pos - 10'd0 + 10'd8 - 10'd64 + 10'd1;
            PinkGhost_r11_y = PinkGhost_Y_Pos - 10'd0 + 10'd3 - 10'd48;
            PinkGhost_rd_x = PinkGhost_X_Pos  - 10'd0 + 10'd8 - 10'd64 + 10'd1;
            PinkGhost_rd_y = PinkGhost_Y_Pos  - 10'd0 + 10'd7 - 10'd48;

            PinkGhost_dr_x = PinkGhost_X_Pos  - 10'd0 + 10'd7 - 10'd64;
            PinkGhost_dr_y = PinkGhost_Y_Pos  - 10'd0 + 10'd8 - 10'd48 + 10'd1;
            PinkGhost_d11_x = PinkGhost_X_Pos - 10'd0 + 10'd3 - 10'd64;
            PinkGhost_d11_y = PinkGhost_Y_Pos - 10'd0 + 10'd8 - 10'd48 + 10'd1;
            PinkGhost_dc_x = PinkGhost_X_Pos  + 10'd0 - 10'd64;
            PinkGhost_dc_y = PinkGhost_Y_Pos  - 10'd0 + 10'd8 - 10'd48 + 10'd1;
            PinkGhost_d4_x = PinkGhost_X_Pos  + 10'd0 - 10'd4 - 10'd64;
            PinkGhost_d4_y = PinkGhost_Y_Pos  - 10'd0 + 10'd8 - 10'd48 + 10'd1;
            PinkGhost_dl_x = PinkGhost_X_Pos  + 10'd0 - 10'd8 - 10'd64;
            PinkGhost_dl_y = PinkGhost_Y_Pos  - 10'd0 + 10'd8 - 10'd48 + 10'd1;

            PinkGhost_ld_x = PinkGhost_X_Pos  + 10'd0 - 10'd9 - 10'd64 - 10'd1;
            PinkGhost_ld_y = PinkGhost_Y_Pos  - 10'd0 + 10'd7 - 10'd48;
            PinkGhost_l11_x = PinkGhost_X_Pos + 10'd0 - 10'd9 - 10'd64 - 10'd1;
            PinkGhost_l11_y = PinkGhost_Y_Pos - 10'd0 + 10'd3 - 10'd48;
            PinkGhost_lc_x = PinkGhost_X_Pos  + 10'd0 - 10'd9 - 10'd64 - 10'd1;
            PinkGhost_lc_y = PinkGhost_Y_Pos  + 10'd0 - 10'd48;
            PinkGhost_l4_x = PinkGhost_X_Pos  + 10'd0 - 10'd9 - 10'd64 - 10'd1;
            PinkGhost_l4_y = PinkGhost_Y_Pos  + 10'd0 - 10'd4 - 10'd48;
            PinkGhost_lu_x = PinkGhost_X_Pos  + 10'd0 - 10'd9 - 10'd64 - 10'd1; // (Center_coord - sprite_wall_check_offset - gradient_border_offset - 2pixel's_ahead_offset)
            PinkGhost_lu_y = PinkGhost_Y_Pos  + 10'd0 - 10'd8 - 10'd48;
        end
        else begin
			 //update boundary checking pixel coordinates of the PinkGhostman sprite 
            PinkGhost_ul_x = PinkGhost_X_Pos  + 10'd1 - 10'd8 - 10'd64;
            PinkGhost_ul_y = PinkGhost_Y_Pos  + 10'd1 - 10'd9 - 10'd48 - 10'd1;
            PinkGhost_u4_x = PinkGhost_X_Pos  + 10'd1 - 10'd4 - 10'd64;
            PinkGhost_u4_y = PinkGhost_Y_Pos  + 10'd1 - 10'd9 - 10'd48 - 10'd1;
            PinkGhost_uc_x = PinkGhost_X_Pos  + 10'd0 - 10'd64;
            PinkGhost_uc_y = PinkGhost_Y_Pos  + 10'd1 - 10'd9 - 10'd48 - 10'd1;
            PinkGhost_u11_x = PinkGhost_X_Pos - 10'd1 + 10'd3 - 10'd64;
            PinkGhost_u11_y = PinkGhost_Y_Pos + 10'd1 - 10'd9 - 10'd48 - 10'd1;
            PinkGhost_ur_x = PinkGhost_X_Pos  - 10'd1 + 10'd7 - 10'd64;
            PinkGhost_ur_y = PinkGhost_Y_Pos  + 10'd1 - 10'd9 - 10'd48 - 10'd1;

            PinkGhost_ru_x = PinkGhost_X_Pos  - 10'd1 + 10'd8 - 10'd64 + 10'd1;
            PinkGhost_ru_y = PinkGhost_Y_Pos  + 10'd1 - 10'd8 - 10'd48;
            PinkGhost_r4_x = PinkGhost_X_Pos  - 10'd1 + 10'd8 - 10'd64 + 10'd1;
            PinkGhost_r4_y = PinkGhost_Y_Pos  + 10'd1 - 10'd4 - 10'd48;
            PinkGhost_rc_x = PinkGhost_X_Pos  - 10'd1 + 10'd8 - 10'd64 + 10'd1;
            PinkGhost_rc_y = PinkGhost_Y_Pos  + 10'd0 - 10'd48;
            PinkGhost_r11_x = PinkGhost_X_Pos - 10'd1 + 10'd8 - 10'd64 + 10'd1;
            PinkGhost_r11_y = PinkGhost_Y_Pos - 10'd1 + 10'd3 - 10'd48;
            PinkGhost_rd_x = PinkGhost_X_Pos  - 10'd1 + 10'd8 - 10'd64 + 10'd1;
            PinkGhost_rd_y = PinkGhost_Y_Pos  - 10'd1 + 10'd7 - 10'd48;

            PinkGhost_dr_x = PinkGhost_X_Pos  - 10'd1 + 10'd7 - 10'd64;
            PinkGhost_dr_y = PinkGhost_Y_Pos  - 10'd1 + 10'd8 - 10'd48 + 10'd1;
            PinkGhost_d11_x = PinkGhost_X_Pos - 10'd1 + 10'd3 - 10'd64;
            PinkGhost_d11_y = PinkGhost_Y_Pos - 10'd1 + 10'd8 - 10'd48 + 10'd1;
            PinkGhost_dc_x = PinkGhost_X_Pos  + 10'd0 - 10'd64;
            PinkGhost_dc_y = PinkGhost_Y_Pos  - 10'd1 + 10'd8 - 10'd48 + 10'd1;
            PinkGhost_d4_x = PinkGhost_X_Pos  + 10'd1 - 10'd4 - 10'd64;
            PinkGhost_d4_y = PinkGhost_Y_Pos  - 10'd1 + 10'd8 - 10'd48 + 10'd1;
            PinkGhost_dl_x = PinkGhost_X_Pos  + 10'd1 - 10'd8 - 10'd64;
            PinkGhost_dl_y = PinkGhost_Y_Pos  - 10'd1 + 10'd8 - 10'd48 + 10'd1;

            PinkGhost_ld_x = PinkGhost_X_Pos  + 10'd1 - 10'd9 - 10'd64 - 10'd1;
            PinkGhost_ld_y = PinkGhost_Y_Pos  - 10'd1 + 10'd7 - 10'd48;
            PinkGhost_l11_x = PinkGhost_X_Pos + 10'd1 - 10'd9 - 10'd64 - 10'd1;
            PinkGhost_l11_y = PinkGhost_Y_Pos - 10'd1 + 10'd3 - 10'd48;
            PinkGhost_lc_x = PinkGhost_X_Pos  + 10'd1 - 10'd9 - 10'd64 - 10'd1;
            PinkGhost_lc_y = PinkGhost_Y_Pos  + 10'd0 - 10'd48;
            PinkGhost_l4_x = PinkGhost_X_Pos  + 10'd1 - 10'd9 - 10'd64 - 10'd1;
            PinkGhost_l4_y = PinkGhost_Y_Pos  + 10'd1 - 10'd4 - 10'd48;
            PinkGhost_lu_x = PinkGhost_X_Pos  + 10'd1 - 10'd9 - 10'd64 - 10'd1; // (Center_coord - sprite_wall_check_offset - gradient_border_offset - 2pixel's_ahead_offset)
            PinkGhost_lu_y = PinkGhost_Y_Pos  + 10'd1 - 10'd8 - 10'd48;
        end
        //update position and motion only at rising edge of frame clock 
        if(frame_clk_rising_edge) begin
            //direction timer
            if(timer == 3'b011)
                next_timer = 3'b000;
            else 
                next_timer = timer + 3'b001;
            
            //animation counting logic
            if(direction != 3'b111) begin
                if(animation == 7'd6) begin
                    next_flag = 1'b1;
                    next_animation = animation - 7'd1;
                end
                else if(animation == 7'd0) begin
                    next_flag = 1'b0;
                    next_animation = animation + 7'd1;
                end
                else if(animation != 7'd0 && animation != 7'd6 && flag == 1'b1)
                    next_animation = animation - 7'd1;
                else if (animation != 7'd0 && animation != 7'd6 && flag == 1'b0)
                    next_animation = animation + 7'd1;				
            end
            
            if(direction == 3'b000) begin
                if(ul_isWall == 1'b1 || u4_isWall == 1'b1 || uc_isWall == 1'b1 || u11_isWall == 1'b1 || ur_isWall == 1'b1) begin
                    PinkGhost_X_Motion_in = 10'd0;
                    PinkGhost_Y_Motion_in = 10'd0;
                    next_direction = 3'b111;
						next_animation = animation;
                end
            end
            else if (direction == 3'b001) begin
                if(lu_isWall == 1'b1 || l4_isWall == 1'b1 || lc_isWall == 1'b1 || l11_isWall == 1'b1 || ld_isWall == 1'b1) begin
                    PinkGhost_X_Motion_in = 10'd0;
                    PinkGhost_Y_Motion_in = 10'd0;
                    next_direction = 3'b111;
						next_animation = animation;						  
                end
            end
            else if (direction == 3'b010) begin
                if(dl_isWall == 1'b1 || d4_isWall == 1'b1 || dc_isWall == 1'b1 || d11_isWall == 1'b1 || dr_isWall == 1'b1) begin
                    PinkGhost_X_Motion_in = 10'd0;
                    PinkGhost_Y_Motion_in = 10'd0;
                    next_direction = 3'b111;
					next_animation = animation;						  
                end            
            end
            else if (direction == 3'b011) begin
                if(ru_isWall == 1'b1 || r4_isWall == 1'b1 || rc_isWall == 1'b1 || r11_isWall == 1'b1 || rd_isWall == 1'b1) begin
                    PinkGhost_X_Motion_in = 10'd0;
                    PinkGhost_Y_Motion_in = 10'd0;
                    next_direction = 3'b111;
					next_animation = animation;						  
                end           
            end



//////////////////////////////////////////////////// RANDOM MOVEMENT //////////////////////////////////////////////////////////////////
            if(is_pink_killer == 1'b0) begin
                if(dumb_countdown == 3'b000) begin
                    next_dumb_countdown = 3'b111; 
                    next_deciding = 1'b0; 
                end
                else if(dumb_countdown != 3'b111) 
                    next_dumb_countdown = dumb_countdown - 3'd1;
                if(deciding == 1'b0) begin
                    case (prev_direction)
                        3'b000:
                            next_deciding = (can_go_left == 1'b1 || can_go_right == 1'b1) ? 1'b1 : 1'b0; //|| can_go_up == 1'b1
                        3'b010:
                            next_deciding = (can_go_left == 1'b1 || can_go_right == 1'b1) ? 1'b1 : 1'b0; //|| can_go_down == 1'b1 
                        3'b001: 
                            next_deciding = (can_go_up == 1'b1 || can_go_down == 1'b1) ? 1'b1 : 1'b0; //|| can_go_left == 1'b1 
                        3'b011:
                            next_deciding = (can_go_up == 1'b1 || can_go_down == 1'b1) ? 1'b1 : 1'b0; //|| can_go_right == 1'b1
                        default: ;
                    endcase
                end
                if(deciding == 1'b1 && dumb_countdown == 3'b111) begin
                    case(timer)
                        3'b000: begin
                            //is up visitable and we were not going down before
                            if(can_go_up == 1'b1 && prev_direction != 3'b010) begin
                                next_dumb_countdown = dumb_countdown - 3'd1;
                                next_direction = 3'b000;
                                PinkGhost_X_Motion_in = 10'd0;
                                PinkGhost_Y_Motion_in = (~(PinkGhost_Y_Step) + 1'b1);
                            end
                            //is left visitable and we were not going left before
                            else if(can_go_left == 1'b1 && prev_direction != 3'b011) begin
                                next_dumb_countdown = dumb_countdown - 3'd1;
                                next_direction = 3'b001;
                                PinkGhost_X_Motion_in = (~(PinkGhost_X_Step) + 1'b1);
                                PinkGhost_Y_Motion_in = 10'd0;
                            end
                            //is down visitable and we were not going down before
                            else if(can_go_down == 1'b1 && prev_direction != 3'b000) begin
                                next_dumb_countdown = dumb_countdown - 3'd1;
                                next_direction = 3'b010;
                                PinkGhost_X_Motion_in = 10'd0;
                                PinkGhost_Y_Motion_in = PinkGhost_Y_Step;
                            end
                            //is right visitable and we were not going right before
                            else if(can_go_right == 1'b1 && prev_direction != 3'b001) begin
                                next_dumb_countdown = dumb_countdown - 3'd1;
                                next_direction = 3'b011;
                                PinkGhost_X_Motion_in = PinkGhost_X_Step;
                                PinkGhost_Y_Motion_in = 10'd0;
                            end
                        end
                        3'b001: begin
                            //is left visitable and we were not going left before
                            if(can_go_left == 1'b1 && prev_direction != 3'b011) begin
                                next_dumb_countdown = dumb_countdown - 3'd1;
                                next_direction = 3'b001;
                                PinkGhost_X_Motion_in = (~(PinkGhost_X_Step) + 1'b1);
                                PinkGhost_Y_Motion_in = 10'd0;
                            end
                            //is down visitable and we were not going down before
                            else if(can_go_down == 1'b1 && prev_direction != 3'b000) begin
                                next_dumb_countdown = dumb_countdown - 3'd1;
                                next_direction = 3'b010;
                                PinkGhost_X_Motion_in = 10'd0;
                                PinkGhost_Y_Motion_in = PinkGhost_Y_Step;
                            end
                            //is up visitable and we were not going down before
                            else if(can_go_up == 1'b1 && prev_direction != 3'b010) begin
                                next_dumb_countdown = dumb_countdown - 3'd1;
                                next_direction = 3'b000;
                                PinkGhost_X_Motion_in = 10'd0;
                                PinkGhost_Y_Motion_in = (~(PinkGhost_Y_Step) + 1'b1);
                            end
                            //is right visitable and we were not going right before
                            else if(can_go_right == 1'b1 && prev_direction != 3'b001) begin
                                next_dumb_countdown = dumb_countdown - 3'd1;
                                next_direction = 3'b011;
                                PinkGhost_X_Motion_in = PinkGhost_X_Step;
                                PinkGhost_Y_Motion_in = 10'd0;
                            end
                        end
                        3'b010: begin
                            //is down visitable and we were not going down before
                            if(can_go_down == 1'b1 && prev_direction != 3'b000) begin
                                next_dumb_countdown = dumb_countdown - 3'd1;
                                next_direction = 3'b010;
                                PinkGhost_X_Motion_in = 10'd0;
                                PinkGhost_Y_Motion_in = PinkGhost_Y_Step;
                            end
                            //is left visitable and we were not going left before
                            else if(can_go_left == 1'b1 && prev_direction != 3'b011) begin
                                next_dumb_countdown = dumb_countdown - 3'd1;
                                next_direction = 3'b001;
                                PinkGhost_X_Motion_in = (~(PinkGhost_X_Step) + 1'b1);
                                PinkGhost_Y_Motion_in = 10'd0;
                            end
                            //is right visitable and we were not going right before
                            else if(can_go_right == 1'b1 && prev_direction != 3'b001) begin
                                next_dumb_countdown = dumb_countdown - 3'd1;
                                next_direction = 3'b011;
                                PinkGhost_X_Motion_in = PinkGhost_X_Step;
                                PinkGhost_Y_Motion_in = 10'd0;
                            end
                            //is up visitable and we were not going down before
                            else if(can_go_up == 1'b1 && prev_direction != 3'b010) begin
                                next_dumb_countdown = dumb_countdown - 3'd1;
                                next_direction = 3'b000;
                                PinkGhost_X_Motion_in = 10'd0;
                                PinkGhost_Y_Motion_in = (~(PinkGhost_Y_Step) + 1'b1);
                            end
                        end
                        3'b011: begin
                            //is right visitable and we were not going right before
                            if(can_go_right == 1'b1 && prev_direction != 3'b001) begin
                                next_dumb_countdown = dumb_countdown - 3'd1;
                                next_direction = 3'b011;
                                PinkGhost_X_Motion_in = PinkGhost_X_Step;
                                PinkGhost_Y_Motion_in = 10'd0;
                            end
                            //is up visitable and we were not going down before
                            else if(can_go_up == 1'b1 && prev_direction != 3'b010) begin
                                next_dumb_countdown = dumb_countdown - 3'd1;
                                next_direction = 3'b000;
                                PinkGhost_X_Motion_in = 10'd0;
                                PinkGhost_Y_Motion_in = (~(PinkGhost_Y_Step) + 1'b1);
                            end
                            //is down visitable and we were not going down before
                            else if(can_go_down == 1'b1 && prev_direction != 3'b000) begin
                                next_dumb_countdown = dumb_countdown - 3'd1;
                                next_direction = 3'b010;
                                PinkGhost_X_Motion_in = 10'd0;
                                PinkGhost_Y_Motion_in = PinkGhost_Y_Step;
                            end
                            //is left visitable and we were not going left before
                            else if(can_go_left == 1'b1 && prev_direction != 3'b011) begin
                                next_dumb_countdown = dumb_countdown - 3'd1;
                                next_direction = 3'b001;
                                PinkGhost_X_Motion_in = (~(PinkGhost_X_Step) + 1'b1);
                                PinkGhost_Y_Motion_in = 10'd0;
                            end
                        end
                    endcase
                end
            end
            ////////////////////////////////////////////////////KILLER PATHFINDING-ISH //////////////////////////////////////////////////////////////////
            else begin
                if(countdown == 3'b000) begin
                    next_countdown = 3'b011; 
                    next_alignment_direction = 3'b111; 
                end
                if (alignment_direction != 3'b111) begin
                    case(alignment_direction)
                        3'b000: begin
                            //previously aligned and wanted to go up, so when the next available up movement is allowed, go up
                            if(ul_isWall == 1'b0 && u4_isWall == 1'b0 && uc_isWall == 1'b0 && u11_isWall == 1'b0 && ur_isWall == 1'b0) begin
                                //next_alignment_direction = 3'b111;
                                next_countdown = countdown - 3'd1; 
                                next_direction = 3'b000;
                                PinkGhost_X_Motion_in = 10'd0;
                                PinkGhost_Y_Motion_in = (~(PinkGhost_Y_Step) + 1'b1);
                            end
                            //can't move up
                            else begin
                                //try to move left
                                if(lu_isWall == 1'b0 && l4_isWall == 1'b0 && lc_isWall == 1'b0 && l11_isWall == 1'b0 && ld_isWall == 1'b0) begin
                                    next_direction = 3'b001;
                                    PinkGhost_X_Motion_in = (~(PinkGhost_X_Step) + 1'b1);
                                    PinkGhost_Y_Motion_in = 10'd0;
                                end
                                //can't move left --> check right
                                else if(ru_isWall == 1'b0 && r4_isWall == 1'b0 && rc_isWall == 1'b0 && r11_isWall == 1'b0 && rd_isWall == 1'b0) begin
                                    next_direction = 3'b011;
                                    PinkGhost_X_Motion_in = PinkGhost_X_Step;
                                    PinkGhost_Y_Motion_in = 10'd0;
                                end
                            end
                        end
                        3'b001: begin
                            //previously aligned and wanted to go left, so when the next available left movement is allowed, go left
                            if(lu_isWall == 1'b0 && l4_isWall == 1'b0 && lc_isWall == 1'b0 && l11_isWall == 1'b0 && ld_isWall == 1'b0) begin
                                //next_alignment_direction = 3'b111;
                                next_countdown = countdown - 3'd1; 							
                                next_direction = 3'b001;
                                PinkGhost_X_Motion_in = (~(PinkGhost_X_Step) + 1'b1);
                                PinkGhost_Y_Motion_in = 10'd0;
                            end
                            //can't move left
                            else begin
                                //try to move up
                                if(ul_isWall == 1'b0 && u4_isWall == 1'b0 && uc_isWall == 1'b0 && u11_isWall == 1'b0 && ur_isWall == 1'b0) begin
                                    next_direction = 3'b000;
                                    PinkGhost_X_Motion_in = 10'd0;
                                    PinkGhost_Y_Motion_in = (~(PinkGhost_Y_Step) + 1'b1);
                                end
                                //can't move up --> check down
                                else if(dl_isWall == 1'b0 && d4_isWall == 1'b0 && dc_isWall == 1'b0 && d11_isWall == 1'b0 && dr_isWall == 1'b0) begin
                                    next_direction = 3'b010;
                                    PinkGhost_X_Motion_in = 10'd0;
                                    PinkGhost_Y_Motion_in = PinkGhost_Y_Step;
                                end
                            end
                        end
                        3'b010: begin
                            //previously aligned and wanted to go down, so when the next available down movement is allowed, go down
                            if(dl_isWall == 1'b0 && d4_isWall == 1'b0 && dc_isWall == 1'b0 && d11_isWall == 1'b0 && dr_isWall == 1'b0) begin
                                //next_alignment_direction = 3'b111;
                                next_countdown = countdown - 3'd1; 							
                                next_direction = 3'b010;
                                PinkGhost_X_Motion_in = 10'd0;
                                PinkGhost_Y_Motion_in = PinkGhost_Y_Step;
                            end
                            //can't move down
                            else begin
                                //try to move right
                                if(ru_isWall == 1'b0 && r4_isWall == 1'b0 && rc_isWall == 1'b0 && r11_isWall == 1'b0 && rd_isWall == 1'b0) begin
                                    next_direction = 3'b011;
                                    PinkGhost_X_Motion_in = PinkGhost_X_Step;
                                    PinkGhost_Y_Motion_in = 10'd0;
                                end
                                //can't move right --> check left
                                else if(lu_isWall == 1'b0 && l4_isWall == 1'b0 && lc_isWall == 1'b0 && l11_isWall == 1'b0 && ld_isWall == 1'b0) begin
                                    next_direction = 3'b001;
                                    PinkGhost_X_Motion_in = (~(PinkGhost_X_Step) + 1'b1);
                                    PinkGhost_Y_Motion_in = 10'd0;
                                end
                            end
                        end
                        3'b011: begin
                            //previously aligned and wanted to go right, so when the next available right movement is allowed, go right
                            if(ru_isWall == 1'b0 && r4_isWall == 1'b0 && rc_isWall == 1'b0 && r11_isWall == 1'b0 && rd_isWall == 1'b0) begin
                                //next_alignment_direction = 3'b111;
                                next_countdown = countdown - 3'd1; 							
                                next_direction = 3'b011;
                                PinkGhost_X_Motion_in = PinkGhost_X_Step;
                                PinkGhost_Y_Motion_in = 10'd0;
                            end
                            //can't move right
                            else begin
                                //try to move down
                                if(dl_isWall == 1'b0 && d4_isWall == 1'b0 && dc_isWall == 1'b0 && d11_isWall == 1'b0 && dr_isWall == 1'b0) begin
                                    next_direction = 3'b010;
                                    PinkGhost_X_Motion_in = 10'd0;
                                    PinkGhost_Y_Motion_in = PinkGhost_Y_Step;
                                end
                                //can't move down --> check up
                                else if(ul_isWall == 1'b0 && u4_isWall == 1'b0 && uc_isWall == 1'b0 && u11_isWall == 1'b0 && ur_isWall == 1'b0) begin
                                    next_direction = 3'b000;
                                    PinkGhost_X_Motion_in = 10'd0;
                                    PinkGhost_Y_Motion_in = (~(PinkGhost_Y_Step) + 1'b1);
                                end
                            end
                        end
                        default: ;
                    endcase
                end
                else begin
                    if(C_Dist < 16) begin
                        next_direction = 3'b111;
                        PinkGhost_X_Motion_in = 10'd0;
                        PinkGhost_Y_Motion_in = 10'd0;
                    end
                    else if((PacCenterY - PinkGhostCenterY <= 1) && (PacCenterY - PinkGhostCenterY >= -1)) begin
                        //Check Horizonal Movement -> left is ideal?
                        if(L_Dist < R_Dist) begin
                            //check left
                            if(lu_isWall == 1'b0 && l4_isWall == 1'b0 && lc_isWall == 1'b0 && l11_isWall == 1'b0 && ld_isWall == 1'b0) begin
                                next_direction = 3'b001;
                                PinkGhost_X_Motion_in = (~(PinkGhost_X_Step) + 1'b1);
                                PinkGhost_Y_Motion_in = 10'd0;
                            end
                            //cant move left -> check right
                            else if(ru_isWall == 1'b0 && r4_isWall == 1'b0 && rc_isWall == 1'b0 && r11_isWall == 1'b0 && rd_isWall == 1'b0) begin
                                next_direction = 3'b011;
                                PinkGhost_X_Motion_in = PinkGhost_X_Step;
                                PinkGhost_Y_Motion_in = 10'd0;
                                //set flag = left
                                next_alignment_direction = 3'b001;
                            end
                            else begin
                                //set flag = left
                                next_alignment_direction = 3'b001;
                            end
                        end
                        //right is ideal
                        else begin
                            if(ru_isWall == 1'b0 && r4_isWall == 1'b0 && rc_isWall == 1'b0 && r11_isWall == 1'b0 && rd_isWall == 1'b0) begin
                                next_direction = 3'b011;
                                PinkGhost_X_Motion_in = PinkGhost_X_Step;
                                PinkGhost_Y_Motion_in = 10'd0;
                            end
                            else if(lu_isWall == 1'b0 && l4_isWall == 1'b0 && lc_isWall == 1'b0 && l11_isWall == 1'b0 && ld_isWall == 1'b0) begin
                                next_direction = 3'b001;
                                PinkGhost_X_Motion_in = (~(PinkGhost_X_Step) + 1'b1);
                                PinkGhost_Y_Motion_in = 10'd0;
                                //set flag = right
                                next_alignment_direction = 3'b011;
                            end
                            else begin
                                //set flag = right
                                next_alignment_direction = 3'b011;
                            end
                        end
                    end
                    else if((PacCenterX - PinkGhostCenterX <= 1) && (PacCenterX - PinkGhostCenterX >= -1)) begin
                        //Check Vertical Movement --> check if up is ideal
                        if(U_Dist < D_Dist) begin
                            //check up
                            if(ul_isWall == 1'b0 && u4_isWall == 1'b0 && uc_isWall == 1'b0 && u11_isWall == 1'b0 && ur_isWall == 1'b0) begin
                                next_direction = 3'b000;
                                PinkGhost_X_Motion_in = 10'd0;
                                PinkGhost_Y_Motion_in = (~(PinkGhost_Y_Step) + 1'b1);
                            end
                            //can't go up so check down
                            else if(dl_isWall == 1'b0 && d4_isWall == 1'b0 && dc_isWall == 1'b0 && d11_isWall == 1'b0 && dr_isWall == 1'b0) begin
                                next_direction = 3'b010;
                                PinkGhost_X_Motion_in = 10'd0;
                                PinkGhost_Y_Motion_in = PinkGhost_Y_Step;
                                //set flag = up
                                next_alignment_direction = 3'b000;
                            end
                            else begin
                                //set flag = up
                                next_alignment_direction = 3'b000;
                            end
                        end
                        //down is ideal
                        else begin
                            //check down
                            if(dl_isWall == 1'b0 && d4_isWall == 1'b0 && dc_isWall == 1'b0 && d11_isWall == 1'b0 && dr_isWall == 1'b0) begin
                                next_direction = 3'b010;
                                PinkGhost_X_Motion_in = 10'd0;
                                PinkGhost_Y_Motion_in = PinkGhost_Y_Step;
                            end
                            //can't go down so check up
                            else if(ul_isWall == 1'b0 && u4_isWall == 1'b0 && uc_isWall == 1'b0 && u11_isWall == 1'b0 && ur_isWall == 1'b0) begin
                                next_direction = 3'b000;
                                PinkGhost_X_Motion_in = 10'd0;
                                PinkGhost_Y_Motion_in = (~(PinkGhost_Y_Step) + 1'b1);
                                //set flag = down
                                next_alignment_direction = 3'b010;
                            end
                            else begin
                                //set flag = down
                                next_alignment_direction = 3'b010;
                            end
                        end
                    end
                    else if(U_Dist < D_Dist) begin //moving up is best
                        //check to see if we can move up
                        if(ul_isWall == 1'b0 && u4_isWall == 1'b0 && uc_isWall == 1'b0 && u11_isWall == 1'b0 && ur_isWall == 1'b0) begin
                            next_direction = 3'b000;
                            PinkGhost_X_Motion_in = 10'd0;
                            PinkGhost_Y_Motion_in = (~(PinkGhost_Y_Step) + 1'b1);
                        end
                        //prioritize horizontal over the down option
                        else begin
                            //left is ideal
                            if(L_Dist < R_Dist) begin
                                //check left
                                if(lu_isWall == 1'b0 && l4_isWall == 1'b0 && lc_isWall == 1'b0 && l11_isWall == 1'b0 && ld_isWall == 1'b0) begin
                                    next_direction = 3'b001;
                                    PinkGhost_X_Motion_in = (~(PinkGhost_X_Step) + 1'b1);
                                    PinkGhost_Y_Motion_in = 10'd0;
                                end
                                //can't go up or left
                                else begin
                                    //check right
                                    if(ru_isWall == 1'b0 && r4_isWall == 1'b0 && rc_isWall == 1'b0 && r11_isWall == 1'b0 && rd_isWall == 1'b0) begin //go right
                                        next_direction = 3'b011;
                                        PinkGhost_X_Motion_in = PinkGhost_X_Step;
                                        PinkGhost_Y_Motion_in = 10'd0;
                                    end
                                    //can't go up or left or right so go down
                                    else if(dl_isWall == 1'b0 && d4_isWall == 1'b0 && dc_isWall == 1'b0 && d11_isWall == 1'b0 && dr_isWall == 1'b0) begin
                                        next_direction = 3'b010;
                                        PinkGhost_X_Motion_in = 10'd0;
                                        PinkGhost_Y_Motion_in = PinkGhost_Y_Step;
                                    end
                                end
                            end
                            //right is ideal or just as good as left
                            else begin
                                //check right
                                if(ru_isWall == 1'b0 && r4_isWall == 1'b0 && rc_isWall == 1'b0 && r11_isWall == 1'b0 && rd_isWall == 1'b0) begin
                                    next_direction = 3'b011;
                                    PinkGhost_X_Motion_in = PinkGhost_X_Step;
                                    PinkGhost_Y_Motion_in = 10'd0;
                                end
                                //can't go up or right
                                else begin
                                    //check left
                                    if(lu_isWall == 1'b0 && l4_isWall == 1'b0 && lc_isWall == 1'b0 && l11_isWall == 1'b0 && ld_isWall == 1'b0) begin //go left
                                        next_direction = 3'b001;
                                        PinkGhost_X_Motion_in = (~(PinkGhost_X_Step) + 1'b1);
                                        PinkGhost_Y_Motion_in = 10'd0;
                                    end
                                    //can't go up or right or left so go down
                                    else if(dl_isWall == 1'b0 && d4_isWall == 1'b0 && dc_isWall == 1'b0 && d11_isWall == 1'b0 && dr_isWall == 1'b0) begin
                                        next_direction = 3'b010;
                                        PinkGhost_X_Motion_in = 10'd0;
                                        PinkGhost_Y_Motion_in = PinkGhost_Y_Step;
                                    end
                                end
                            end
                        end						
                    end
                    else begin //moving down is best ---> (D_Dist <= U_Dist)
                        //check down
                        if(dl_isWall == 1'b0 && d4_isWall == 1'b0 && dc_isWall == 1'b0 && d11_isWall == 1'b0 && dr_isWall == 1'b0) begin
                            next_direction = 3'b010;
                            PinkGhost_X_Motion_in = 10'd0;
                            PinkGhost_Y_Motion_in = PinkGhost_Y_Step;
                        end
                        //can't go down so prioritize horizontal over down
                        else begin
                            //left is ideal
                            if(L_Dist < R_Dist) begin
                                //check left
                                if(lu_isWall == 1'b0 && l4_isWall == 1'b0 && lc_isWall == 1'b0 && l11_isWall == 1'b0 && ld_isWall == 1'b0) begin
                                    next_direction = 3'b001;
                                    PinkGhost_X_Motion_in = (~(PinkGhost_X_Step) + 1'b1);
                                    PinkGhost_Y_Motion_in = 10'd0;
                                end
                                //can't go down or left
                                else begin
                                    //check right
                                    if(ru_isWall == 1'b0 && r4_isWall == 1'b0 && rc_isWall == 1'b0 && r11_isWall == 1'b0 && rd_isWall == 1'b0) begin //go right
                                        next_direction = 3'b011;
                                        PinkGhost_X_Motion_in = PinkGhost_X_Step;
                                        PinkGhost_Y_Motion_in = 10'd0;
                                    end
                                    //can't go down or left or right so go up
                                    else if(ul_isWall == 1'b0 && u4_isWall == 1'b0 && uc_isWall == 1'b0 && u11_isWall == 1'b0 && ur_isWall == 1'b0) begin
                                        next_direction = 3'b010;
                                        PinkGhost_X_Motion_in = 10'd0;
                                        PinkGhost_Y_Motion_in = (~(PinkGhost_Y_Step) + 1'b1);
                                    end
                                end
                            end
                            //right is ideal or just as good as left
                            else begin
                                //check right
                                if(ru_isWall == 1'b0 && r4_isWall == 1'b0 && rc_isWall == 1'b0 && r11_isWall == 1'b0 && rd_isWall == 1'b0) begin
                                    next_direction = 3'b011;
                                    PinkGhost_X_Motion_in = PinkGhost_X_Step;
                                    PinkGhost_Y_Motion_in = 10'd0;
                                end
                                //can't go down or right
                                else begin
                                    //check left
                                    if(lu_isWall == 1'b0 && l4_isWall == 1'b0 && lc_isWall == 1'b0 && l11_isWall == 1'b0 && ld_isWall == 1'b0) begin //go left
                                        next_direction = 3'b001;
                                        PinkGhost_X_Motion_in = (~(PinkGhost_X_Step) + 1'b1);
                                        PinkGhost_Y_Motion_in = 10'd0;
                                    end
                                    //can't go down or right or left so go up
                                    else if(ul_isWall == 1'b0 && u4_isWall == 1'b0 && uc_isWall == 1'b0 && u11_isWall == 1'b0 && ur_isWall == 1'b0) begin
                                        next_direction = 3'b010;
                                        PinkGhost_X_Motion_in = 10'd0;
                                        PinkGhost_Y_Motion_in = (~(PinkGhost_Y_Step) + 1'b1);
                                    end
                                end
                            end
                        end
                    end				
                end	
            end
            if((PinkGhost_Y_Pos >= PinkGhost_Y_Max) || (PinkGhost_Y_Pos <= PinkGhost_Y_Min)) begin
                if(PinkGhost_Y_Pos >= PinkGhost_Y_Max)
                    PinkGhost_Y_Pos_in = PinkGhost_Y_Min + 10'd1 + PinkGhost_Y_Motion_in;
                else
                    PinkGhost_Y_Pos_in = PinkGhost_Y_Max - 10'd1 + PinkGhost_Y_Motion_in;
            end
            else if((PinkGhost_X_Pos >= PinkGhost_X_Max) || (PinkGhost_X_Pos <= PinkGhost_X_Min)) begin
                if(PinkGhost_X_Pos >= PinkGhost_X_Max) begin //going right
                    PinkGhost_X_Pos_in = PinkGhost_X_Min + 10'd1 + PinkGhost_X_Motion_in;
                end
                else begin //going left
                    PinkGhost_X_Pos_in = PinkGhost_X_Max - 10'd1 + PinkGhost_X_Motion_in;
                end
            end	             
            else begin
                PinkGhost_X_Pos_in = PinkGhost_X_Pos + PinkGhost_X_Motion;
                PinkGhost_Y_Pos_in = PinkGhost_Y_Pos + PinkGhost_Y_Motion;                
            end
        end
    end
    
	 //determine whether the DrawX and DrawY a PinkGhostman coordinate 
    assign PinkGhostX = DrawX - PinkGhost_X_Pos + 10'd8;
    assign PinkGhostY = DrawY - PinkGhost_Y_Pos + 10'd8;    
    
    always_comb begin
        if (PinkGhostX >= 10'd1 && PinkGhostX < 10'd14 && PinkGhostY >= 10'd1 && PinkGhostY < 10'd14 && hold == 1'b0) 
            is_pink_ghost = 1'b1;
        else
            is_pink_ghost = 1'b0;
    end
endmodule 