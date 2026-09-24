.section .text
.globl _start
.eqv SW_MASK  ,0x7F 

start:
	#requiered code in order for the UART to work
       csrrwi x0,5,0x10
        csrrwi x0,6,0x1F
        csrrsi x0,0,0x02
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
	jal test_uart_send #fuction to test the functionality of the program must be commented out when implemented
		loop:
			jal uart_sampling          #function to continuously sample the uart
			# jal uart_save #save data received from the uart
			# modify data from the uart and send it   
			jal modify_data
			jal send_uart
		j loop
   	
	
	
_done:
	j _done


test_uart_send:
	    li t4, 0xF
            lui s2, 0x989
	    addi s2, s2, 0x680
	    sw t4, 0(s2)
	    ret
	

uart_sampling:
	csrrs t1,3,x0 #READ Mcause register (could be 5 as well)
	li   t0, 0xFF00
	and  t1, t1, t0   # extract source bits to t1
	srli	t1, t1, 8	# move it to the first byte
	li t2, 2
	bne t2, t1, uart_sampling # if the code is not from the uart keep sampling
        lui t0, 0x989 # construct the addres
	addi s1, t0, 0x680
	lw s1, 0(t0) # save de data
	andi s1, t0, SW_MASK             # keep only the data
	beqz s1, uart_sampling             # byte == 0 -> no new data
	beq s1, t3, uart_sampling # if its the same value keep sampling
	addi t3, s3, 0 #update old value

	ret # return to loop





#uart_save:
#         lui t0, 0x989 # construct the addres
#	 addi s1, t0, 0x680
#	 lw s1, 0(t0) # save de data
#	 ret #return to loop	
	
modify_data:
	#data received from the uart is in s1
	addi s1, s1, 1
	ret # return to loop

send_uart:
            lui s2, 0x989
	    addi s2, s2, 0x680
	    sw s1, 0(s2)
