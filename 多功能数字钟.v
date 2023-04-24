//1、顶层设计
//top实现代码
module top(
         input clk_100m, clr, mode,set_signal,s,set_alarm,add,speed, //s=0:调整min ;  s=1:h
         output [5:0] pos,//位码，FPGA上有8个数码管，用6个数码管
         output [6:0] seg,//段码，7段显示数码管
         output T ,//指示上午/下午 
         output a,b,alarm,led 
         );
          reg [3:0] t0r,t1r,t2r,t3r,t4r,t5r; //BCD码  
          wire clk_1hz,clk_4hz,clk_1k,clk_5h;
          wire [3:0] t0,t1,t2,t3,t4,t5,seg1; //BCD码
          wire cp,add_p,clk;
        assign t0=t0r, t1=t1r, t2=t2r, t3=t3r, t4=t4r,t5=t5r;
        assign clk=speed ? clk_4hz : clk_1hz;//为方便测试，用的4hz
        assign cp=set_signal?add_p:clk; 
        assign a=1, b=1;
    clk_div diver( clk_100m, clk_1k, clk_5h,clk_4hz, clk_1hz,clr); //分频      
    prevent P(clk_1k,0,0,add,add_p); //防抖动
    clock clock_1(cp,set_signal,clr,mode,s,T,t0,t1,t2,t3,t4,t5);  
    display Time(clk_5h,t0,t1,t2,t3,t4,t5,pos,seg1);               
    bcd show(seg1,seg);
    alarm A(clk_4hz,clr, set_alarm,t0,t1,t2,t3,t4,t5,alarm);  
    CLOCK C(clk_4hz,t0,t1,t2,t3,t4,t5,led );    //报时         
endmodule

//2、时钟分频模块
//时钟分频模块实现
module clk_div(
    input clk_100m,
    output clk_1k,//125hz
    output clk_5h,//200hz
    output clk_4hz,
    output clk_1hz,
    input cr
    );
reg clk_1k_r,clk_5h_r,clk_4hz_r,clk_1hz_r;
assign clk_1k=clk_1k_r;
assign clk_5h=clk_5h_r;
assign clk_4hz=clk_4hz_r;
assign clk_1hz=clk_1hz_r;
reg [18:0] count_1k=0;
reg [16:0] count_5h=0;
reg [23:0] count_4hz=0;
reg [25:0] count_1hz=0;
always @ (posedge clk_100m,negedge cr)

    if(!cr)
    begin
        clk_1k_r<=0; clk_5h_r<=0;
        clk_4hz_r<=0; clk_1hz_r<=0;
    end
    else 
 begin
        if(count_1k<19'b1100_0011_0101_0000_000)
        count_1k<=count_1k+1;
        else  begin
            count_1k<=0;
            clk_1k_r<=~clk_1k_r;
        end
        if(count_5h<17'b11_0000_1101_010_0000)
            count_5h<=count_5h+1;
        else  begin
            count_5h<=0;
            clk_5h_r<=~clk_5h_r;
        end
         if(count_4hz<24'b10_1111_1010_1111_0000_1000_00)
               count_4hz<=count_4hz+1;
        else  begin
            count_4hz<=0;
            clk_4hz_r<=~clk_4hz_r;
                    end
                if(count_1hz<26'b10_1111_1010_1111_0000_1000_0000)
                count_1hz<=count_1hz+1;
                else
                begin
                    count_1hz<=0;
                    clk_1hz_r<=~clk_1hz_r;
                end
    end
endmodule

//3、主体计时模块
//计时实现代码：
module clock(cp,set,clr,mode,s,T,t0,t1,t2,t3,t4,t5);   //54：32：10 
          input   cp,set,clr,mode;//mode=1:24h
          input s; //s=0:调整min ;  s=1:h
          output  reg T=0;  //上午T=0，下午T=1
          output  reg [3:0] t0,t1,t2,t3,t4,t5;
always@(posedge cp )  
begin
        if(~clr) begin t0<=0;t1<=0;t2<=0;t3<=0;t4<=0;t5<=0; end
        else if(set) 
          begin 
                    if(~mode&&(  (t5==1&&t4>1)||(t5==2) ) ) begin t5<=t5-1;t4<=t4-2;end
                    if(mode&&T&&( (t5==1&&t4<2)||(t5==0&&t4>0) ))  begin t5<=t5+1;t4<=t4+2;end
                    if(s ==0) begin//设置分
                          t2<=t2+1;
                          if(t2==9)  begin t2<=0; t3<=t3+1;
                                           if(t3==5) begin t3<=0; t4<=t4+1; end
                                          end
                                  end
                    if(s ==1) begin t4<=t4+1;//设置小时
                                  if(mode)  T<=( (t5==1)&&(t4>1) )||(t5==2)  ?1:0; 
                                  if(t4==9)  begin t4<=0; t5<=t5+1; end
                                  if(mode&&t5==2&&t4==3)    //24小时
                                            begin t5<=0; t4<=0; end
                                  if(~mode&&t5==1&&t4==2)  //12小时
                                            begin t5<=0; t4<=1;T<=~T;end
                                   end
                                   
             end                      
        else 
                                 begin t0<=t0+1;
                                     if(~mode&&(  (t5==1&&t4>1)||(t5==2) ) ) 
                                                  begin t5<=t5-1;t4<=t4-2;end
                                     if(t0==9) begin t0<=0;t1<=t1+1;//阻塞赋值混用
                                             if(t1==5) begin t1<=0;t2<=t2+1; //秒
                                                       if(t2==9)  begin t2<=0; t3<=t3+1;
                                                             if(t3==5) begin t3<=0; t4<=t4+1;//分
                                                                                            if(mode) T<=( t5==1&&t4>1 )||(t5>2)  ?1:0; 
                                                                                            if(t4==9)   begin t4<=0; t5<=t5+1;end
                                                                                            if(mode&&t5==2&&t4==3)    //24小时
                                                                                                       begin t5<=0; t4<=0;end
                                                                                            if(~mode&&t5==1&&t4==2)  //12小时
                                                                                                        begin t5<=0; t4<=1;T<=~T;end
                                                                                      
                                                                                 end
                                                                       end
                                                           end
                                                 end
                                       end            
 end     
endmodule

//RS触发器防止抖动模块
module prevent(    //RS触发器，防止抖动
          input cp,R,S,CP,
          output reg pCP=0
          );
always@(posedge cp)
          begin
                    case({R,S})
                    2'b00:pCP<=CP;
                    2'b01:pCP<=1'b1;
                    2'b10:pCP<=0;
                    2'b11:pCP<=1'bx;
                    endcase
          end
endmodule

//CLOCK测试代码
`timescale 1ns / 1ps
module clock_sim( );
          reg cp,set,clr,mode,s;
          wire T;
          wire [3:0]t0,t1,t2,t3,t4,t5;
                    clock clock_1(cp,set,clr,mode,s,T,t0,t1,t2,t3,t4,t5);
          
          initial  cp=1; 
          always #5 cp=~cp;
          
   initial
         begin
             set=0;s=0;mode=0;clr=1;#100
             clr=0;#10
             clr=1;#1000              
             set=1;#1000
             s=1; #1000 $stop;
          end
endmodule

//4、数码管译码模块
//数码管译码实现
module bcd( 
  input  [3:0] bcd_in,
  output  reg[6:0] out
);
always @(bcd_in)
  begin
          case(bcd_in)
                  4'b0000:out <=7'b1000000;//40         
                  4'b0001:out <=7'b1111001;//79         
                  4'b0010:out <=7'b0100100;//24         
                  4'b0011:out <=7'b0110000;//30         
                  4'b0100:out <=7'b0011001;//19         
                  4'b0101:out <=7'b0010010;//12         
                  4'b0110:out <=7'b0000010;//2          
                  4'b0111:out <=7'b1111000;//78         
                  4'b1000:out <=7'b0000000;//0          
                  4'b1001:out <=7'b0010000;//10         
                  default: out <=7'b1111111;           
          endcase
  end
endmodule

//数码管动态扫描
module display(
                           input   cp,//1kHz
                           input   [3:0] T0,T1,T2,T3,T4,T5,
                           output [5:0] pos,
                           output [3:0]seg1
                          );
         reg [2:0]cout=0;
         reg [3:0]seg_r=0;
         reg [5:0]pos_r=0;
         assign seg1=seg_r;
         assign pos=pos_r;
         always@(posedge cp)
                begin
                    if(cout<6) cout<=cout+1;
                    else cout<=0;
                    case(cout)
                              5:      begin seg_r<=T0;  pos_r<=6'b011111;   end
                              4:      begin seg_r<=T1;  pos_r<=6'b101111;   end
                              3:      begin seg_r<=T2;  pos_r<=6'b110111;   end
                              2:      begin seg_r<=T3;  pos_r<=6'b111011;   end
                              1:      begin seg_r<=T4;  pos_r<=6'b111101;   end
                              0:      begin seg_r<=T5;  pos_r<=6'b111110;   end
                              default:  begin seg_r<=T0;  pos_r<=6'b111111;   end
                    endcase
                end               
endmodule

//5、附加功能
//12/24小时切换（已集成在主体模块中）

//整点报时（几点LED就闪几下）
module CLOCK(cp,t0,t1,t2,t3,t4,t5,led );
          input cp;
          input [3:0] t0,t1,t2,t3,t4,t5;
          output reg led=0;
          wire equ;
          reg [4:0] c1=0,c2=0;
          assign equ=({t3,t2,t1,t0}>=16'h0000 && {t3,t2,t1,t0}<16'h0009)? 1: 0;
          always @ (posedge cp)
          begin
                    if(~equ) begin c1<={1'b0,t5};c2<={t4,1'b0};end //c2要乘2
                    else begin
                          if(c2>0) begin c2<=c2-1;led<=~led;end
                          else if(c1>0) begin c1<=c1-1;c2<=5'd20;led<=~led; end
                          else led<=0;
                    end
          end
endmodule

//闹钟模块（LED代替闹钟）
module alarm(cp,clr, set_a,t0,t1,t2,t3,t4,t5,a); 
          input cp,clr,set_a;
          input [3:0] t0,t1,t2,t3,t4,t5;
          output reg a; //alarm
          reg [3:0] a0,a1,a2,a3,a4,a5;
     always @ (posedge cp,negedge clr)     
     begin
          if(~clr) begin a<=0;a0<=0;a1<=0;a2<=0;a3<=0;a4<=0;a5<=0;end
          else begin
                    if(set_a) begin a0<=t0;a1<=t1;a2<=t2;a3<=t3;a4<=t4;a5<=t4;end
                    else begin 
                              if( {a0,a1,a2,a3,a4,a5}=={t0,t1,t2,t3,t4,t5} )
                                        a<=1;
                              else a<=0;
                    end
          end
     end
endmodule

