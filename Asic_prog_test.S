.section .text
.globl _start

.eqv SW_MASK,0x7F 
.eqv SRCANDCODE_MASK, 0x3E000000
.eqv UARTRD, 0x20000000
.eqv UARTDATA_ADDR, 0x1004

#OLED values
.eqv data_mem, 0x00001000  #address where the packets are stored (only 4 bytes are used). It must be RAM
.eqv stack_top, 0x00001800 #last RAM address (16-byte aligned). It must not overlap data_mem
.eqv tick_count, 5000      #50ns x 5000 counts = 250us each tick

_start:
	li s4, 0                   #initialize UART data flag (0 = no new data)
	la t2, int_handler         #load the address of the interrupt handler into t2
	csrrw x0,5,t2             #set MTVEC to int_handler address
	li sp,stack_top            #the stack is required by the OLED driver
	jal ra,_oled_init          #start the OLED (this does csrrw to CSR0 internally,
	                           #so UART enable must be set AFTER this call)
	jal ra,_oled_clear         #clear the OLED
	#FIX: enable UART/SPI interrupts AFTER _oled_init, not before.
	#_oled_init does csrrw x0,0,0x00010001 which overwrites the full CSR0,
	#clearing any bits set before the call. By setting them here, after _oled_init,
	#the bits survive and the UART interrupt actually fires.
	csrrsi x0,0,0x02           #enable bit 1 (UART/SPI interrupt enable)
	jal ra, test_uart_send     #test function: send a byte to trigger a UART RX interrupt
	                           #remove this line when the program is implemented in real hardware
	jal x0,main

int_handler:
	#save the context: all registers used inside this handler or any function it calls
	addi sp, sp, -32
	sw t1, 0(sp)
	sw t5, 4(sp)
	sw t6, 8(sp)
	sw ra, 12(sp)
	sw t0, 16(sp)
	sw s1, 20(sp)
	#note: s3 and s4 are intentionally NOT saved/restored:
	#  s3 = timer tick flag, must survive to be read by _oled_run's _loop
	#  s4 = UART data flag, must survive to be read by main

	csrrci x0,0,0x03           #disable all interrupts while inside the handler (no nesting)

	csrrs t5,3,x0              #read mcauseB (peripheral interrupt cause: UART, SPI...)
	li t1,SRCANDCODE_MASK      #mask to isolate source and code bits
	and t5,t5,t1
	li t6,UARTRD          	   #expected value for "UART" interrupt
	beq t5,t6,is_uart          #if it matches, handle UART

	csrrs t5,2,x0              #else read mcauseA (core interrupt cause: timer...)
	andi t6,t5,7               #mask timer code bits
	li t5,3                    #expected value for timer interrupt (011)
	beq t5,t6,is_timer

	j return                   #unknown interrupt, just return

is_uart:
	jal ra, uart_save          #read byte from UART, store it in UARTDATA_ADDR, set s4=1
	j return

is_timer:
	li s3,1                    #raise tick flag for the OLED state machine
	j return

return:
	csrrsi x0,0,0x03           #re-enable UART/SPI and timer interrupts
	#restore context
	lw s1, 20(sp)
	lw t0, 16(sp)
	lw ra, 12(sp)
	lw t6, 8(sp)
	lw t5, 4(sp)
	lw t1, 0(sp)
	addi sp, sp, 32
	mret                       #return to the interrupted program (temporary, this was mret)

main:
	#spin here waiting for a UART interrupt to set s4=1
	beqz s4, main
	li s4, 0                   #clear the flag: ready for the next byte
	#new UART data arrived: load it from the shared address and display it on the OLED
	li t0, UARTDATA_ADDR
	lw a0, 0(t0)               #load the received byte
	mv s1, a0 #save it before executing
	jal ra,_oled_write_hex     #display it on the OLED as "0xNN"
	jal ra, modify_data        #modify the data (s1 += 1)
	jal ra, send_uart          #send modified data back through UART
	j main

#-------------------------------------------------------------------------------
#AUX functions
#-------------------------------------------------------------------------------
# uncomment instructions when implemneting
uart_save:
	li t0, 0x00800000              #construct UART RX address: 0x989680
	lw s1, 0(t0)           #read byte from UART into s1
	li t0, UARTDATA_ADDR       #address of the shared data buffer
	sw s1, 0(t0)               #store received byte there
	li s4, 1                   #set flag: new UART data available
	ret

modify_data:
	addi s1, s1, 1             #increment the received byte by 1
	ret

send_uart:
	lui t0,0x00800000              #construct UART TX address: 0x989680
	sw s1, 0(t0)           #send modified byte through UART
	ret

test_uart_send:
	#sends a test byte (value 1) through UART to simulate an incoming byte
	#this triggers a UART RX interrupt on the other side
	#remove this function call from _start when running on real hardware
	li t4, 1
	li s2, 0x00800000 #(temporary uncomment when implementing)
	sw t4, 0(s2)
	ret

#-------------------------------------------------------------------------------
#PART 3: OLED DRIVER
#Public functions:
#_oled_init: call once (sets up the GPIO, the timer, resets and initializes the OLED)
#_oled_clear: clears the display, cursor goes to line 1 column 0
#_oled_set_cursor: a0 = DDRAM address (0x00 line 1, 0x40 line 2)
#_oled_putc: a0 = ASCII character, written at the cursor (the cursor moves by itself)
#_oled_write_hex: a0 = byte, written at the cursor as "0xNN"
#_oled_cmd: a0 = any OLED command byte
#-------------------------------------------------------------------------------
_oled_clear:
	li a0,0x00000001
	j _oled_cmd
_oled_set_cursor:
	ori a0,a0,0x00000080
	j _oled_cmd
_oled_putc:
	j _oled_data
_oled_write_hex:
	addi sp,sp,-16
	sw ra,12(sp)
	sw a0,8(sp)
	li a0,0x00000030            #'0'
	jal ra,_oled_data
	li a0,0x00000078            #'x'
	jal ra,_oled_data
	lw t0,8(sp)
	srli a0,t0,4               #high nibble
	jal ra,_nibble_to_ascii
	jal ra,_oled_data
	lw a0,8(sp)                #low nibble
	jal ra,_nibble_to_ascii
	jal ra,_oled_data
	lw ra,12(sp)
	addi sp,sp,16
	jalr x0,0(ra)
_nibble_to_ascii:
	andi a0,a0,0x0000000F
	li t0,10
	blt a0,t0,_nta_digit
	addi a0,a0,55
	jalr x0,0(ra)
_nta_digit:
	addi a0,a0,48
	jalr x0,0(ra)
_oled_init:
	addi sp,sp,-16
	sw ra,12(sp)
	li t0,0x0000000F
	li t1,0x00010000
	li t2,tick_count
	csrrw x0,0,t1              #enable CSR read mode (timer NOT started yet)
	csrrw x0,4,t0              #GPIO: SA0=1, /RST=1, SDA=1, SCL=1
	#note: CSR5 (MTVEC) is intentionally NOT written here.
	#it was already set in _start via 'la t2,int_handler / csrrw x0,5,t2'
	#and writing it here with a hardcoded value would break the correct address.
	csrrw x0,6,t2              #set timer period
	li s3,0                    #clear tick flag
	li t1,0x00010001
	csrrw x0,0,t1              #start the timer (bit 0 = 1)
	#note: bit 1 (UART enable) is intentionally left 0 here.
	#it will be set by _start after this function returns, via csrrsi x0,0,0x02
	li a0,0
	li a1,0
	jal ra,_oled_run           #reset sequence (states 0 and 1)
	li a0,0x00000028
	jal ra,_oled_cmd
	li a0,0x00000008
	jal ra,_oled_cmd
	li a0,0x0000002A
	jal ra,_oled_cmd
	li a0,0x00000008
	jal ra,_oled_cmd
	li a0,0x00000079
	jal ra,_oled_cmd
	li a0,0x000000DA
	jal ra,_oled_cmd
	li a0,0x00000000
	jal ra,_oled_cmd
	li a0,0x00000078
	jal ra,_oled_cmd
	li a0,0x00000028
	jal ra,_oled_cmd
	li a0,0x00000001
	jal ra,_oled_cmd
	li a0,0x0000000F
	jal ra,_oled_cmd
	lw ra,12(sp)
	addi sp,sp,16
	jalr x0,0(ra)
_oled_cmd:
	addi a1,a0,0
	li a0,0x00000080
	j _oled_send
_oled_data:
	addi a1,a0,0
	li a0,0x00000040
_oled_send:
	li t0,data_mem
	li t1,0x0000007A
	sb t1,0(t0)
	sb a0,1(t0)
	sb a1,2(t0)
	sb x0,3(t0)
	li a0,2
	li a1,3
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
	li s5,0
	li s6,data_mem
	li s7,0
	li s8,0
	li s9,0
	li s10,0
	jal x0,_loop
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
_rst_1:
	li t1,0x0000000D
	csrrw x0,4,t1
	addi s0,s0,1
	jal x0,_loop_1
_rst_2:
	li t1,0x0000000F
	csrrw x0,4,t1
	li t0,4
	bne s8,t0,_rst_wait
	addi s0,s0,1
	li s8,0
	jal x0,_loop_1
_rst_wait:
	addi s8,s8,1
	jal x0,_loop_1
_init:
	bge x0,s1,_end
	lb s7,0(s6)
	addi s6,s6,1
	li t1,0x0000000B
	csrrw x0,4,t1
	addi s0,s0,1
	jal x0,_loop_1
_scl_1:
	li t0,0x0000008
	csrrc x0,4,t0
	addi s0,s0,1
	li t2,8
	bne s5,t2,_output_gpio
	li t1,0x00000400
	csrrs x0,0,t1
	lb s7,0(s6)
	addi s6,s6,1
	li t1,0x0000000F
	bne s7,t1,_output_gpio
	li s10,1
_output_gpio:
	li t2,9
	bne s5,t2,_not_ack
	li t1,0x00000400
	csrrc x0,0,t1
	li t2,0x00000004
	csrrc x0,4,t2
_not_ack:
	jal x0,_loop_1
_data_bit:
	li t2,8
	addi s0,s0,1
	beq s5,t2,_ack_bit
	beq s1,x0,_stop_bit
	li t0,7
	sub t0,t0,s5
	srl t0,s7,t0
	andi t0,t0,1
	li t1,1
	li t2,0x00000004
	beq t0,t1,_one
	csrrc x0,4,t2
	jal x0,_loop_1
_one:
	csrrs x0,4,t2
_ack_bit:
	jal x0,_loop_1
_stop_bit:
	li t2,0x00000004
	csrrc x0,4,t2
	jal x0,_loop_1
_scl_2:
	li t0,0x00000008
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
	addi s6,s6,-1
	jal x0,_loop_1
_stop_wait:
	addi s8,s8,1
	jal x0,_loop_1
_loop_1:
	li s3,0
_loop:
	li t0,1
	beq s3,t0,_check
	jal ra,_loop
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

