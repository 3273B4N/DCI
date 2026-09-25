.section .text
.globl _start
.eqv SW_MASK,0x7F 
.eqv SRCANDCODE_MASK, 0x3E000000
.eqv UARTRD1BYTE, 0x23000000

_start:
	la   t2, int_handler # load the direction of the interrupt handler into t2
        csrrw x0,5,t2 #set direction of the instruction handler (see how to set the direction)
        csrrsi x0,0,0x02 #enables the UART and SPI interrupt enables
	li t6,UARTRD1BYTE# reserves a register to be used as the criteria for the interruption handler
	li t1,SRCANDCODE_MASK # register that holds the src and code mask
	jal ra, test_uart_send # erase this function when the program is implemented
	jal x0,main

int_handler:
	csrrsi x0,0,0x00 #disables the UART and SPI interrupt enables
	csrrs t5,3,x0	#read the mcauseB CSR 
	and t5,t5,t1 #mask the source and code bits
	bne t5,t6,return # if the interrupt does not correspond to the uart read 1 byte, return
	jal ra, uart_save #jump to the load data function
	# space to add the oled display function here
	jal ra, modify_data
	jal ra, send_uart # send data through uart (might cause a interruption)
	j return # return to the loop function
	
return:
        csrrsi x0,0,0x02 #enables the UART and SPI interrupt enables
	mret	#return to the main program

main: #loop function to wait for the UART data

	j main

#aux functions
uart_save:
	 lui t0, 0x989 #Construct UART address
	 lb s1, 0x680(t0) # Read byte from uart to s1
	 ret #return

modify_data:
	#data received from the uart is in s1
	addi s1, s1, 1
	ret # return 	
send_uart:
	 sb s1, 0x680(t0) # send byte through the uart
	 ret #return

test_uart_send:
	    li t4, 0xF
            lui s2, 0x989
	    addi s2, s2, 0x680
	    sw t4, 0(s2)
	    ret




