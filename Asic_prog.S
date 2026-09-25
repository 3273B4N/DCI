.section .text
.globl start

.eqv SW_MASK,0x7F 
.eqv SRCANDCODE_MASK, 0x3E000000
.eqv UARTRD1BYTE, 0x23000000
.eqv UARTDATA_ADDR, 0x2000

#OLED values
.equ data_mem, 0x00001000 #address where the packets are stored (only 4 bytes are used). It must be RAM
.equ stack_top, 0x00001800	#last RAM address (16-byte aligned). It must not overlap data_mem
.equ tick_count, 5000	   #50ns x 5000 counts = 250us each tick

start:
	la t2, int_handler # load the direction of the interrupt handler into t2
        csrrw x0,5,t2 #set direction of the instruction handler (see how to set the direction)
        csrrsi x0,0,0x03  #enables the UART, SPI and timer interrupt enables
	li sp,stack_top	#the stack is required by the OLED
	jal ra,_oled_init #start the oled
	jal ra,_oled_clear # clear the oled
	jal ra, test_uart_send # erase this function when the program is implemented
	li s4, 0           # Initialize UART data flag
	jal x0,main

int_handler:
	#save the context
	addi sp, sp, -32
	sw t1, 0(sp)
	sw t5, 4(sp)
	sw t6, 8(sp)
	sw ra, 12(sp)
	sw t0, 16(sp)
	sw s1, 20(sp)

	csrrsi x0,0,0x00 #disables all the interrupt enables
	csrrs t5,3,x0	#read the mcauseB CSR 
	li t1,SRCANDCODE_MASK # register that holds the src and code mask
	and t5,t5,t1 #mask the source and code bits
	li t6,UARTRD1BYTE# value to see if it is a uart read byte value
	beq t5,t6,is_uart # if the interrupt correspond to the uart read 1 byte, go to the function
	
	csrrs t5,2,x0	# else, read the mcauseA CSR and check if timer code happened (3'b011)
	andi t6,t5,7	#mask the timer interuption
	li t5,3	#011 code 
	beq t5,t6,is_timer # if the interrupt correspond to the timer go to the function
	
	j return # else just return to the main function

	is_uart:
		jal ra, uart_save #jump to the load data function
		jal ra, modify_data
		jal ra, send_uart # send data through uart 
		j return # return to the loop function

	is_timer:
		li s3,1	#raise flag if timer code appeared
		j return
	
return:
        csrrsi x0,0,0x03 #enables the UART and SPI interrupt enables and the timer
	#restore context
	lw s1, 20(sp)
	lw t0, 16(sp)
	lw ra, 12(sp)
	lw t6, 8(sp)
	lw t5, 4(sp)
	lw t1, 0(sp)
	addi sp, sp, 32
	mret	#return to the main program

main:  #loop function to wait for the UART data
	#check if the uart data flag is not set then loop, else write data on the OLED
	beqz s4, main
	la t0, UARTDATA_ADDR 
	lb a0, 0(t0) #load the data in the UART data addres
	jal ra,_oled_write_hex	#write it on the oled
	 #set the uart flag to zero: no new data
	li s4, 0
	j main

#AUX functions
uart_save:
	 lui t0, 0x989 #Construct UART address
	 lb s1, 0x680(t0) # Read byte from uart to s1
	 la t0, UARTDATA_ADDR
	 sb s1, 0(t0) #store the data in the UART data addres
	  li s4, 1 #set a flag to see that there is new uart data
	 ret #return

modify_data:
	#data received from the uart is in s1
	addi s1, s1, 1
	ret # return 	
send_uart:
	 sb s1, 0x680(t0) # send byte through the uart
	 ret #return

test_uart_send:
	    li t4, 1
            lui s2, 0x989
	    addi s2, s2, 0x680
	    sw t4, 0(s2)
	    ret




#-------------------------------------------------------------------------------
#PART 3: DRIVER
#Public functions:
#_oled_init: call once (sets up the GPIO, the timer, resets and initializes the OLED)
#_oled_clear: clears the display, cursor goes to line 1 column 0
#_oled_set_cursor: a0 = DDRAM address (0x00 line 1, 0x40 line 2)
#_oled_putc: a0 = ASCII character, written at the cursor (the cursor moves by itself)
#_oled_write_hex: a0 = byte, written at the cursor as "0xNN"
#_oled_cmd: a0 = any OLED command byte
#-------------------------------------------------------------------------------
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
#GPIO0-3 to '1', CSR read mode, interrupt addr and timer (same values and order as the demo)
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
#Command sequence of the demo
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





