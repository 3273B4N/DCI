#Description:
#This program writes a "Hello World" message on the OLED display attached to SIWA using the GPIO ports to emulate an #I2C protocol.
#-------------------------------------------------------------------------------
.section .text
.globl _start
.equ data_mem, 0x00001000 #this is the address where this program's data memory starts
.equ pkt_qt, 3#117    #each pkt is 1 byte
.equ bit_qt, 9	  #each byte to be sent needs 9 cycles: (8 bits of data/addr/cmd + 1 ack)
.equ wait_time, 10#10000
_start:
	jal x0,_main
int_handler:
#-------------------------------------------------------------------------------
#On the interrupt handler, check if the timer bit is set
#-------------------------------------------------------------------------------
	csrrs t0,2,x0      #read the mcauseA CSR and check if timer code happened (3'b011)
	andi t1,t0,7       #mask the code bits (mcause bits 25, 26 and 27) and discard the rest
	li t0,3            #011 code
	bne t0,t1,_return
	li s3,1            #raise flag if timer code appeared
_return:
	mret	           #return to the main program
_main:
#-------------------------------------------------------------------------------
#First, the data memory needs to be filled with the OLED commands
#-------------------------------------------------------------------------------
	li s6,data_mem
	li t0,0x0000007A		#Address:011110+SA0:1+R/W:0= 01111010
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x00000080		#1000000 = Control bit + D/C bit + 6 0s
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x00000028		#Change to Fundamental Function set: two-line display, 5x8 character font
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x0000007A		#Address:011110+SA0:1+R/W:0= 01111010
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x00000080		#1000000 = Control bit + D/C bit + 6 0s
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x00000008		#Display, cursor and blinking off
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x0000007A		#Address:011110+SA0:1+R/W:0= 01111010
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x00000080		#1000000 = Control bit + D/C bit + 6 0s
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x0000002A		#Change to Extended Function set
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x0000007A		#Address:011110+SA0:1+R/W:0= 01111010
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x00000080		#1000000 = Control bit + D/C bit + 6 0s
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x00000008		#Two-line display set and 5-dot font config
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x0000007A		#Address:011110+SA0:1+R/W:0= 01111010
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x00000080		#1000000 = Control bit + D/C bit + 6 0s
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x00000079		#Enable OLED Command set
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x0000007A		#Address:011110+SA0:1+R/W:0= 01111010
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x00000080		#1000000 = Control bit + D/C bit + 6 0s
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x000000DA		#SEG config (this is how it is supposed to write on the screen). 1st command of 2 commands
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x0000007A		#Address:011110+SA0:1+R/W:0= 01111010
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x00000080		#1000000 = Control bit + D/C bit + 6 0s
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x00000000		#SEG config - 2nd part
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x0000007A		#Address:011110+SA0:1+R/W:0= 01111010
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x00000080		#1000000 = Control bit + D/C bit + 6 0s
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x00000078		#Disable OLED Command set
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x0000007A		#Address:011110+SA0:1+R/W:0= 01111010
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x00000080		#1000000 = Control bit + D/C bit + 6 0s
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x00000028		#Change to Fundamental Function set
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x0000007A		#Address:011110+SA0:1+R/W:0= 01111010
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x00000080		#1000000 = Control bit + D/C bit + 6 0s
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x00000001		#clear display and set DDRAM addr to 0'h
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x0000007A		#Address:011110+SA0:1+R/W:0= 01111010
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x00000080		#1000000 = Control bit + D/C bit + 6 0s
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x0000000F		#display ON, cursor on, blinking on
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x0000007A		#Address:011110+SA0:1+R/W:0= 01111010
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x00000040		#0100000 = Control bit + D/C bit + 6 0s
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x00000048		#letter "H" 01000001 (ascii code)
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x0000007A		#Address:011110+SA0:1+R/W:0= 01111010
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x00000040		#0100000 = Control bit + D/C bit + 6 0s
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x00000045		#letter "E" 01000001 (ascii code)
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x0000007A		#Address:011110+SA0:1+R/W:0= 01111010
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x00000040		#0100000 = Control bit + D/C bit + 6 0s
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x0000004C		#letter "L" 01000001 (ascii code)
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x0000007A		#Address:011110+SA0:1+R/W:0= 01111010
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x00000040		#0100000 = Control bit + D/C bit + 6 0s
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x0000004C		#letter "L" 01000001 (ascii code)
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x0000007A		#Address:011110+SA0:1+R/W:0= 01111010
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x00000040		#0100000 = Control bit + D/C bit + 6 0s
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x0000004F		#letter "O" 01000001 (ascii code)
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x0000007A		#Address:011110+SA0:1+R/W:0= 01111010
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x00000040		#0100000 = Control bit + D/C bit + 6 0s
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x00000020		#letter " " 01000001 (ascii code)
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x0000007A		#Address:011110+SA0:1+R/W:0= 01111010
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x00000040		#0100000 = Control bit + D/C bit + 6 0s
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x00000057		#letter "W" 01000001 (ascii code)
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x0000007A		#Address:011110+SA0:1+R/W:0= 01111010
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x00000040		#0100000 = Control bit + D/C bit + 6 0s
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x0000004F		#letter "O" 01000001 (ascii code)
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x0000007A		#Address:011110+SA0:1+R/W:0= 01111010
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x00000040		#0100000 = Control bit + D/C bit + 6 0s
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x00000052		#letter "R" 01000001 (ascii code)
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x0000007A		#Address:011110+SA0:1+R/W:0= 01111010
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x00000040		#0100000 = Control bit + D/C bit + 6 0s
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x0000004C		#letter "L" 01000001 (ascii code)
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x0000007A		#Address:011110+SA0:1+R/W:0= 01111010
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x00000040		#0100000 = Control bit + D/C bit + 6 0s
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x00000044		#letter "D" 01000001 (ascii code)
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x0000007A		#Address:011110+SA0:1+R/W:0= 01111010
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x00000040		#0100000 = Control bit + D/C bit + 6 0s
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x00000021		#letter "!" 01000001 (ascii code)
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x0000007A		#Address:011110+SA0:1+R/W:0= 01111010
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x00000080		#1000000 = Control bit + D/C bit + 6 0s
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x000000C0		#set DDRAM addr to 40'h
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x0000007A		#Address:011110+SA0:1+R/W:0= 01111010
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x00000040		#0100000 = Control bit + D/C bit + 6 0s
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x0000004D		#letter "M" 01000001 (ascii code)
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x0000007A		#Address:011110+SA0:1+R/W:0= 01111010
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x00000040		#0100000 = Control bit + D/C bit + 6 0s
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x00000079		#letter "y" 01000001 (ascii code)
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x0000007A		#Address:011110+SA0:1+R/W:0= 01111010
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x00000040		#0100000 = Control bit + D/C bit + 6 0s
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x00000020		#letter " " 01000001 (ascii code)
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x0000007A		#Address:011110+SA0:1+R/W:0= 01111010
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x00000040		#0100000 = Control bit + D/C bit + 6 0s
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x0000006E		#letter "n" 01000001 (ascii code)
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x0000007A		#Address:011110+SA0:1+R/W:0= 01111010
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x00000040		#0100000 = Control bit + D/C bit + 6 0s
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x00000061		#letter "a" 01000001 (ascii code)
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x0000007A		#Address:011110+SA0:1+R/W:0= 01111010
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x00000040		#0100000 = Control bit + D/C bit + 6 0s
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x0000006D		#letter "m" 01000001 (ascii code)
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x0000007A		#Address:011110+SA0:1+R/W:0= 01111010
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x00000040		#0100000 = Control bit + D/C bit + 6 0s
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x00000065		#letter "e" 01000001 (ascii code)
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x0000007A		#Address:011110+SA0:1+R/W:0= 01111010
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x00000040		#0100000 = Control bit + D/C bit + 6 0s
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x00000020		#letter " " 01000001 (ascii code)
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x0000007A		#Address:011110+SA0:1+R/W:0= 01111010
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x00000040		#0100000 = Control bit + D/C bit + 6 0s
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x00000069		#letter "i" 01000001 (ascii code)
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x0000007A		#Address:011110+SA0:1+R/W:0= 01111010
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x00000040		#0100000 = Control bit + D/C bit + 6 0s
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x00000073		#letter "s" 01000001 (ascii code)
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x0000007A		#Address:011110+SA0:1+R/W:0= 01111010
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x00000040		#0100000 = Control bit + D/C bit + 6 0s
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x00000020		#letter " " 01000001 (ascii code)
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x0000007A		#Address:011110+SA0:1+R/W:0= 01111010
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x00000040		#0100000 = Control bit + D/C bit + 6 0s
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x00000053		#letter "S" 01000001 (ascii code)
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x0000007A		#Address:011110+SA0:1+R/W:0= 01111010
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x00000040		#0100000 = Control bit + D/C bit + 6 0s
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x00000049		#letter "I" 01000001 (ascii code)
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x0000007A		#Address:011110+SA0:1+R/W:0= 01111010
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x00000040		#0100000 = Control bit + D/C bit + 6 0s
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x00000057		#letter "W" 01000001 (ascii code)
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x0000007A		#Address:011110+SA0:1+R/W:0= 01111010
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x00000040		#0100000 = Control bit + D/C bit + 6 0s
	sb t0,0(s6)
	addi s6,s6,1
	li t0,0x00000041		#letter "A" 01000001 (ascii code)
	sb t0,0(s6)
	addi s6,s6,1
#-------------------------------------------------------------------------------
#Then, we need to set up the GPIO0-3 to '0', the timer and the interrupt addr whe then timer ticks
#GPIO0 is SA0
#GPIO1 is /RST
#GPIO2 is SDA
#GPIO3 is SCL
#-------------------------------------------------------------------------------
#t0 register holds the GPIO CSR value
	li t0,0x0000000F
#-------------------------------------------------------------------------------
#The CSR read mode must be enabled on the MIE/MIP register. t1 holds this value
#-------------------------------------------------------------------------------
	li t1,0x00010000
#-------------------------------------------------------------------------------
#The timer is set to 2500(decimal). Each generated clk cycle is calculated to take 10000 20MHz cycles (expected #generated clock = 2KHz), but we need to make changes at every 1/4 cycle to emulate the I2C protocol.
#-------------------------------------------------------------------------------
#	li t2,2500
	li t2,5000			#50ns x 5000 counts = 250us each tick
#-------------------------------------------------------------------------------
#Set the interrupt addr on MVTEC CSR
#-------------------------------------------------------------------------------
	li t3,4
#-------------------------------------------------------------------------------
#Write the CSR registers
#-------------------------------------------------------------------------------
	csrrw x0,0,t1
	csrrw x0,4,t0
	csrrw x0,5,t3
	csrrw x0,6,t2
#-------------------------------------------------------------------------------
#Register s0 holds the state phase of the I2C protocol:
#0: reset_1 (clear the RST signal)
#1: reset_2 (set back the REST signal)
#2: SDA must go down (before starting this routine, it checks if there are packets to be sent, if not the program stops)
#3: SCL_1 (SCL goes from '1' to '0')
#4: Data_bit: Asign bit packet to SDA output
#5: SCL_2 (SCL goes from '0' to '1')
#6: Stop bit
#7: When packet has been transfered, SDA must go up
#-------------------------------------------------------------------------------
#Register s1 holds the number of packets to be sent
#The packets will be stored in memory
#Register s2 holds the number 1/4 SCL cycles needed for each packet
#Register s3 holds the tick event
#Register s4 holds the current state of the I2C protocol sequence
#Register s5 holds the counter for the 1/4 SCL cycles
#Register s6 holds the data_memory pointer
#Register s7 holds the current packet
#Register s8 holds the ACK wait time in cycles count or the stop bit wait time
#Register s9 counts 3 pkts to know when to stop a transfer
#Register s10 holds the flag that indicates a delay of 100ms when the dislay turns on
#-------------------------------------------------------------------------------
	li s0,0
	li s1,pkt_qt
	li s2,bit_qt
	li s3,0
	li s5,0 		#counter for the number of 1/4 SCL cycles
	li s6,data_mem
	li s7,0
	li s8,0
	li s9,0
	li s10,0
#-------------------------------------------------------------------------------
#initiate the timer to send the message and wait for the timer interruption
#-------------------------------------------------------------------------------
	li t1,0x00010001
	csrrw x0,0,t1
	jal x0,_loop
#-------------------------------------------------------------------------------
#checks the next state
#-------------------------------------------------------------------------------
_check:
	li t0,0
	beq s0,t0,_rst_1
	li t0,1
	beq s0,t0,_rst_2
	li t0,2
	beq s0,t0,_init
	li t0,3
	beq s0,t0,_scl_1
	li t0,4
	beq s0,t0,_data_bit
	li t0,5
	beq s0,t0,_scl_2
	li t0,6
	beq s0,t0,_stop
	#li t0,7
	#beq s0,t0,_stop_wait
#-------------------------------------------------------------------------------
#clear RST signal (GPIO1 goes down)
#-------------------------------------------------------------------------------
_rst_1:
	li t1,0x0000000D
	csrrw x0,4,t1
	addi s0,s0,1
	jal x0,_loop_1
#-------------------------------------------------------------------------------
#set back the RST signal (GPIO1 goes up)
#-------------------------------------------------------------------------------
_rst_2:
	li t1,0x0000000F
	csrrw x0,4,t1
	li t0,4		#1ms = 4 cicles x 250us each cycle
	bne s8,t0,_rst_wait
	addi s0,s0,1
	li s8,0
	jal x0,_loop_1
_rst_wait:
	addi s8,s8,1
	jal x0,_loop_1
#-------------------------------------------------------------------------------
#After reset, the program must start here everytime a packet is going to be sent
#-------------------------------------------------------------------------------
_init:
#-------------------------------------------------------------------------------
#First, check if all packets have been sent, then finish the program; if not, then load and send a packet
#-------------------------------------------------------------------------------
	bge x0,s1,_end
	lb s7,0(s6)	   #load packet
	addi s6,s6,1       #data pointer +1
#-------------------------------------------------------------------------------
#Proceed with the initilization: clear the SDA signal (GPIO2 goes down)
#-------------------------------------------------------------------------------
	li t1,0x0000000B
	csrrw x0,4,t1
	addi s0,s0,1
	jal x0,_loop_1
#-------------------------------------------------------------------------------
#SCL loop (GPIO3 goes down)
#-------------------------------------------------------------------------------
_scl_1:
	li t0,0x0000008 #mask to clear the GPIO3 bit
	csrrc x0,4,t0
	addi s0,s0,1
	li t2,8
	bne s5,t2,_output_gpio
	li t1,0x00000400		#set the GPIO2 as an input to receive the ACK bit using a mask
	csrrs x0,0,t1
	lb s7,0(s6)			#also start loading the next packet
	addi s6,s6,1
	li t1,0x0000000F
	bne s7,t1,_output_gpio
	li s10,1
_output_gpio:
	li t2,9
	bne s5,t2,_not_ack
	#li t0,4				#wait 1 full clock cycle before changing back the GPIO to output mode
	#bne s8,t0,_input_gpio
	li t1,0x00000400		#set the GPIO2 as an output to send new data using a mask
	csrrc x0,0,t1
	li t2,0x00000004 		#mask to clear the GPIO2 bit
	csrrc x0,4,t2	
#	jal x0,_input_gpio
#_input_gpio:
#	li t0,8
#	bne s8,t0,_loop_ack
#	li s8,0
#	li s5,0
#	jal x0,_loop_1
#_loop_ack:
#	addi s0,s0,-1
#	addi s8,s8,1
_not_ack:
	jal x0,_loop_1
#-------------------------------------------------------------------------------
#Load the left most bit of the packet into the SDA output (GPIO2)
#-------------------------------------------------------------------------------
_data_bit:
	li t2,8
	addi s0,s0,1
	beq s5,t2,_ack_bit
	beq s1,x0,_stop_bit
	li t0,7		 #since we need to send MSBs first, this is the maximum number of shifts to the right
	sub t0,t0,s5	 #the number of shifts to the right vary according to the bit sent
	srl t0,s7,t0      #shift to the right
	andi t0,t0,1     #take only the right most bit for the SDA output
	li t1,1
	li t2,0x00000004 #mask to clear or set the GPIO2 bit
	beq t0,t1,_one
	csrrc x0,4,t2
	jal x0,_loop_1
_one:
	csrrs x0,4,t2
_ack_bit:
	
	jal x0,_loop_1
_stop_bit:
	li t2,0x00000004 #mask to clear or set the GPIO2 bit
	csrrc x0,4,t2
	jal x0,_loop_1
#-------------------------------------------------------------------------------
#SCL loop (GPIO3 goes up)
#-------------------------------------------------------------------------------
_scl_2:
	li t0,0x00000008 #mask to set the GPIO3 bit
	csrrs x0,4,t0
	li t0,9
	bne s5,t0,_loop_scl
	li s5,0
	li t0,3
	addi s1,s1,-1
	addi s9,s9,1
	bne s9,t0,_not_3rd_pkt
	addi s0,s0,1
	li s9,0
	jal ra,_loop_1
_not_3rd_pkt:
_loop_scl:
	addi s5,s5,1
	addi s0,s0,-2
	jal x0,_loop_1
#-------------------------------------------------------------------------------
#Stop bit, set SDA bit (GPIO2 goes up)
#-------------------------------------------------------------------------------
_stop:
	li t1,0x0000000F
	csrrw x0,4,t1
	li t0,8
	li t1,1
	bne s10,t1,_not_100ms
	li t0,400
_not_100ms:
	bne s8,t0,_stop_wait
	bge x0,s1,_end
	li s0,2
	li s8,0
	li s10,0
	addi s6,s6,-1			#the memory pointer must decrease once since the next packet is already preloaded
	jal x0,_loop_1
_stop_wait:
	addi s8,s8,1
	jal x0,_loop_1
#-------------------------------------------------------------------------------
#_if the internal_timer ticks, then check which is the next state
#-------------------------------------------------------------------------------
_loop_1:
	li s3,0
_loop:
	li t6,1
	beq s3,t6,_check
	jal ra,_loop
#-------------------------------------------------------------------------------
#the OLED Demo has finished, play with LEDs now and loop there
#-------------------------------------------------------------------------------
_end:
#-------------------------------------------------------------------------------
#Before writting the GPIO CSR, the CSR read mode must be enabled on the MIE/MIP register. s0 holds this value
#-------------------------------------------------------------------------------
	li t1,0x00010000
	csrrw x0,0,t1
	li t0,0x00010002
	csrrw x0,0,t0
	li s1,0			#timer_counter
	li s3,0			#state register
	li s4,0			#up_down register
	j _wait_led
#-------------------------------------------------------------------------------
#Now let's write the CSR registers
#-------------------------------------------------------------------------------
_change_led:
	li t0,0
	beq s3,t0,_gpio4
	li t0,1
	beq s3,t0,_gpio5
	li t0,2
	beq s3,t0,_gpio6
	li t0,3
	beq s3,t0,_gpio7
_gpio4:
	li t0,0x0000001F
	j _next_led
	
_gpio5:
	li t0,0x0000002F
	j _next_led
	
_gpio6:
	li t0,0x0000004F
	j _next_led
	
_gpio7:
	li t0,0x0000008F
	j _next_led
_next_led:
	csrrw x0,4,t0
	li t1,0
	beq s4,t1,_up
	li t1,1
	beq s4,t1,_down
_up:
	li s4,0
	li t0,3
	beq s3,t0,_down
	addi s3,s3,1
	li s1,0
	j _wait_led
_down:
	li s4,1
	li t0,0
	beq s3,t0,_up
	addi s3,s3,-1
	li s1,0
	j _wait_led
_wait_led:
	li s2,wait_time
	addi s1,s1,1
	bge s1,s2,_change_led
	j _wait_led

