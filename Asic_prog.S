#Description:
#Generic Asic_program to communicate the ASIC SIWA to the FPGA version
#HOW TO USE IT IN ANY PROGRAM
#1) Paste the .equ lines (PART 1) with the other .equ of your program
#2) Address 0x00 must be "jal x0,_main" and address 0x04 must be the interrupt handler (PART 2).
#   If your program already has a handler, merge the "li s3,1" into it.
#3) Paste the driver (PART 3) anywhere after that
#4) In your main: initialize sp, then "jal ra,_oled_init" once
#5) Whenever you want to write: jal ra,_oled_clear / _oled_set_cursor / _oled_putc / _oled_write_hex
#
#RESERVED REGISTERS 
#s3 holds the tick event 
#t5 and t6 are used only by the interrupt handler
#The driver clobbers a0, a1, t0-t2 and preserves all the s registers (except s3).
#s2 holds the uart address 
#s4 holds the old uart value

.section .text
.globl _start

.equ data_mem, 0x00001000	# adress where the packets are stored (only 4 bytes are used). 
.equ stack_top, 0x00001800  # last RAM address (16-byte aligned). It must not overlap data_mem
.equ tick_count, 5000	   #50ns x 5000 counts = 250us each tick
.eqv SW_MASK  ,0x7F 
_start:
	#requiered code in order for the UART to work
       # csrrwi x0,5,0x10
       # csrrwi x0,6,0x1F
       # csrrsi x0,0,0x02

	jal x0,_main
int_handler:

#On the interrupt handler, check if the timer bit is set
	csrrs t5,2,x0	#read the mcauseA CSR and check if timer code happened (3'b011)
	andi t6,t5,7	#mask the code bits (mcause bits 25, 26 and 27) and discard the rest
	li t5,3	#011 code
	bne t5,t6,_return
	li s3,1	#raise flag if timer code appeared
_return:
	mret	#return to the main program

_main:
	addi t3, t3, 0x0 # initialize uart initial value 
	li sp,stack_top	#the stack is required by the driver
	jal ra,_oled_init	#call it once, at the start
	jal ra,_oled_clear	#clears the screen
	jal test_uart_send #fuction to test the functionality of the program must be commented out when implemented
		loop:
			jal uart_sampling          #function to continuously sample the uart
			addi a0,s1,0	#save the received data into the oled
			jal ra,_oled_write_hex
			# modify data from the uart and send it   
			jal modify_data
			jal send_uart
		j loop
   	
	
	
_done:
	j _done


test_uart_send:
	     lui s2, 0x989
	     addi s2, s2, 0x680 #UART base address
            li t4, 0xF
	    sw t4, 0(s2)
	    ret
	

uart_sampling:
	    lui s2, 0x989
	    addi s2, s2, 0x680 #UART base address
	    lw   s1, (s2)      # loads data from UART
	    andi s1, t0, SW_MASK             # keep only the data
	    beqz s1, uart_sampling             # byte == 0 -> no new data
	    beq s1, t3, uart_sampling # if its the same value keep sampling
	    addi t3, s3, 0 #update old value
	    ret # else return to loop


	  
modify_data:
	#data received from the uart is in s1
	addi s1, s1, 1
	ret # return to loop

send_uart:
	lui s2, 0x989
	 addi s2, s2, 0x680 #UART base address
	    sw s1, 0(s2)

#Driver for the OLED
#functions:
#_oled_init: call once (sets up the GPIO, the timer, resets and initializes the OLED)
#_oled_clear: clears the display, cursor goes to line 1 column 0
#_oled_set_cursor: a0 = DDRAM address (0x00 line 1, 0x40 line 2)
#_oled_putc: a0 = ASCII character, written at the cursor (the cursor moves by itself)
#_oled_write_hex: a0 = byte, written at the cursor as "0xNN"
#_oled_cmd: a0 = any OLED command byte

_oled_clear:
	li a0,0x00000001	#clear display and set DDRAM addr to 0'h
	j _oled_cmd
_oled_set_cursor:
	ori a0,a0,0x00000080	#set DDRAM addr (0xC0 = line 2, as in the demo)
	j _oled_cmd
_oled_putc:
	j _oled_data
_oled_write_hex:
	addi sp,sp,-16
	sw ra,12(sp)
	sw a0,8(sp)	#keep the byte
	li a0,0x00000030	#letter "0"
	jal ra,_oled_data
	li a0,0x00000078	#letter "x"
	jal ra,_oled_data
	lw t0,8(sp)
	srli a0,t0,4	#high nibble
	jal ra,_nibble_to_ascii
	jal ra,_oled_data
	lw a0,8(sp)	#low nibble
	jal ra,_nibble_to_ascii
	jal ra,_oled_data
	lw ra,12(sp)
	addi sp,sp,16
	jalr x0,0(ra)
#a0 = value (only the low 4 bits are used) -> a0 = ASCII "0"-"9" or "A"-"F"
_nibble_to_ascii:
	andi a0,a0,0x0000000F
	li t0,10
	blt a0,t0,_nta_digit
	addi a0,a0,55	#10..15 -> "A".."F"
	jalr x0,0(ra)
_nta_digit:
	addi a0,a0,48	#0..9 -> "0".."9"
	jalr x0,0(ra)
#-------------------------------------------------------------------------------
#Initialization: same steps as the demo (CSR setup, timer, reset, command sequence)
#-------------------------------------------------------------------------------
_oled_init:
	addi sp,sp,-16
	sw ra,12(sp)
#-------------------------------------------------------------------------------
#GPIO0-3 to '1', CSR read mode, interrupt addr and timer 
#-------------------------------------------------------------------------------
	li t0,0x0000000F
	li t1,0x00010000
	li t2,tick_count
	li t3,4
	csrrw x0,0,t1
	csrrw x0,4,t0
	csrrw x0,5,t3
	csrrw x0,6,t2
	li s3,0
	li t1,0x00010001
	csrrw x0,0,t1	#initiate the timer
#-------------------------------------------------------------------------------
#Reset sequence only (states 0 and 1, no packets)
#-------------------------------------------------------------------------------
	li a0,0
	li a1,0
	jal ra,_oled_run
#-------------------------------------------------------------------------------
#Commmand sequence
#-------------------------------------------------------------------------------
	li a0,0x00000028	#Change to Fundamental Function set: two-line display, 5x8 character font
	jal ra,_oled_cmd
	li a0,0x00000008	#Display, cursor and blinking off
	jal ra,_oled_cmd
	li a0,0x0000002A	#Change to Extended Function set
	jal ra,_oled_cmd
	li a0,0x00000008	#Two-line display set and 5-dot font config
	jal ra,_oled_cmd
	li a0,0x00000079	#Enable OLED Command set
	jal ra,_oled_cmd
	li a0,0x000000DA	#SEG config (this is how it is supposed to write on the screen). 1st command of 2 commands
	jal ra,_oled_cmd
	li a0,0x00000000	#SEG config - 2nd part
	jal ra,_oled_cmd
	li a0,0x00000078	#Disable OLED Command set
	jal ra,_oled_cmd
	li a0,0x00000028	#Change to Fundamental Function set
	jal ra,_oled_cmd
	li a0,0x00000001	#clear display and set DDRAM addr to 0'h
	jal ra,_oled_cmd
	li a0,0x0000000F	#display ON, cursor on, blinking on (the state machine waits 100ms after this command)
	jal ra,_oled_cmd
	lw ra,12(sp)
	addi sp,sp,16
	jalr x0,0(ra)
#-------------------------------------------------------------------------------
#Every command / data byte is one transaction of 3 packets, like the demo:
#Address:011110+SA0:1+R/W:0= 01111010, Control bit + D/C bit + 6 0s, and the byte itself
#-------------------------------------------------------------------------------
#a0 = command byte
_oled_cmd:
	addi a1,a0,0
	li a0,0x00000080	#1000000 = Control bit + D/C bit + 6 0s
	j _oled_send
#a0 = data byte (character code)
_oled_data:
	addi a1,a0,0
	li a0,0x00000040	#0100000 = Control bit + D/C bit + 6 0s
#a0 = control byte, a1 = payload byte
_oled_send:
	li t0,data_mem
	li t1,0x0000007A	#Address:011110+SA0:1+R/W:0= 01111010
	sb t1,0(t0)
	sb a0,1(t0)
	sb a1,2(t0)
	sb x0,3(t0)	#the byte after the last packet must be 0 (it is preloaded by the state machine, like in the demo)
	li a0,2	#start at state 2 (the reset has already been done)
	li a1,3	#3 packets
#-------------------------------------------------------------------------------
#Runs the state machine of the demo
#a0 = first state (0 = reset and then packets, 2 = only packets)
#a1 = number of packets stored in data_mem
#Register s0 holds the state phase of the I2C protocol:
#0: reset_1 (clear the RST signal)
#1: reset_2 (set back the REST signal)
#2: SDA must go down (before starting this routine, it checks if there are packets to be sent, if not the program stops)
#3: SCL_1 (SCL goes from '1' to '0')
#4: Data_bit: Asign bit packet to SDA output
#5: SCL_2 (SCL goes from '0' to '1')
#6: Stop bit
#Register s1 holds the number of packets to be sent
#Register s3 holds the tick event
#Register s5 holds the counter for the 1/4 SCL cycles
#Register s6 holds the data_memory pointer
#Register s7 holds the current packet
#Register s8 holds the ACK wait time in cycles count or the stop bit wait time
#Register s9 counts 3 pkts to know when to stop a transfer
#Register s10 holds the flag that indicates a delay of 100ms when the dislay turns on
#-------------------------------------------------------------------------------
_oled_run:
	addi sp,sp,-48
	sw ra,44(sp)
	sw s0,40(sp)
	sw s1,36(sp)
	sw s5,32(sp)
	sw s6,28(sp)
	sw s7,24(sp)
	sw s8,20(sp)
	sw s9,16(sp)
	sw s10,12(sp)
	addi s0,a0,0
	addi s1,a1,0
	li s3,0
	li s5,0 		#counter for the number of 1/4 SCL cycles
	li s6,data_mem
	li s7,0
	li s8,0
	li s9,0
	li s10,0
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
#Every time a packet is going to be sent, the state machine starts here
#-------------------------------------------------------------------------------
_init:
#-------------------------------------------------------------------------------
#First, check if all packets have been sent, then finish; if not, then load and send a packet
#-------------------------------------------------------------------------------
	bge x0,s1,_end
	lb s7,0(s6)	   #load packet
	addi s6,s6,1	#data pointer +1
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
	li t0,0x0000008	#mask to clear the GPIO3 bit
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
	li t1,0x00000400		#set the GPIO2 as an output to send new data using a mask
	csrrc x0,0,t1
	li t2,0x00000004 		#mask to clear the GPIO2 bit
	csrrc x0,4,t2
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
	srl t0,s7,t0	#shift to the right
	andi t0,t0,1	#take only the right most bit for the SDA output
	li t1,1
	li t2,0x00000004	#mask to clear or set the GPIO2 bit
	beq t0,t1,_one
	csrrc x0,4,t2
	jal x0,_loop_1
_one:
	csrrs x0,4,t2
_ack_bit:
	jal x0,_loop_1
_stop_bit:
	li t2,0x00000004	#mask to clear or set the GPIO2 bit
	csrrc x0,4,t2
	jal x0,_loop_1
#-------------------------------------------------------------------------------
#SCL loop (GPIO3 goes up)
#-------------------------------------------------------------------------------
_scl_2:
	li t0,0x00000008	#mask to set the GPIO3 bit
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
	li t0,1
	beq s3,t0,_check
	jal ra,_loop
#-------------------------------------------------------------------------------
#All the packets have been sent: restore the registers and go back to the caller
#-------------------------------------------------------------------------------
_end:
	lw s10,12(sp)
	lw s9,16(sp)
	lw s8,20(sp)
	lw s7,24(sp)
	lw s6,28(sp)
	lw s5,32(sp)
	lw s1,36(sp)
	lw s0,40(sp)
	lw ra,44(sp)
	addi sp,sp,48
	jalr x0,0(ra)
